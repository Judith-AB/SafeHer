import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:geocoding/geocoding.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _descController = TextEditingController();
  final _firestoreService = FirestoreService();

  String _selectedType = 'Harassment';
  bool _isSubmitting = false;

  final List<String> _incidentTypes = [
    'Harassment',
    'Stalking',
    'Assault',
    'Theft',
    'Unsafe Area',
    'Other',
  ];

  Future<Position> _getLocation() async {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Location services disabled');
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> updateAnalytics(Position position) async {
    final firestore = FirebaseFirestore.instance;

    final snapshot =
        await firestore.collection('incidents').get();

    int harassment = 0;
    int stalking = 0;
    int assault = 0;
    int theft = 0;
    int unsafeArea = 0;
    int other = 0;

    Map<String, int> locationCounts = {};
    Map<String, int> hourBuckets = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();

      final type = data['type'];

      if (type == 'Harassment') harassment++;
      if (type == 'Stalking') stalking++;
      if (type == 'Assault') assault++;
      if (type == 'Theft') theft++;
      if (type == 'Unsafe Area') unsafeArea++;
      if (type == 'Other') other++;

      /// LOCATION ANALYSIS
      if (data['areaName'] != null) {
        String area = data['areaName'];

        locationCounts[area] =
            (locationCounts[area] ?? 0) + 1;
      }

      /// TIME ANALYSIS
      if (data['timestamp'] != null) {
        Timestamp ts = data['timestamp'];

        DateTime dt = ts.toDate();

        int hour = dt.hour;

        String bucket = "";

        if (hour >= 6 && hour < 12) {
          bucket = "6 AM - 12 PM";
        } else if (hour >= 12 && hour < 18) {
          bucket = "12 PM - 6 PM";
        } else if (hour >= 18 && hour < 24) {
          bucket = "6 PM - 12 AM";
        } else {
          bucket = "12 AM - 6 AM";
        }

        hourBuckets[bucket] =
            (hourBuckets[bucket] ?? 0) + 1;
      }
    }

    /// MOST UNSAFE AREA
    String mostUnsafeArea = "Unknown";
    int maxAreaCount = 0;

    locationCounts.forEach((key, value) {
      if (value > maxAreaCount) {
        maxAreaCount = value;
        mostUnsafeArea = key;
      }
    });

    /// PEAK UNSAFE HOURS
    String peakUnsafeHours = "Unknown";
    int maxHourCount = 0;

    hourBuckets.forEach((key, value) {
      if (value > maxHourCount) {
        maxHourCount = value;
        peakUnsafeHours = key;
      }
    });

    await firestore
        .collection('analytics')
        .doc('summary')
        .set({
      'totalIncidents': snapshot.docs.length,
      'harassment': harassment,
      'stalking': stalking,
      'assault': assault,
      'theft': theft,
      'unsafeArea': unsafeArea,
      'other': other,
      'mostUnsafeArea': mostUnsafeArea,
      'peakUnsafeHours': peakUnsafeHours,
    });
  }

  Future<void> _submitReport() async {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the incident'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final position = await _getLocation();

      /// GET AREA NAME
      List<Placemark> placemarks =
          await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String areaName =
          placemarks.first.locality ?? "Unknown";

      /// SAVE INCIDENT
      await FirebaseFirestore.instance
          .collection('incidents')
          .add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'type': _selectedType,
        'description':
            _descController.text.trim(),
        'areaName': areaName,
        'timestamp':
            FieldValue.serverTimestamp(),
      });

      await updateAnalytics(position);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Report submitted anonymously!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFFE91E8C),

        title: const Text(
          '📍 Report Incident',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            const Text(
              'Your report is 100% anonymous',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Type of Incident',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,

              children: _incidentTypes.map((type) {
                final isSelected =
                    _selectedType == type;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = type;
                    });
                  },

                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),

                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE91E8C)
                          : Colors.white,

                      borderRadius:
                          BorderRadius.circular(20),

                      border: Border.all(
                        color:
                            const Color(0xFFE91E8C),
                      ),
                    ),

                    child: Text(
                      type,

                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(
                                0xFFE91E8C),

                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            const Text(
              'Describe what happened',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _descController,
              maxLines: 5,

              decoration: InputDecoration(
                hintText:
                    'Describe the incident briefly...',

                filled: true,
                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 12),

            const Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Color(0xFFE91E8C),
                  size: 16,
                ),

                SizedBox(width: 4),

                Text(
                  'Your current location will be attached automatically',

                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : _submitReport,

                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFE91E8C),

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 16,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),

                child: _isSubmitting
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        'Submit Anonymous Report',

                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}