import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import 'driver_active_trip_screen.dart';

class DriverNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const DriverNavigationScreen({super.key, required this.request});

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  final MapController _mapController = MapController();

  static const LatLng _driverPos = LatLng(10.3220, 123.8920);
  static const LatLng _patientPos = LatLng(10.3157, 123.8854);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Map (expanded)
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(10.3188, 123.8887),
                    initialZoom: 14.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.resqmove.app',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_driverPos, _patientPos],
                          color: AppTheme.blue,
                          strokeWidth: 5,
                          borderColor: AppTheme.blue.withOpacity(0.2),
                          borderStrokeWidth: 8,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Driver
                        Marker(
                          point: _driverPos,
                          width: 56, height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: AppTheme.blue.withOpacity(0.5), blurRadius: 16, spreadRadius: 3)],
                            ),
                            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                        // Patient
                        Marker(
                          point: _patientPos,
                          width: 56, height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF1A35), AppTheme.crimson],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.55), blurRadius: 16, spreadRadius: 3)],
                            ),
                            child: const Icon(Icons.person_pin_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Top overlays
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.96),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: AppTheme.border),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10)],
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textDark, size: 17),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // ETA
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.96),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10)],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_rounded, color: AppTheme.warning, size: 17),
                              const SizedBox(width: 7),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ETA to Patient', style: GoogleFonts.outfit(fontSize: 9.5, color: AppTheme.textLight)),
                                  Text('--', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.warning)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Distance
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.96),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.blue.withOpacity(0.3)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10)],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.near_me_rounded, color: AppTheme.blue, size: 17),
                              const SizedBox(width: 7),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Distance', style: GoogleFonts.outfit(fontSize: 9.5, color: AppTheme.textLight)),
                                  Text('--', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.blue)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Recenter
                Positioned(
                  bottom: 18, right: 16,
                  child: GestureDetector(
                    onTap: () => _mapController.move(const LatLng(10.3188, 123.8887), 14.5),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10)],
                      ),
                      child: const Icon(Icons.my_location_rounded, color: AppTheme.blue, size: 22),
                    ),
                  ),
                ),

                // Legend chips
                Positioned(
                  bottom: 18, left: 16,
                  child: Row(
                    children: [
                      _LegendChip(color: AppTheme.blue, label: 'You'),
                      const SizedBox(width: 8),
                      _LegendChip(color: AppTheme.crimson, label: 'Patient'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom panel
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 24, offset: Offset(0, -6))],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44, height: 4,
                    decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 18),
                // Request info card
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
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.crimson.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppTheme.crimson.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.emergency_rounded, color: AppTheme.crimson, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.request['emergencyType'] ?? 'Emergency',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 13, color: AppTheme.textLight),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(widget.request['location'] ?? 'Unknown',
                                      style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textMid),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_rounded, color: AppTheme.success, size: 16),
                              const SizedBox(width: 6),
                              Text('Call', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.success)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Start navigation button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => DriverActiveTripScreen(request: widget.request)),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 19),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E88E5), Color(0xFF1565C0), Color(0xFF0D47A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AppTheme.blue.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 10)),
                        BoxShadow(color: AppTheme.blue.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.navigation_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Text('START NAVIGATION',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: 1.0)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)]),
          ),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        ],
      ),
    );
  }
}
