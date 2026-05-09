import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  List<CircleMarker> circles = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final snap =
        await FirebaseFirestore.instance.collection('heatmap_buckets').get();

    final List<CircleMarker> loaded = [];
    for (var doc in snap.docs) {
      final data = doc.data();
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      final count = (data['count'] as num).toInt();
      loaded.add(CircleMarker(
        point: LatLng(lat, lng),
        radius: 3000,
        useRadiusInMeter: true,
        color: count > 5
            ? Colors.red.withValues(alpha: 0.6)
            : Colors.orange.withValues(alpha: 0.5),
        borderStrokeWidth: 2,
        borderColor: Colors.red,
      ));
    }

    setState(() {
      circles = loaded;
      _loaded = true;
    });
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(10.06, 76.4),
              initialZoom: 10,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safeher.app',
              ),
              CircleLayer(circles: circles),
            ],
          ),

          if (!_loaded) const Center(child: CircularProgressIndicator()),

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
                      CircleAvatar(radius: 8, backgroundColor: Colors.orange),
                      SizedBox(width: 8),
                      Text('Low (1-5 incidents)'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
