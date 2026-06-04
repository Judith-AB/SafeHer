const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

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

    const incidentType = (data.type || 'Other').toLowerCase().replace(' ', '_');

    await db.collection("heatmap_buckets")
        .doc(bucketId)
        .set({
            lat: fuzzed.lat,
            lng: fuzzed.lng,
            count: admin.firestore.FieldValue.increment(1),
            dominant_type: incidentType,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

    console.log(`Bucket: ${bucketId} | pii_removed: true`);
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

// ══════════════════════════════════════════════
// NOVELTY 2: Legal escalation function
// When chatbot can't answer, query is logged
// anonymously for human legal aid volunteer
// ══════════════════════════════════════════════
const { onCall } = require("firebase-functions/v2/https");

exports.escalateLegalQuery = onCall(async (request) => {
  const { userQuery, sessionId } = request.data;

  await db.collection("unresolved_legal_queries").add({
    query: userQuery,
    sessionId: sessionId,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    resolved: false,
    escalation_tier: "human_legal_aid",
  });

  return {
    escalated: true,
    message: "Your query has been forwarded to a legal aid volunteer. You may also call iCall: 9152987821",
  };
});