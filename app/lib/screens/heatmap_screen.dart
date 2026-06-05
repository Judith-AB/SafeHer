import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _ZoneInfo {
  final double lat;
  final double lng;
  final String riskLabel;
  final double probability;

  _ZoneInfo({
    required this.lat,
    required this.lng,
    required this.riskLabel,
    required this.probability,
  });
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  List<CircleMarker> circles = [];
  List<_ZoneInfo> zoneInfoList = [];
  bool _loaded = false;
  int _highRiskCount = 0;
  int _lowRiskCount = 0;
  double _rocAuc = 0.0;
  _ZoneInfo? _selectedZone;

  static const String _apiUrl =
      'https://us-central1-safeher-app-9251b.cloudfunctions.net/getPredictiveHeatmap';

  @override
  void initState() {
    super.initState();
    _loadMLHeatmap();
  }

  Future<void> _loadMLHeatmap() async {
    setState(() {
      _loaded = false;
      _selectedZone = null;
    });

    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final List data = body['predictions'];
        final double rocAuc = (body['roc_auc'] as num).toDouble();

        int high = 0;
        int low = 0;
        final List<CircleMarker> loaded = [];
        final List<_ZoneInfo> zones = [];

        for (var item in data) {
          final lat = (item['lat_zone'] as num).toDouble();
          final lng = (item['lng_zone'] as num).toDouble();
          final label = item['predicted_risk_label'] as String;
          final prob = (item['high_risk_probability'] as num).toDouble();
          final isHigh = label == 'HIGH';

          if (isHigh)
            high++;
          else
            low++;

          zones.add(_ZoneInfo(
            lat: lat,
            lng: lng,
            riskLabel: label,
            probability: prob,
          ));

          loaded.add(CircleMarker(
            point: LatLng(lat, lng),
            radius: 2000 + (prob * 2000),
            useRadiusInMeter: true,
            color: isHigh
                ? Colors.red.withValues(alpha: 0.4 + (prob * 0.3))
                : Colors.orange.withValues(alpha: 0.3),
            borderStrokeWidth: 1,
            borderColor: isHigh ? Colors.red : Colors.orange,
          ));
        }

        setState(() {
          circles = loaded;
          zoneInfoList = zones;
          _highRiskCount = high;
          _lowRiskCount = low;
          _rocAuc = rocAuc;
          _loaded = true;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() => _loaded = true);
    }
  }

  void _onMapTap(LatLng tappedPoint) {
    // Find nearest zone within 0.05 degrees
    _ZoneInfo? nearest;
    double minDist = double.infinity;

    for (var zone in zoneInfoList) {
      final dist = (zone.lat - tappedPoint.latitude).abs() +
          (zone.lng - tappedPoint.longitude).abs();
      if (dist < minDist && dist < 0.05) {
        minDist = dist;
        nearest = zone;
      }
    }

    setState(() => _selectedZone = nearest);
  }

  String _getDominantType(String riskLabel, double prob) {
    if (riskLabel == 'HIGH' && prob > 0.8) return 'Assault / Stalking';
    if (riskLabel == 'HIGH' && prob > 0.6) return 'Stalking / Harassment';
    return 'Harassment / Unsafe Area';
  }

  String _getSafetyTip(String riskLabel) {
    if (riskLabel == 'HIGH') {
      return '⚠️ Avoid this area at night. Stay in groups and keep emergency contacts ready.';
    }
    return '✅ Relatively safer area. Stay alert and report any incidents.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 80,75,56),
        title: const Text(
          ' ML Safety Heatmap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadMLHeatmap,
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(9.2, 76.8),
              initialZoom: 8,
              onTap: (_, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safeher.app',
              ),
              CircleLayer(circles: circles),
            ],
          ),

          // Loading indicator
          if (!_loaded)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading ML predictions...',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // Stats banner
          if (_loaded)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [
                      Text('$_highRiskCount',
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const Text('High Risk', style: TextStyle(fontSize: 11)),
                    ]),
                    Container(
                        width: 1, height: 40, color: Colors.grey.shade300),
                    Column(children: [
                      Text('$_lowRiskCount',
                          style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const Text('Low Risk', style: TextStyle(fontSize: 11)),
                    ]),
                    Container(
                        width: 1, height: 40, color: Colors.grey.shade300),
                    Column(children: [
                      Text(
                        '${(_rocAuc * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                            color: Color(0xFFE91E8C),
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                      const Text('Model AUC', style: TextStyle(fontSize: 11)),
                    ]),
                  ],
                ),
              ),
            ),

          // Tap info popup
          if (_loaded && _selectedZone != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: _selectedZone!.riskLabel == 'HIGH'
                                ? Colors.red
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedZone!.riskLabel} RISK ZONE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _selectedZone!.riskLabel == 'HIGH'
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                          ),
                        ]),
                        GestureDetector(
                          onTap: () => setState(() => _selectedZone = null),
                          child: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.warning_amber,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Dominant type: ${_getDominantType(_selectedZone!.riskLabel, _selectedZone!.probability)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.analytics, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Risk confidence: ${(_selectedZone!.probability * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedZone!.riskLabel == 'HIGH'
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getSafetyTip(_selectedZone!.riskLabel),
                        style: TextStyle(
                          fontSize: 12,
                          color: _selectedZone!.riskLabel == 'HIGH'
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Legend
          if (_loaded)
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
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
                    Text('🤖 ML Predicted Risk',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                    SizedBox(height: 6),
                    Row(children: [
                      CircleAvatar(radius: 6, backgroundColor: Colors.red),
                      SizedBox(width: 6),
                      Text('High Risk', style: TextStyle(fontSize: 11)),
                    ]),
                    SizedBox(height: 4),
                    Row(children: [
                      CircleAvatar(radius: 6, backgroundColor: Colors.orange),
                      SizedBox(width: 6),
                      Text('Low Risk', style: TextStyle(fontSize: 11)),
                    ]),
                    SizedBox(height: 4),
                    Text('Tap a zone for details',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
