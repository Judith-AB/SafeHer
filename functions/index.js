const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

exports.onIncidentCreated = onDocumentCreated("incidents/{incidentId}", async (event) => {
    const data = event.data.data();
    const lat = Math.round(data.latitude * 100) / 100;
    const lng = Math.round(data.longitude * 100) / 100;
    const bucketId = `${lat}_${lng}`;

    await db.collection("heatmap_buckets")
        .doc(bucketId)
        .set({
            lat,
            lng,
            count: admin.firestore.FieldValue.increment(1),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

    console.log(`Heatmap updated for bucket: ${bucketId}`);
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