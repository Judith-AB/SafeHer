const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { BigQuery } = require("@google-cloud/bigquery");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const bigquery = new BigQuery();

function fuzzCoordinates(lat, lng) {
  return {
    lat: Math.round(lat * 1000) / 1000,
    lng: Math.round(lng * 1000) / 1000,
  };
}

exports.onIncidentCreated = onDocumentCreated("incidents/{incidentId}", async (event) => {
  const data = event.data.data();
  const fuzzed = fuzzCoordinates(data.latitude, data.longitude);
  const bucketId = `${fuzzed.lat}_${fuzzed.lng}`;

  await event.data.ref.update({
    latitude: fuzzed.lat,
    longitude: fuzzed.lng,
    pii_removed: true,
    grid_resolution_m: 111,
  });

  const incidentType = (data.type || "Other").toLowerCase().replace(" ", "_");

  await db.collection("heatmap_buckets")
    .doc(bucketId)
    .set({
      lat: fuzzed.lat,
      lng: fuzzed.lng,
      count: admin.firestore.FieldValue.increment(1),
      dominant_type: incidentType,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

  const now = new Date();
  const rows = [{
    lat: fuzzed.lat,
    lng: fuzzed.lng,
    category: data.type || "Other",
    hour_of_day: now.getHours(),
    day_of_week: now.getDay(),
    risk_score: 0.5,
    split: "TEST",
  }];

  await bigquery.dataset("safeher").table("incidents_ml").insert(rows);
  console.log(`Incident inserted into BigQuery: ${bucketId}`);
});

exports.onSosTriggered = onDocumentCreated("sos_events/{sosId}", async (event) => {
  const data = event.data.data();
  console.log(`SOS triggered at: ${data.latitude}, ${data.longitude}`);

  await db.collection("sos_log").add({
    latitude: data.latitude,
    longitude: data.longitude,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    status: "triggered",
  });
});


exports.escalateLegalQuery = onRequest({ cors: true }, async (req, res) => {
  const { userQuery, sessionId } = req.body;

  await db.collection("unresolved_legal_queries").add({
    query: userQuery,
    sessionId: sessionId,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    resolved: false,
    escalation_tier: "human_legal_aid",
  });

  res.json({
    escalated: true,
    message: "Your query has been forwarded to a legal aid volunteer. You may also call iCall: 9152987821",
  });
});

exports.getPredictiveHeatmap = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  const predictQuery = `
        SELECT
            lat_zone,
            lng_zone,
            predicted_risk_label,
            ROUND(
                (SELECT p.prob
                 FROM UNNEST(predicted_risk_label_probs) p
                 WHERE p.label = 'HIGH'), 3
            ) AS high_risk_probability
        FROM ML.PREDICT(
            MODEL \`safeher-app-9251b.safeher.risk_model\`,
            (
                SELECT DISTINCT
                    category,
                    hour_of_day,
                    day_of_week,
                    ROUND(lat, 2) AS lat_zone,
                    ROUND(lng, 2) AS lng_zone
                FROM \`safeher-app-9251b.safeher.incidents_ml\`
                WHERE split = 'TEST'
                LIMIT 150
            )
        )
    `;

  // Fetch predictions + AUC from Firestore in parallel
  const [predictionsResult, metricsDoc] = await Promise.all([
    bigquery.query(predictQuery),
    db.collection("model_metrics").doc("risk_model").get(),
  ]);

  const predictions = predictionsResult[0];
  const metrics = metricsDoc.data();

  res.json({
    predictions,
    roc_auc: metrics.roc_auc,
  });
});
exports.weeklyRetrainRiskModel = onSchedule({
    schedule: "every sunday 00:00",
    timeoutSeconds: 540,
    memory: "1GiB",
}, async () => {
    try {
        console.log("Starting weekly model retraining...");

        const retrainQuery = `
            CREATE OR REPLACE MODEL \`safeher-app-9251b.safeher.risk_model\`
            OPTIONS (
                model_type = 'boosted_tree_classifier',
                num_parallel_tree = 1,
                max_tree_depth = 4,
                input_label_cols = ['risk_label']
            ) AS
            SELECT
                category,
                hour_of_day,
                day_of_week,
                ROUND(lat, 2) AS lat_zone,
                ROUND(lng, 2) AS lng_zone,
                CASE
                    WHEN risk_score >= 0.6 THEN 'HIGH'
                    ELSE 'LOW'
                END AS risk_label
            FROM \`safeher-app-9251b.safeher.incidents_ml\`
            WHERE split = 'TRAIN'
        `;

        const evalQuery = `
            SELECT
                ROUND(precision, 4) AS precision,
                ROUND(recall, 4) AS recall,
                ROUND(accuracy, 4) AS accuracy,
                ROUND(f1_score, 4) AS f1_score,
                ROUND(roc_auc, 4) AS roc_auc
            FROM ML.EVALUATE(
                MODEL \`safeher-app-9251b.safeher.risk_model\`,
                (
                    SELECT
                        category,
                        hour_of_day,
                        day_of_week,
                        ROUND(lat, 2) AS lat_zone,
                        ROUND(lng, 2) AS lng_zone,
                        CASE
                            WHEN risk_score >= 0.6 THEN 'HIGH'
                            ELSE 'LOW'
                        END AS risk_label
                    FROM \`safeher-app-9251b.safeher.incidents_ml\`
                    WHERE split = 'TEST'
                )
            )
        `;

        await bigquery.query(retrainQuery);
        const [evalRows] = await bigquery.query(evalQuery);
        const metrics = evalRows[0];

        await db.collection("model_metrics").doc("risk_model").set({
            roc_auc: metrics.roc_auc,
            accuracy: metrics.accuracy,
            precision: metrics.precision,
            recall: metrics.recall,
            f1_score: metrics.f1_score,
            last_trained: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log("Weekly retraining complete:", metrics);

    } catch (error) {
        console.error("Weekly retraining failed:", error);
    }
});