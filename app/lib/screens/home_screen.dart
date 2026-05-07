import 'package:flutter/material.dart';
import 'sos_screen.dart';
import 'report_screen.dart';
import 'heatmap_screen.dart';
import 'chatbot_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE91E8C),
        title: const Text(
          '🛡️ SafeHer',
          style: TextStyle(
            color: Colors.white,
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
              'Hello, stay safe 💗',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE91E8C),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'What do you need help with today?',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // SOS Button
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SosScreen())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'SOS — I Need Help Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Grid of 3 feature buttons
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _FeatureCard(
                    icon: Icons.report_problem,
                    label: 'Report Incident',
                    color: const Color(0xFFFF6B6B),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ReportScreen())),
                  ),
                  _FeatureCard(
                    icon: Icons.map,
                    label: 'Safety Heatmap',
                    color: const Color(0xFF4ECDC4),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const HeatmapScreen())),
                  ),
                  _FeatureCard(
                    icon: Icons.chat,
                    label: 'Legal Aid Chatbot',
                    color: const Color(0xFF9B59B6),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ChatbotScreen())),
                  ),
                  _FeatureCard(
                    icon: Icons.info,
                    label: 'Helpline Numbers',
                    color: const Color(0xFF3498DB),
                    onTap: () => _showHelplines(context),
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
        title: const Text('📞 Emergency Helplines'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🚨 Emergency: 112'),
            SizedBox(height: 8),
            Text('👩 Women Helpline: 1091'),
            SizedBox(height: 8),
            Text('🏠 Domestic Violence: 181'),
            SizedBox(height: 8),
            Text('👶 CHILDLINE: 1098'),
            SizedBox(height: 8),
            Text('👮 Police: 100'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
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