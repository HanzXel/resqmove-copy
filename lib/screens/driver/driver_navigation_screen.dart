import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../theme/app_theme.dart';
import '../../services/tracking_service.dart';
import '../../services/routing_service.dart';
import 'driver_active_trip_screen.dart';

class DriverNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const DriverNavigationScreen({super.key, required this.request});

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  final MapController _mapController = MapController();
  Timer? _locationTimer;
  Timer? _routeRefreshDebounce;

  late LatLng _patientPos;
  LatLng? _driverPos; // null until GPS resolves

  List<LatLng> _routePolyline = const [];
  bool _routingLoading = true;
  String _etaLabel = '--';
  String _distLabel = '--';

  @override
  void initState() {
    super.initState();
    _patientPos = _parsePatientLatLng();
    unawaited(_bootstrapNav());
    _locationTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _pushGps());
  }

  Future<void> _bootstrapNav() async {
    await _fetchDriverLocationOnce();
    await _loadRoute();
    unawaited(_pushGps());
  }

  LatLng _parsePatientLatLng() {
    final pl = widget.request['pickup_location'];
    if (pl is Map) {
      final lat = pl['latitude'];
      final lng = pl['longitude'];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return const LatLng(10.3157, 123.8854);
  }

  Future<void> _fetchDriverLocationOnce() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) {
        setState(() => _driverPos = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  String get _emergencyTitle =>
      (widget.request['emergencyType'] ??
              widget.request['emergency_type'] ??
              'Emergency')
          .toString();

  String get _addressLine {
    final pl = widget.request['pickup_location'];
    if (pl is Map && pl['address'] != null) {
      final a = pl['address'].toString().trim();
      if (a.isNotEmpty) return a;
    }
    return (widget.request['pickup_address'] ??
            widget.request['location'] ??
            'Unknown')
        .toString();
  }

  LatLng get _effectiveDriverPos =>
      _driverPos ?? const LatLng(10.3220, 123.8920);

  LatLng get _mapCenter => LatLng(
        (_patientPos.latitude + _effectiveDriverPos.latitude) / 2,
        (_patientPos.longitude + _effectiveDriverPos.longitude) / 2,
      );

  Future<void> _pushGps() async {
    final id = widget.request['id']?.toString();
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) {
        setState(() {
          _driverPos = LatLng(pos.latitude, pos.longitude);
          if (_routePolyline.isEmpty) _applyStraightLineMetrics();
        });
      }
      await TrackingService.instance.pushDriverLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        activeRequestId: id,
      );
      _scheduleRouteRefresh();
    } catch (_) {}
  }

  Future<void> _loadRoute() async {
    if (mounted) setState(() => _routingLoading = true);
    final from = _driverPos;
    if (from == null) {
      if (mounted) setState(() => _routingLoading = false);
      return;
    }
    final route =
        await RoutingService.instance.fetchDrivingRoute(from, _patientPos);
    if (!mounted) return;

    if (route != null && route.points.length >= 2) {
      setState(() {
        _routingLoading = false;
        _routePolyline = route.points;
        _distLabel = _formatDistanceKm(route.distanceMeters / 1000.0);
        _etaLabel = _formatDriveEta(route.durationSeconds);
      });
    } else {
      setState(() {
        _routingLoading = false;
        _routePolyline = [from, _patientPos];
        _applyStraightLineMetrics();
      });
    }
  }

  void _applyStraightLineMetrics() {
    final from = _driverPos;
    if (from == null) return;
    const d = Distance();
    final meters = d.as(LengthUnit.Meter, from, _patientPos);
    _distLabel = _formatDistanceKm(meters / 1000.0);
    const double avgSpeedMps = 40.0 / 3.6;
    _etaLabel = _formatDriveEta(meters / avgSpeedMps);
  }

  String _formatDistanceKm(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  String _formatDriveEta(double durationSeconds) {
    final minutes = (durationSeconds / 60).ceil();
    if (minutes < 1) return '<1 min';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  void _scheduleRouteRefresh() {
    _routeRefreshDebounce?.cancel();
    _routeRefreshDebounce =
        Timer(const Duration(seconds: 8), () => unawaited(_loadRoute()));
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _routeRefreshDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverPos = _driverPos;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                // ── Map ──────────────────────────────────────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                      initialCenter: _mapCenter, initialZoom: 14.5),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.resqmove.app',
                    ),
                    // Route polyline — only draw when we have ≥ 2 distinct points
                    if (_routePolyline.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePolyline,
                            color: AppTheme.blue,
                            strokeWidth: 5,
                            borderColor: AppTheme.blue.withOpacity(0.25),
                            borderStrokeWidth: 9,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Patient marker (red pin)
                        Marker(
                          point: _patientPos,
                          width: 56,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF1A35),
                                  AppTheme.crimson
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: AppTheme.crimson.withOpacity(0.55),
                                    blurRadius: 16,
                                    spreadRadius: 3)
                              ],
                            ),
                            child: const Icon(Icons.person_pin_rounded,
                                color: Colors.white, size: 24),
                          ),
                        ),
                        // Driver marker (blue truck) — only when GPS resolved
                        if (driverPos != null)
                          Marker(
                            point: driverPos,
                            width: 56,
                            height: 56,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          AppTheme.blue.withOpacity(0.5),
                                      blurRadius: 16,
                                      spreadRadius: 3)
                                ],
                              ),
                              child: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: Colors.white,
                                  size: 24),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // ── Top overlay: back + ETA + Distance ──────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.96),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: AppTheme.border),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 10)
                              ],
                            ),
                            child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppTheme.textDark,
                                size: 17),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // ETA chip
                        _InfoChip(
                          icon: Icons.timer_rounded,
                          iconColor: AppTheme.warning,
                          label: 'ETA to Patient',
                          value: _routingLoading ? '…' : _etaLabel,
                          valueColor: AppTheme.warning,
                          borderColor: AppTheme.warning.withOpacity(0.3),
                        ),
                        const Spacer(),

                        // Distance chip
                        _InfoChip(
                          icon: Icons.near_me_rounded,
                          iconColor: AppTheme.blue,
                          label: 'Distance',
                          value: _routingLoading ? '…' : _distLabel,
                          valueColor: AppTheme.blue,
                          borderColor: AppTheme.blue.withOpacity(0.3),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Legend bottom-left ───────────────────────────────────
                Positioned(
                  bottom: 18,
                  left: 16,
                  child: Row(
                    children: [
                      _LegendChip(color: AppTheme.blue, label: 'You'),
                      const SizedBox(width: 8),
                      _LegendChip(color: AppTheme.crimson, label: 'Patient'),
                    ],
                  ),
                ),

                // ── Re-center button bottom-right ────────────────────────
                Positioned(
                  bottom: 18,
                  right: 16,
                  child: GestureDetector(
                    onTap: () =>
                        _mapController.move(_mapCenter, 14.5),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 10)
                        ],
                      ),
                      child: const Icon(Icons.my_location_rounded,
                          color: AppTheme.blue, size: 22),
                    ),
                  ),
                ),

                // ── GPS loading indicator ─────────────────────────────────
                if (driverPos == null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.blue)),
                              const SizedBox(width: 10),
                              Text('Getting your location…',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom sheet ─────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 24,
                    offset: Offset(0, -6))
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.crimson.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: AppTheme.crimson.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.emergency_rounded,
                            color: AppTheme.crimson, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_emergencyTitle,
                                style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textDark)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 13, color: AppTheme.textLight),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(_addressLine,
                                      style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          color: AppTheme.textMid),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                                color: AppTheme.success.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_rounded,
                                  color: AppTheme.success, size: 16),
                              const SizedBox(width: 6),
                              Text('Call',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.success)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DriverActiveTripScreen(
                              request: widget.request)),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 19),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E88E5),
                          Color(0xFF1565C0),
                          Color(0xFF0D47A1)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: AppTheme.blue.withOpacity(0.45),
                            blurRadius: 24,
                            offset: const Offset(0, 10)),
                        BoxShadow(
                            color: AppTheme.blue.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.navigation_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Text('START NAVIGATION',
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable info chip (ETA / Distance) ─────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final Color borderColor;

  const _InfoChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.10), blurRadius: 10)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 7),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.outfit(
                      fontSize: 9.5, color: AppTheme.textLight)),
              Text(value,
                  style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: valueColor)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Legend chip ──────────────────────────────────────────────────────────────
class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.4), blurRadius: 4)
                ]),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
        ],
      ),
    );
  }
}
