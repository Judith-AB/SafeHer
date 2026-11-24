const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { BigQuery } = require("@google-cloud/bigquery");
const { SessionsClient } = require("@google-cloud/dialogflow");
const admin = require("firebase-admin");
const { roundCoord, istParts, truncateToIstHour, hourBand, inIndia } = require("./lib/helpers");

admin.initializeApp();
const db = admin.firestore();
const bigquery = new BigQuery();
const FieldValue = admin.firestore.FieldValue;

const PROJECT = process.env.GCLOUD_PROJECT || "safeher-app-9251b";
const DATASET = `${PROJECT}.safeher`;
const PANEL_TABLE = `${DATASET}.ncrb_panel`;
const FORECAST_TABLE = `${DATASET}.kerala_forecast`;
const DEFAULT_MODEL = `${DATASET}.ncrb_risk_model_v1`;
// total_lag1 is a raw count that drifts between years; it is kept only for a baseline.
const NON_FEATURES = "state, district, year, split, is_kerala, total_lag1";
const DIALOGFLOW_PROJECT = process.env.DIALOGFLOW_PROJECT || PROJECT;

// Must match app/lib/constants.dart and firestore.rules.
const CATEGORIES = ["Assault", "Stalking", "Eve Teasing", "Harassment", "Unsafe Area"];
const RETENTION_DAYS = { incident: 365, sos: 30, legal: 90 };
const FALLBACK_CONFIDENCE = 0.5; // chosen from scripts/chatbot_eval.js results
// recall_high is recall on the HIGH class. BigQuery ML's own "recall" is for LOW,
// because it treats the first label alphabetically as positive for string labels.
const GATE = { aucTolerance: 0.01, recallTolerance: 0.02 };
// Absolute floor, so small tolerated drops cannot add up over many promotions (v1: 0.9817 / 0.8436).
const GATE_FLOOR = { roc_auc: 0.97, recall_high: 0.80 };
const KEEP_MODELS = 4;

const daysFromNow = (n) => admin.firestore.Timestamp.fromMillis(Date.now() + n * 86400000);

function requireAuth(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign-in required.");
}

async function currentModel() {
  const doc = await db.collection("model_metrics").doc("current").get();
  return doc.exists ? doc.data() : { model: DEFAULT_MODEL };
}

exports.onIncidentCreated = onDocumentCreated("incidents/{incidentId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data();
  const id = event.params.incidentId;
  if (data.processed) return; // Firestore triggers can fire more than once

  const lat = roundCoord(Number(data.latitude));
  const lng = roundCoord(Number(data.longitude));
  if (!inIndia(lat, lng) || !CATEGORIES.includes(data.type)) {
    logger.warn("Rejected invalid incident", { id }); // never log coordinates
    await snap.ref.delete();
    return;
  }

  const reported = data.timestamp && data.timestamp.toDate ? data.timestamp.toDate() : new Date(event.time);
  const { hour, day } = istParts(reported);
  const reportedHour = truncateToIstHour(reported);
  const area = typeof data.areaName === "string" ? data.areaName.slice(0, 60) : null;

  await snap.ref.update({
    latitude: lat,
    longitude: lng,
    timestamp: admin.firestore.Timestamp.fromDate(reportedHour),
    expireAt: daysFromNow(RETENTION_DAYS.incident),
    anonymous_uid: FieldValue.delete(), // written by older app builds
    pii_removed: true,
    grid_resolution_m: 111,
    processed: true,
  });

  await db.collection("heatmap_buckets").doc(`${lat}_${lng}`).set({
    lat, lng,
    count: FieldValue.increment(1),
    by_type: { [data.type]: FieldValue.increment(1) },
    lastUpdated: FieldValue.serverTimestamp(),
  }, { merge: true });

  const summary = {
    totalIncidents: FieldValue.increment(1),
    by_type: { [data.type]: FieldValue.increment(1) },
    by_hour_band: { [hourBand(hour)]: FieldValue.increment(1) },
  };
  // Per-locality counts are not published: a locality with one report would reveal it.
  await db.collection("analytics").doc("summary").set(summary, { merge: true });

  // Live reports have no ground-truth label, so they are stored but not used for training.
  try {
    await bigquery.dataset("safeher").table("incidents_live").insert([{
      insertId: event.id,
      json: {
        incident_id: id, lat, lng, category: data.type,
        hour_of_day: hour, day_of_week: day,
        reported_hour: reportedHour.toISOString(),
      },
    }], { raw: true });
  } catch (err) {
    logger.error("BigQuery insert failed", { id, err: err.message });
    throw err;
  }
});

exports.onSosTriggered = onDocumentCreated("sos_events/{sosId}", async (event) => {
  if (!event.data) return;
  await event.data.ref.update({ expireAt: daysFromNow(RETENTION_DAYS.sos) });
  logger.info("SOS event recorded", { id: event.params.sosId });
});

const dialogflow = new SessionsClient();

exports.detectLegalIntent = onCall({ maxInstances: 10 }, async (request) => {
  requireAuth(request);
  const text = String(request.data?.text || "").trim();
  const sessionId = String(request.data?.sessionId || "");
  if (!text || text.length > 500) throw new HttpsError("invalid-argument", "Message must be 1-500 characters.");
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(sessionId)) throw new HttpsError("invalid-argument", "Bad session id.");

  const [response] = await dialogflow.detectIntent({
    session: dialogflow.projectAgentSessionPath(DIALOGFLOW_PROJECT, sessionId),
    queryInput: { text: { text, languageCode: "en" } },
  });
  const q = response.queryResult || {};
  const confidence = typeof q.intentDetectionConfidence === "number" ? q.intentDetectionConfidence : 0;
  const isFallback = Boolean(q.intent && q.intent.isFallback);
  return {
    reply: q.fulfillmentText || "",
    intent: q.intent ? q.intent.displayName : null,
    confidence,
    isFallback,
    referral: isFallback || confidence < FALLBACK_CONFIDENCE,
  };
});

exports.escalateLegalQuery = onCall({ maxInstances: 5 }, async (request) => {
  requireAuth(request);
  const query = String(request.data?.userQuery || "").trim();
  if (!query || query.length > 1000) throw new HttpsError("invalid-argument", "Query must be 1-1000 characters.");

  await db.collection("unresolved_legal_queries").add({
    query,
    created: FieldValue.serverTimestamp(),
    expireAt: daysFromNow(RETENTION_DAYS.legal),
    status: "open",
    escalation_tier: "referral",
  });

  return {
    referred: true,
    message:
      "I can't answer this one reliably. Your question has been saved (without your identity) " +
      "so we can improve these answers, but no one will reply to it here.",
  };
});

exports.getPredictiveHeatmap = onRequest({ maxInstances: 5, timeoutSeconds: 60 }, async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method !== "GET") {
    res.status(405).json({ error: "GET only" });
    return;
  }
  try {
    const current = await currentModel();
    const cacheRef = db.collection("heatmap_cache").doc("current");
    const cache = await cacheRef.get();
    const fresh = cache.exists && cache.data().model === current.model &&
      Date.now() - cache.data().generated_at.toMillis() < 6 * 3600 * 1000;

    let predictions;
    if (fresh) {
      predictions = cache.data().predictions;
    } else {
      // Probability that each Kerala district ranks in India's top 20% next year.
      const query = `
        SELECT district, lat AS lat_zone, lng AS lng_zone, year AS forecast_year,
               predicted_risk_label,
               ROUND((SELECT p.prob FROM UNNEST(predicted_risk_label_probs) p WHERE p.label = 'HIGH'), 3)
                 AS high_risk_probability
        FROM ML.PREDICT(MODEL \`${current.model}\`, (SELECT * FROM \`${FORECAST_TABLE}\`))
        ORDER BY district`;
      const [rows] = await bigquery.query({ query });
      predictions = rows;
      await cacheRef.set({
        model: current.model,
        generated_at: admin.firestore.Timestamp.now(),
        predictions,
      });
    }
    res.set("Cache-Control", "public, max-age=300");
    res.json({ predictions, roc_auc: current.roc_auc ?? null, model: current.model });
  } catch (err) {
    logger.error("Heatmap failed", { err: err.message });
    res.status(503).json({ error: "Predictions unavailable" });
  }
});

function trainSql(model) {
  return `
    CREATE OR REPLACE MODEL \`${model}\`
    OPTIONS (model_type = 'boosted_tree_classifier', num_parallel_tree = 1, max_tree_depth = 4,
             input_label_cols = ['risk_label'], data_split_method = 'NO_SPLIT') AS
    SELECT * EXCEPT (${NON_FEATURES})
    FROM \`${PANEL_TABLE}\` WHERE split = 'TRAIN'`;
}

const TEST_SQL = `SELECT * EXCEPT (${NON_FEATURES}) FROM \`${PANEL_TABLE}\` WHERE split = 'TEST'`;

function evalSql(model) {
  return `
    SELECT ROUND(accuracy, 4) AS accuracy, ROUND(roc_auc, 4) AS roc_auc,
           ROUND(recall, 4) AS recall_low, ROUND(precision, 4) AS precision_low
    FROM ML.EVALUATE(MODEL \`${model}\`, (${TEST_SQL}))`;
}

function confusionSql(model) {
  return `SELECT expected_label, HIGH, LOW FROM ML.CONFUSION_MATRIX(MODEL \`${model}\`, (${TEST_SQL}))`;
}

// Metrics on the held-out years, with precision, recall and F1 for the HIGH class.
async function evaluate(model) {
  const [[m]] = await bigquery.query({ query: evalSql(model) });
  const [cm] = await bigquery.query({ query: confusionSql(model) });
  const row = (label) => cm.find((r) => r.expected_label === label) || { HIGH: 0, LOW: 0 };
  const tp = row("HIGH").HIGH, fn = row("HIGH").LOW, fp = row("LOW").HIGH;
  const r4 = (x) => Math.round(x * 10000) / 10000;
  const recall_high = tp + fn ? r4(tp / (tp + fn)) : 0;
  const precision_high = tp + fp ? r4(tp / (tp + fp)) : 0;
  const f1_high = recall_high + precision_high ? r4((2 * recall_high * precision_high) / (recall_high + precision_high)) : 0;
  return { ...m, recall_high, precision_high, f1_high };
}

function passesGate(cand, cur) {
  if (cand.roc_auc < GATE_FLOOR.roc_auc || cand.recall_high < GATE_FLOOR.recall_high) return false;
  if (!cur) return true;
  return cand.roc_auc >= cur.roc_auc - GATE.aucTolerance &&
         cand.recall_high >= cur.recall_high - GATE.recallTolerance;
}

async function promoteModel(model, metrics, extra = {}) {
  const record = { model, ...metrics, promoted_at: FieldValue.serverTimestamp(), ...extra };
  await db.collection("model_metrics").doc("current").set(record);
  await db.collection("model_metrics").doc("risk_model").set(record); // read by older app builds
  await db.collection("heatmap_cache").doc("current").delete();
}

exports.scheduledRetrainRiskModel = onSchedule({
  schedule: "1 of month 00:00", // NCRB data is annual, so monthly is enough
  timeZone: "UTC",
  timeoutSeconds: 540,
  memory: "1GiB",
}, async () => {
  const stamp = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  const candidate = `${DATASET}.ncrb_risk_model_${stamp}`;
  const current = await currentModel();

  try {
    await bigquery.query({ query: trainSql(candidate) });
    const cand = await evaluate(candidate);
    let cur = null;
    if (current.recall_high != null) cur = current;
    else if (current.model) cur = await evaluate(current.model).catch(() => null);

    const promote = passesGate(cand, cur);

    await db.collection("model_history").add({
      action: "retrain", candidate, previous: current.model, candidate_metrics: cand,
      previous_metrics: cur, promoted: promote, gate: GATE, gate_floor: GATE_FLOOR,
      at: FieldValue.serverTimestamp(),
    });

    if (promote) {
      await promoteModel(candidate, cand);
      logger.info("Promoted candidate", { candidate, cand });
      await pruneOldModels(candidate);
    } else {
      await bigquery.query({ query: `DROP MODEL IF EXISTS \`${candidate}\`` });
      logger.warn("Candidate rejected by gate", { candidate, cand, cur });
    }
  } catch (err) {
    logger.error("Monthly retraining failed", { candidate, err: err.message });
    throw err; // so Cloud Scheduler records the run as failed
  }
});

// Rollback to a kept version. Only callable by an account with the custom claim admin=true
// (set with scripts/set_admin.js). The Firestore console edit in DEPLOY.md does the same by hand.
exports.rollbackRiskModel = onCall({ maxInstances: 1, timeoutSeconds: 120 }, async (request) => {
  if (!request.auth?.token?.admin) throw new HttpsError("permission-denied", "Admin only.");
  const id = String(request.data?.model || "");
  if (!/^ncrb_risk_model_(v1|\d{8})$/.test(id)) throw new HttpsError("invalid-argument", "Unknown model id.");
  const model = `${DATASET}.${id}`;
  const previous = (await currentModel()).model;
  let metrics;
  try {
    metrics = await evaluate(model);
  } catch (err) {
    throw new HttpsError("not-found", `Model ${id} could not be evaluated: ${err.message}`);
  }
  await promoteModel(model, metrics, { rolled_back_from: previous });
  await db.collection("model_history").add({
    action: "rollback", candidate: model, previous, candidate_metrics: metrics, promoted: true,
    at: FieldValue.serverTimestamp(),
  });
  logger.warn("Rolled back risk model", { from: previous, to: model });
  return { model, metrics };
});

// Rollback: point model_metrics/current at one of the kept versions.
async function pruneOldModels(keep) {
  const [models] = await bigquery.dataset("safeher").getModels();
  const versions = models.map((m) => m.id).filter((id) => /^ncrb_risk_model_\d{8}$/.test(id)).sort().reverse();
  for (const id of versions.slice(KEEP_MODELS)) {
    if (`${DATASET}.${id}` === keep) continue;
    await bigquery.query({ query: `DROP MODEL IF EXISTS \`${DATASET}.${id}\`` });
  }
}
