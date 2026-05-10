import 'package:flutter/material.dart';
import 'package:safeher/theme.dart';
import 'sos_screen.dart';
import 'report_screen.dart';
import 'heatmap_screen.dart';
import 'chatbot_screen.dart';
import 'analytics_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.deepCharcoal,
        elevation: 0,
        title: const Text(
          '🛡️ SafeHer',
          style: TextStyle(
            color: AppTheme.creamLight,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hello, stay safe',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'What do you need help with today?',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // SOS Button - Keeping it Red for safety
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SosScreen()),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFB22222), 
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB22222).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_rounded,
                        color: AppTheme.creamLight, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'SOS — I Need Help Now',
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

            const SizedBox(height: 24),

            // Feature Grid - All boxes now use oliveMuted
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [

                  _FeatureCard(
                    icon: Icons.report_problem,
                    label: 'Report Incident',
                    color: AppTheme.beigeMid,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportScreen()),
                    ),
                  ),

                  _FeatureCard(
                    icon: Icons.map,
                    label: 'Safety Heatmap',
                    color: AppTheme.beigeMid,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HeatmapScreen()),
                    ),
                  ),

                  _FeatureCard(
                    icon: Icons.chat,
                    label: 'Legal Aid Chatbot',
                    color: AppTheme.beigeMid,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                    ),
                  ),

                  _FeatureCard(
                    icon: Icons.info,
                    label: 'Helpline Numbers',
                    color: AppTheme.beigeMid,
                    onTap: () => _showHelplines(context),
                  ),

                  _FeatureCard(
                    icon: Icons.analytics,
                    label: 'Analytics Dashboard',
                    color: AppTheme.beigeMid,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelplines(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.white,
        title: const Text(
          'Emergency Helplines',
          style: TextStyle(color: AppTheme.deepCharcoal, fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🚨 Emergency: 112', style: TextStyle(color: AppTheme.deepCharcoal)),
            SizedBox(height: 8),
            Text('👩 Women Helpline: 1091', style: TextStyle(color: AppTheme.deepCharcoal)),
            SizedBox(height: 8),
            Text('🏠 Domestic Violence: 181', style: TextStyle(color: AppTheme.deepCharcoal)),
            SizedBox(height: 8),
            Text('👶 CHILDLINE: 1098', style: TextStyle(color: AppTheme.deepCharcoal)),
            SizedBox(height: 8),
            Text('👮 Police: 100', style: TextStyle(color: AppTheme.deepCharcoal)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.deepCharcoal)),
          )
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.deepCharcoal, size: 40),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.deepCharcoal,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}