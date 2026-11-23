// categories must match functions/index.js and firestore.rules
class AppConstants {
  static const categories = [
    'Assault',
    'Stalking',
    'Eve Teasing',
    'Harassment',
    'Unsafe Area',
  ];

  static const heatmapUrl =
      'https://us-central1-safeher-app-9251b.cloudfunctions.net/getPredictiveHeatmap';

  // ~111 m cell; applied before any location leaves the device
  static double roundCoord(double x) => (x * 1000).round() / 1000;
}
