import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF2F8),

      appBar: AppBar(
        backgroundColor: Colors.pink,

        title: const Text(
          "Safety Analytics",
          style: TextStyle(color: Colors.white),
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
              child: CircularProgressIndicator(),
            );
          }

          var data =
              snapshot.data!.data()
                  as Map<String, dynamic>;

          int total =
              data['totalIncidents'] ?? 0;

          int harassment =
              data['harassment'] ?? 0;

          int theft =
              data['theft'] ?? 0;

          int stalking =
              data['stalking'] ?? 0;

          int assault =
              data['assault'] ?? 0;

          int other =
              data['other'] ?? 0;

          String area = "Unknown";

          if (data['mostUnsafeArea'] != null &&
              data['mostUnsafeArea']
                  .toString()
                  .trim()
                  .isNotEmpty) {

            area = data['mostUnsafeArea'];
          }

          String peakHours =
              data['peakUnsafeHours'] ??
                  "Unknown";

          return SingleChildScrollView(
            padding:
                const EdgeInsets.all(16),

            child: Column(
              children: [

                /// TOTAL INCIDENTS
                _buildCard(
                  title: "Total Incidents",
                  value: total.toString(),
                  color: Colors.redAccent,
                  icon: Icons.warning,
                ),

                const SizedBox(height: 16),

                /// MOST UNSAFE AREA
                _buildCard(
                  title: "Most Unsafe Area",
                  value: area,
                  color: Colors.orange,
                  icon: Icons.location_on,
                ),

                const SizedBox(height: 20),

                /// INCIDENT TYPE ANALYSIS
                const Align(
                  alignment:
                      Alignment.centerLeft,

                  child: Text(
                    "Incident Type Analysis",

                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildProgressTile(
                  label: "Harassment",
                  value: harassment,
                  color: Colors.pink,
                ),

                const SizedBox(height: 12),

                _buildProgressTile(
                  label: "Theft",
                  value: theft,
                  color: Colors.blue,
                ),

                const SizedBox(height: 12),

                _buildProgressTile(
                  label: "Stalking",
                  value: stalking,
                  color: Colors.purple,
                ),

                const SizedBox(height: 12),

                _buildProgressTile(
                  label: "Assault",
                  value: assault,
                  color: Colors.red,
                ),

                const SizedBox(height: 12),

                _buildProgressTile(
                  label: "Other",
                  value: other,
                  color: Colors.green,
                ),

                const SizedBox(height: 30),

                /// INCIDENT TREND
                Container(
                  width: double.infinity,

                  padding:
                      const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius:
                        BorderRadius.circular(
                            18),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey
                            .withOpacity(0.2),

                        blurRadius: 8,
                      )
                    ],
                  ),

                  child: const Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [

                      Text(
                        "Incident Trend",

                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 20),

                      Text(
                        "Incidents are increasing in the last 7 days.",

                        style:
                            TextStyle(
                          fontSize: 16,
                        ),
                      ),

                      SizedBox(height: 10),

                      LinearProgressIndicator(
                        value: 0.7,
                        minHeight: 10,
                        backgroundColor:
                            Colors.grey,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                /// PEAK UNSAFE HOURS
                Container(
                  width: double.infinity,

                  padding:
                      const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius:
                        BorderRadius.circular(
                            18),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey
                            .withOpacity(0.2),

                        blurRadius: 8,
                      )
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [

                      const Text(
                        "Peak Unsafe Hours",

                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        "Most incidents reported between $peakHours",

                        style:
                            const TextStyle(
                          fontSize: 16,
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

      padding:
          const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: color,

        borderRadius:
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color:
                color.withOpacity(0.3),

            blurRadius: 10,
          )
        ],
      ),

      child: Row(
        children: [

          Icon(
            icon,
            color: Colors.white,
            size: 40,
          ),

          const SizedBox(width: 20),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              Text(
                title,

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                value,

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
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
      padding:
          const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(16),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,

            children: [

              Text(
                label,

                style: const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              Text(
                value.toString(),

                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          LinearProgressIndicator(
            value: progress,
            color: color,
            minHeight: 10,
            borderRadius:
                BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}