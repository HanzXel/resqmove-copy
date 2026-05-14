import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../services/location_service.dart';   // ← NEW
import '../../services/tracking_service.dart';    // ← NEW (push location to server)
import 'driver_navigation_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  bool _isAvailable = true;
  bool _hasIncomingRequest = false;
  final MapController _mapController = MapController();

  // ── REAL GPS state ──────────────────────────────────────────────────────────
  LatLng _driverPos = const LatLng(10.3220, 123.8920); // fallback until GPS loads
  String _locationLabel = 'Getting location...';
  StreamSubscription<Position>? _locationSub;
  // ────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  // ── Get initial position then start streaming updates ─────────────────────

  Future<void> _initLocation() async {
    // One-shot get for immediate map center
    final result = await LocationService.instance.getCurrentLocation();
    if (mounted) {
      setState(() {
        _driverPos = LatLng(result.latitude, result.longitude);
        _locationLabel = result.address ?? 'Cebu City, PH';
      });
      _mapController.move(_driverPos, 15);
    }

    // Start streaming — updates map marker as driver moves
    _locationSub = LocationService.instance.startTracking().listen((position) {
      if (!mounted) return;
      final newPos = LatLng(position.latitude, position.longitude);
      setState(() => _driverPos = newPos);

      // Push to server so patient can track the driver
      TrackingService.instance.pushDriverLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });
  }

  void _toggleAvailability(bool val) {
    HapticFeedback.mediumImpact();
    setState(() => _isAvailable = val);
  }

  void _acceptRequest() {
    HapticFeedback.heavyImpact();
    setState(() => _hasIncomingRequest = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverNavigationScreen(
          request: const {},
          driverPosition: _driverPos,   // ← pass real position
        ),
      ),
    );
  }

  void _declineRequest() {
    HapticFeedback.mediumImpact();
    setState(() => _hasIncomingRequest = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Request declined. It will be reassigned.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.textDark,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildStatsRow()),
          if (_hasIncomingRequest && _isAvailable)
            SliverToBoxAdapter(child: _buildIncomingRequest()),
          SliverToBoxAdapter(child: _buildMap()),
          SliverToBoxAdapter(child: _buildActivitySection()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 5))],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF1A35), AppTheme.crimson],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.40), blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 13),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ResQmove',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                      Text('Driver Portal',
                          style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Spacer(),
                  _StatusPill(isAvailable: _isAvailable),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE8EDF5), Color(0xFFD5DCE9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10)],
                        ),
                        child: const Icon(Icons.person_rounded, color: AppTheme.textMid, size: 28),
                      ),
                      Positioned(
                        bottom: 1, right: 1,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: _isAvailable ? AppTheme.success : AppTheme.textLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 13),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Good day, Driver!',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                      Text('Ready to save lives today?',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textLight)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: AppTheme.textMid, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: _AvailabilityToggle(isAvailable: _isAvailable, onToggle: _toggleAvailability),
            ),
            Container(height: 1, color: AppTheme.border),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashSectionLabel(label: "TODAY'S OVERVIEW"),
          const SizedBox(height: 14),
          Row(
            children: const [
              _StatCard(value: '0', label: 'Pending', sublabel: 'Requests', color: AppTheme.warning, icon: Icons.notifications_active_rounded),
              SizedBox(width: 10),
              _StatCard(value: '0', label: 'Trips', sublabel: 'Today', color: AppTheme.blue, icon: Icons.airport_shuttle_rounded),
              SizedBox(width: 10),
              _StatCard(value: '0', label: 'Avg', sublabel: 'Response', color: AppTheme.success, icon: Icons.timer_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequest() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF1A35), Color(0xFFD0021B), Color(0xFF9B0015)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: AppTheme.crimson.withOpacity(0.48), blurRadius: 32, offset: const Offset(0, 14)),
            BoxShadow(color: AppTheme.crimson.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white.withOpacity(0.30)),
                  ),
                  child: Row(
                    children: [
                      _PulsingWhiteDot(),
                      const SizedBox(width: 7),
                      Text('INCOMING REQUEST',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 1.0)),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.notification_important_rounded, color: Colors.white, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: Colors.white.withOpacity(0.28)),
                  ),
                  child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cardiac Arrest',
                          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -0.5)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white70, size: 14),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text('Ayala Center Cebu, Cebu City',
                                style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _RequestChip(icon: Icons.timer_outlined, label: '~6 min away'),
                const SizedBox(width: 8),
                _RequestChip(icon: Icons.near_me_rounded, label: '1.8 km'),
                const SizedBox(width: 8),
                _RequestChip(icon: Icons.warning_rounded, label: 'Critical'),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _declineRequest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.30)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.close_rounded, color: Colors.white, size: 19),
                          const SizedBox(width: 8),
                          Text('DECLINE',
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800,
                                  color: Colors.white, letterSpacing: 0.8)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _acceptRequest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, color: AppTheme.crimson, size: 21),
                          const SizedBox(width: 9),
                          Text('ACCEPT',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900,
                                  color: AppTheme.crimson, letterSpacing: 0.8)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DashSectionLabel(label: 'YOUR LOCATION'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppTheme.success.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(width: 7, height: 7,
                      decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('GPS Active',
                        style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.success)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 22, offset: const Offset(0, 8)),
                ],
              ),
              child: SizedBox(
                height: 230,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(initialCenter: _driverPos, initialZoom: 15),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.resqmove.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _driverPos,   // ← REAL position
                              width: 60, height: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF1A35), AppTheme.crimson],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.crimson.withOpacity(0.55), blurRadius: 22, spreadRadius: 4),
                                  ],
                                ),
                                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 26),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.97),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppTheme.crimson, size: 14),
                            const SizedBox(width: 5),
                            Text(_locationLabel,   // ← REAL label
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12, right: 12,
                      child: GestureDetector(
                        onTap: () => _mapController.move(_driverPos, 15),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                          ),
                          child: const Icon(Icons.my_location_rounded, color: AppTheme.blue, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.blue.withOpacity(0.06), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.blue.withOpacity(0.13)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.blue.withOpacity(0.16)),
                  ),
                  child: const Icon(Icons.access_time_rounded, color: AppTheme.blue, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Shift',
                          style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
                      Text('Shift data not available',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                    ],
                  ),
                ),
                _DutyBadge(isOnDuty: _isAvailable),
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (!_hasIncomingRequest)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: AppTheme.textLight, size: 24),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No Incoming Requests',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                        const SizedBox(height: 3),
                        Text('Requests will appear here when dispatched.',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textLight, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(child: _QuickActionBtn(icon: Icons.phone_rounded, label: 'Call Dispatch', color: AppTheme.success)),
              const SizedBox(width: 12),
              Expanded(child: _QuickActionBtn(icon: Icons.report_problem_outlined, label: 'Report Issue', color: AppTheme.warning)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  WIDGETS (unchanged from original)
// ═══════════════════════════════════════════

class _DashSectionLabel extends StatelessWidget {
  final String label;
  const _DashSectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 4, height: 16,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppTheme.crimson, AppTheme.crimsonDark],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppTheme.textLight, letterSpacing: 1.3)),
    ]);
  }
}

class _PulsingWhiteDot extends StatefulWidget {
  @override
  State<_PulsingWhiteDot> createState() => _PulsingWhiteDotState();
}

class _PulsingWhiteDotState extends State<_PulsingWhiteDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.3 + _ctrl.value * 0.4),
              blurRadius: 3 + _ctrl.value * 6, spreadRadius: _ctrl.value * 2)],
        ),
      ),
    );
  }
}

class _RequestChip extends StatelessWidget {
  final IconData icon; final String label;
  const _RequestChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.17),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Row(children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _DutyBadge extends StatelessWidget {
  final bool isOnDuty;
  const _DutyBadge({required this.isOnDuty});
  @override
  Widget build(BuildContext context) {
    final color = isOnDuty ? AppTheme.success : AppTheme.textLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(isOnDuty ? 'On Duty' : 'Off Duty',
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _QuickActionBtn({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isAvailable;
  const _StatusPill({required this.isAvailable});
  @override
  Widget build(BuildContext context) {
    final color = isAvailable ? AppTheme.success : AppTheme.textLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isAvailable ? AppTheme.success.withOpacity(0.09) : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isAvailable ? AppTheme.success.withOpacity(0.30) : AppTheme.border),
      ),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(isAvailable ? 'Available' : 'Offline',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _AvailabilityToggle extends StatelessWidget {
  final bool isAvailable; final ValueChanged<bool> onToggle;
  const _AvailabilityToggle({required this.isAvailable, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: isAvailable ? AppTheme.success.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAvailable ? AppTheme.success.withOpacity(0.30) : AppTheme.border, width: 1.5),
        boxShadow: [BoxShadow(color: (isAvailable ? AppTheme.success : Colors.black).withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: isAvailable ? AppTheme.success.withOpacity(0.11) : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isAvailable ? AppTheme.success.withOpacity(0.2) : AppTheme.border),
          ),
          child: Icon(isAvailable ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: isAvailable ? AppTheme.success : AppTheme.textLight, size: 24),
        ),
        const SizedBox(width: 15),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isAvailable ? 'You are Available' : 'You are Offline',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          Text(isAvailable ? 'Accepting incoming requests' : 'Not accepting requests',
              style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textLight)),
        ]),
        const Spacer(),
        Switch(value: isAvailable, onChanged: onToggle,
            activeColor: AppTheme.success, activeTrackColor: AppTheme.success.withOpacity(0.22),
            inactiveThumbColor: AppTheme.textLight),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label, sublabel; final Color color; final IconData icon;
  const _StatCard({required this.value, required this.label, required this.sublabel, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.11)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(13),
                border: Border.all(color: color.withOpacity(0.15))),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 14),
          Text(value, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMid)),
          Text(sublabel, style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textLight)),
        ]),
      ),
    );
  }
}
