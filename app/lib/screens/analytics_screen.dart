import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safeher/theme.dart';
import '../constants.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

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
          "Safety Analytics",
          style: TextStyle(color: AppTheme.creamLight),
        ),
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('analytics')
            .doc('summary')
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.deepCharcoal),
            );
          }

          final data = (snapshot.data!.data() as Map<String, dynamic>?) ?? {};
          final byType = Map<String, dynamic>.from(data['by_type'] ?? {});
          final byBand = Map<String, dynamic>.from(data['by_hour_band'] ?? {});

          int count(String k) => (byType[k] as num?)?.toInt() ?? 0;
          String topKey(Map<String, dynamic> m) {
            if (m.isEmpty) return 'Unknown';
            return m.entries
                .reduce((a, b) => (a.value as num) >= (b.value as num) ? a : b)
                .key;
          }

          const bandLabels = {
            '00-06': '12 AM - 6 AM',
            '06-12': '6 AM - 12 PM',
            '12-18': '12 PM - 6 PM',
            '18-24': '6 PM - 12 AM',
          };

          int total = (data['totalIncidents'] as num?)?.toInt() ?? 0;
          String peakHours = bandLabels[topKey(byBand)] ?? 'Unknown';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildCard(
                  title: "Total Incidents",
                  value: total.toString(),
                  color: AppTheme.deepCharcoal,
                  icon: Icons.warning,
                ),

                const SizedBox(height: 16),

                const SizedBox(height: 20),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Incident Type Analysis",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepCharcoal,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                for (final c in AppConstants.categories) ...[
                  _buildProgressTile(
                    label: c,
                    value: count(c),
                    total: total,
                    color: AppTheme.oliveMuted,
                  ),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 30),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.deepCharcoal.withOpacity(0.1),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Peak Unsafe Hours",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepCharcoal,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Most incidents reported between $peakHours",
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.deepCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.creamLight,
            size: 40,
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.creamLight,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.creamLight,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProgressTile({
    required String label,
    required int value,
    required int total,
    required Color color,
  }) {
    final double progress = total == 0 ? 0 : value / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepCharcoal,
                ),
              ),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.deepCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            color: color,
            backgroundColor: AppTheme.beigeMid,
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}