// ─────────────────────────────────────────────────────────────────────────────
//  OSRM public demo router — road geometry for map polyline (no API key).
//  Fair-use: suitable for development; for production use your own OSRM/ORS.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsrmRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const OsrmRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class RoutingService {
  RoutingService._();
  static final RoutingService instance = RoutingService._();

  static const _userAgent = 'ResQMove/1.0 (ambulance-app; contact: dev-local)';
  static const _timeout = Duration(seconds: 12);

  /// Driving route [from] → [to] using OSRM demo server.
  Future<OsrmRoute?> fetchDrivingRoute(LatLng from, LatLng to) async {
    final coords =
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coords'
      '?overview=full&geometries=geojson',
    );
    try {
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      final routes = json?['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final route0 = routes.first as Map<String, dynamic>;
      final geometry = route0['geometry'] as Map<String, dynamic>?;
      final coordsList = geometry?['coordinates'] as List<dynamic>?;
      if (coordsList == null || coordsList.isEmpty) return null;

      final points = <LatLng>[];
      for (final c in coordsList) {
        if (c is List && c.length >= 2) {
          final lon = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          points.add(LatLng(lat, lon));
        }
      }
      if (points.length < 2) return null;

      final dist = (route0['distance'] as num?)?.toDouble() ?? 0;
      final dur = (route0['duration'] as num?)?.toDouble() ?? 0;
      return OsrmRoute(
        points: points,
        distanceMeters: dist,
        durationSeconds: dur,
      );
    } catch (_) {
      return null;
    }
  }
}
