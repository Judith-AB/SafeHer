import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safeher/theme.dart';

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
            : Colors.red.withValues(alpha: 0.25), 
        borderStrokeWidth: 2,
        borderColor: count > 5 ? Colors.red : Colors.red.withValues(alpha: 0.4),
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
      backgroundColor: AppTheme.creamLight,
      appBar: AppBar(
        backgroundColor: AppTheme.deepCharcoal,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.creamLight),
        title: const Text(
          'Safety Heatmap',
          style: TextStyle(color: AppTheme.creamLight, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.creamLight),
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

          if (!_loaded) const Center(child: CircularProgressIndicator(color: AppTheme.deepCharcoal)),

          // Legend
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.deepCharcoal.withValues(alpha: 0.1),
                    blurRadius: 8,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Incident Density',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepCharcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const CircleAvatar(radius: 8, backgroundColor: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'High (5+ incidents)',
                        style: TextStyle(color: AppTheme.deepCharcoal.withOpacity(0.8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(radius: 8, backgroundColor: Colors.red.withValues(alpha: 0.3)),
                      const SizedBox(width: 8),
                      Text(
                        'Low (1-5 incidents)',
                        style: TextStyle(color: AppTheme.deepCharcoal.withOpacity(0.8)),
                      ),
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