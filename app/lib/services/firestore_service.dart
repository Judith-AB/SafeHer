import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // Submit anonymous incident report
  Future<void> submitIncident({
    required double latitude,
    required double longitude,
    required String type,
    required String description,
  }) async {
    await _db.collection('incidents').add({
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'anonymous': true,
    });
  }

  // Get all heatmap buckets for map display
  Stream<QuerySnapshot> getHeatmapBuckets() {
    return _db.collection('heatmap_buckets').snapshots();
  }

  // Get recent incidents
  Stream<QuerySnapshot> getIncidents() {
    return _db
        .collection('incidents')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // Save SOS event
  Future<void> saveSosEvent({
    required double latitude,
    required double longitude,
  }) async {
    await _db.collection('sos_events').add({
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
