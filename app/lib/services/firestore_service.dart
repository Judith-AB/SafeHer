import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

// Coordinates are rounded here; Firestore rules reject unrounded ones.
class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<void> submitIncident({
    required double latitude,
    required double longitude,
    required String type,
    String? description,
    String? areaName,
  }) async {
    final data = <String, dynamic>{
      'latitude': AppConstants.roundCoord(latitude),
      'longitude': AppConstants.roundCoord(longitude),
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'anonymous': true,
      'pii_removed': true,
      'grid_resolution_m': 111,
    };
    if (description != null && description.isNotEmpty) {
      data['description'] =
          description.length > 280 ? description.substring(0, 280) : description;
    }
    if (areaName != null && areaName.isNotEmpty) {
      data['areaName'] = areaName.length > 60 ? areaName.substring(0, 60) : areaName;
    }
    await _db.collection('incidents').add(data);
  }

  Future<void> saveSosEvent({
    required double latitude,
    required double longitude,
  }) async {
    await _db.collection('sos_events').add({
      'latitude': AppConstants.roundCoord(latitude),
      'longitude': AppConstants.roundCoord(longitude),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
