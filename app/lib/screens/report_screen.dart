import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safeher/theme.dart';
import '../constants.dart';
import '../services/firestore_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  final List<String> _incidentTypes = AppConstants.categories;

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    return await Geolocator.getCurrentPosition();
  }

  // Shown before each report so the user knows what is stored and for how long.
  Future<bool> _confirmNotice() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Before you report'),
        content: const Text(
          'We store: the incident type, your location rounded to about 100 m, '
          'the hour (not the exact time), your area name and any text you add.\n\n'
          'We do not store your name, phone number or account with the report.\n\n'
          'Reports are deleted automatically after one year. '
          'Do not write names or other details that could identify you or anyone else.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('I agree, submit')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _submitReport() async {
    if (!await _confirmNotice()) return;
    if (!mounted) return;
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still connecting. Please try again in a moment.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final position = await _getLocation();
      // Round before geocoding so the precise fix never leaves the device.
      final lat = AppConstants.roundCoord(position.latitude);
      final lng = AppConstants.roundCoord(position.longitude);

      String? areaName;
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        areaName = placemarks.isNotEmpty ? placemarks.first.locality : null;
      } catch (_) {
        areaName = null;
      }

      await _firestoreService.submitIncident(
        latitude: lat,
        longitude: lng,
        type: _selectedType,
        description: _descController.text.trim(),
        areaName: areaName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted without your identity.'),
            backgroundColor: AppTheme.oliveMuted,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamLight,
      appBar: AppBar(
        backgroundColor: AppTheme.deepCharcoal,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.creamLight),
        title: const Text(
          'Report Incident',
          style: TextStyle(
            color: AppTheme.creamLight,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView( 
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your name, phone and account are not stored with this report',
                style: TextStyle(
                  color: AppTheme.deepCharcoal.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Type of Incident',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.deepCharcoal,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _incidentTypes.map((type) {
                  final isSelected = _selectedType == type;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.deepCharcoal : AppTheme.beigeMid,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.deepCharcoal.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? AppTheme.creamLight : AppTheme.deepCharcoal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Describe what happened (optional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.deepCharcoal,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                maxLines: 5,
                maxLength: 280,
                style: const TextStyle(color: AppTheme.deepCharcoal),
                decoration: InputDecoration(
                  hintText: 'Please do not include names, phone numbers or addresses.',
                  hintStyle: TextStyle(color: AppTheme.deepCharcoal.withOpacity(0.4)),
                  filled: true,
                  fillColor: AppTheme.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppTheme.oliveMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Your location is rounded to about 100 m before upload',
                    style: TextStyle(
                      color: AppTheme.deepCharcoal.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40), 

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepCharcoal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: AppTheme.creamLight, strokeWidth: 2),
                        )
                      : const Text(
                          'Submit Anonymous Report',
                          style: TextStyle(
                            color: AppTheme.creamLight,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
