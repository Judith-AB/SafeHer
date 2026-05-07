import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HeatmapScreen extends StatelessWidget {
  const HeatmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE91E8C),
        title: const Text(
          '🗺️ Safety Heatmap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('heatmap_buckets')
            .snapshots(),
        builder: (context, snapshot) {
          List<CircleMarker> circles = [];

          if (snapshot.hasData) {
            circles = snapshot.data!.docs.map((doc) {
              final count = (doc['count'] as num).toInt();
              return CircleMarker(
                point: LatLng(
                  (doc['lat'] as num).toDouble(),
                  (doc['lng'] as num).toDouble(),
                ),
                radius: 200,
                useRadiusInMeter: true,
                color: count > 5
                    ? Colors.red.withValues(alpha: 0.5)
                    : Colors.orange.withValues(alpha: 0.35),
                borderStrokeWidth: 0,
              );
            }).toList();
          }

          return Stack(
            children: [
              FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(8.5241, 76.9366),
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.safeher.app',
                  ),
                  CircleLayer(circles: circles),
                ],
              ),

              // Legend
              Positioned(
                bottom: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Incident Density',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(radius: 8, backgroundColor: Colors.red),
                          SizedBox(width: 8),
                          Text('High (5+ incidents)'),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          CircleAvatar(
                              radius: 8, backgroundColor: Colors.orange),
                          SizedBox(width: 8),
                          Text('Low (1-5 incidents)'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      ),
    );
  }
}
