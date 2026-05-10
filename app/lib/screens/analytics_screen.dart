import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safeher/theme.dart';

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

          var data = snapshot.data!.data() as Map<String, dynamic>;

          int total = data['totalIncidents'] ?? 0;
          int harassment = data['harassment'] ?? 0;
          int theft = data['theft'] ?? 0;
          int stalking = data['stalking'] ?? 0;
          int assault = data['assault'] ?? 0;
          int other = data['other'] ?? 0;

          String area = "Unknown";
          if (data['mostUnsafeArea'] != null &&
              data['mostUnsafeArea'].toString().trim().isNotEmpty) {
            area = data['mostUnsafeArea'];
          }

          String peakHours = data['peakUnsafeHours'] ?? "Unknown";

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

                _buildCard(
                  title: "Most Unsafe Area",
                  value: area,
                  color: AppTheme.oliveMuted,
                  icon: Icons.location_on,
                ),

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

                _buildProgressTile(
                  label: "Harassment",
                  value: harassment,
                  color: AppTheme.oliveMuted,
                ),

                const SizedBox(height: 12),

                _buildProgressTile(
                  label: "Theft",
                  value: theft,
                  color: AppTheme.oliveMuted,
                ),

                const SizedBox(height: 12),

                _buildProgressTile(
                  label: "Stalking",
                  value: stalking,
                  color: AppTheme.oliveMuted,
                ),

                const SizedBox(height: 12),

                _buildProgressTile(
                  label: "Assault",
                  value: assault,
                  color: AppTheme.oliveMuted,
                ),

                const SizedBox(height: 12),

                _buildProgressTile(
                  label: "Other",
                  value: other,
                  color: AppTheme.oliveMuted,
                ),

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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Incident Trend",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepCharcoal,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Incidents are increasing in the last 7 days.",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.deepCharcoal,
                        ),
                      ),
                      SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: 0.7,
                        minHeight: 10,
                        backgroundColor: AppTheme.beigeMid,
                        color: AppTheme.deepCharcoal,
                      ),
                    ],
                  ),
                ),

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
    required Color color,
  }) {
    double progress = value / 10;
    if (progress > 1) {
      progress = 1;
    }

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