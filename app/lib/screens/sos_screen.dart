import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safeher/theme.dart';
import '../services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  bool _isSending = false;
  bool _sosSent = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  static const Color emergencyCrimson = Color(0xFFB22222);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendSOS() async {
    setState(() => _isSending = true);

    try {
      // Save to Firestore
      final position = await Geolocator.getCurrentPosition();
      await _firestoreService.saveSosEvent(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final Uri callUri = Uri(scheme: 'tel', path: '112');
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      }

      setState(() {
        _sosSent = true;
        _isSending = false;
      });
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,

      appBar: AppBar(
        backgroundColor: AppTheme.deepCharcoal,
        centerTitle: true,
        title: const Text(
          '🚨 SOS Emergency',
          style: TextStyle(color: AppTheme.creamLight, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppTheme.creamLight),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.beigeMid,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.oliveMuted.withOpacity(0.5)),
              ),
              child: const Column(
                children: [
                  Text(
                    'Emergency Helplines',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.deepCharcoal,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('🚨 All Emergencies: 112', style: TextStyle(color: AppTheme.deepCharcoal)),
                  Text('👩 Women Helpline: 1091', style: TextStyle(color: AppTheme.deepCharcoal)),
                  Text('👮 Police: 100', style: TextStyle(color: AppTheme.deepCharcoal)),
                  Text('🏠 Domestic Violence: 181', style: TextStyle(color: AppTheme.deepCharcoal)),
                ],
              ),
            ),

            const Spacer(),

            _sosSent
                ? Column(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppTheme.oliveMuted, size: 80),
                      const SizedBox(height: 16),
                      const Text(
                        '✅ SOS Alert Sent!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.oliveMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your location has been recorded.\nStay safe!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => setState(() => _sosSent = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: emergencyCrimson,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Send Again',
                          style: TextStyle(color: AppTheme.creamLight),
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onLongPress: _isSending ? null : _sendSOS,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: emergencyCrimson,
                          boxShadow: [
                            BoxShadow(
                              color: emergencyCrimson.withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: _isSending
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.creamLight,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.warning_rounded,
                                      color: AppTheme.creamLight, size: 50),
                                  SizedBox(height: 8),
                                  Text(
                                    'HOLD\nfor SOS',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppTheme.creamLight,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

            const Spacer(),

            const Text(
              'Hold the SOS button to send your\nlocation to emergency services',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}