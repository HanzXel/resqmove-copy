import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/driver_service.dart';
import 'driver_dashboard_screen.dart';
import 'driver_profile_screen.dart';

// ─────────────────────────────────────────────
//  TRIPS SCREEN (real data)
// ─────────────────────────────────────────────
class _DriverTripsScreen extends StatefulWidget {
  const _DriverTripsScreen();

  @override
  State<_DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<_DriverTripsScreen> {
  List<AmbulanceRequestModel> _trips = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await DriverService.instance.getTripHistory();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success) {
        _trips = result.requests;
      } else {
        _error = result.errorMessage ?? 'Could not load trips.';
      }
    });
  }

  int get _completed => _trips.where((t) => t.status == RequestStatus.completed).length;
  int get _cancelled => _trips.where((t) => t.status == RequestStatus.cancelled).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppTheme.border),
            ),
            title: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF1A35), AppTheme.crimson],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.38), blurRadius: 12, offset: const Offset(0, 5))],
                  ),
                  child: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip History',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                    Text('Your completed dispatches',
                        style: GoogleFonts.outfit(fontSize: 10.5, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMid),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Summary cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  _TripStatCard(
                    value: _loading ? '-' : '$_completed',
                    label: 'Completed',
                    color: AppTheme.success,
                    icon: Icons.check_circle_rounded,
                  ),
                  const SizedBox(width: 10),
                  _TripStatCard(
                    value: _loading ? '-' : '$_cancelled',
                    label: 'Cancelled',
                    color: AppTheme.crimson,
                    icon: Icons.cancel_rounded,
                  ),
                  const SizedBox(width: 10),
                  _TripStatCard(
                    value: _loading ? '-' : '${_trips.length}',
                    label: 'Total',
                    color: AppTheme.blue,
                    icon: Icons.list_alt_rounded,
                  ),
                ],
              ),
            ),
          ),

          // Loading state
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )

          // Error state
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 48),
                  const SizedBox(height: 14),
                  Text(_error!, style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )

          // Empty state
          else if (_trips.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(Icons.history_rounded, color: AppTheme.textLight, size: 34),
                  ),
                  const SizedBox(height: 18),
                  Text('No trips yet',
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  Text('Your completed and cancelled trips\nwill appear here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textLight, height: 1.5)),
                  const SizedBox(height: 80),
                ],
              ),
            )

          // Trip list
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) return const SizedBox(height: 16);
                  final trip = _trips[index - 1];
                  return _TripCard(trip: trip);
                },
                childCount: _trips.length + 1,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TRIP CARD
// ─────────────────────────────────────────────
class _TripCard extends StatelessWidget {
  final AmbulanceRequestModel trip;
  const _TripCard({required this.trip});

  bool get _isCompleted => trip.status == RequestStatus.completed;

  @override
  Widget build(BuildContext context) {
    final statusColor = _isCompleted ? AppTheme.success : AppTheme.crimson;
    final statusLabel = _isCompleted ? 'Completed' : 'Cancelled';
    final addr = trip.pickupLocation.address ??
        '${trip.pickupLocation.latitude.toStringAsFixed(4)}, ${trip.pickupLocation.longitude.toStringAsFixed(4)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(color: statusColor.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 5)),
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: statusColor.withOpacity(0.18)),
                  ),
                  child: Icon(
                    _isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: statusColor, size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.emergencyType.label,
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                      const SizedBox(height: 2),
                      Text(addr,
                          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textLight),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withOpacity(0.22)),
                  ),
                  child: Text(statusLabel,
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            if (trip.id != null && trip.id!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: AppTheme.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TripDetailRow(icon: Icons.tag_rounded, text: 'ID: ${trip.id!.length > 8 ? trip.id!.substring(0, 8) : trip.id!}', color: AppTheme.textLight),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripDetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _TripDetailRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textMid),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _TripStatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  const _TripStatCard({required this.value, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.12)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.18)),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textDark)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.outfit(fontSize: 10.5, color: AppTheme.textLight)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHELL
// ─────────────────────────────────────────────
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DriverDashboardScreen(),
    _DriverTripsScreen(),
    DriverProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _DriverBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = i);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BOTTOM NAV
// ─────────────────────────────────────────────
class _DriverBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _DriverBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DriverNavItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              index: 0,
              current: currentIndex,
              onTap: onTap,
            ),
            _DriverNavItem(
              icon: Icons.history_rounded,
              label: 'Trips',
              index: 1,
              current: currentIndex,
              onTap: onTap,
            ),
            _DriverNavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              index: 2,
              current: currentIndex,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final Function(int) onTap;
  final int? badge;

  const _DriverNavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
            horizontal: active ? 26 : 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFFFF1A35), Color(0xFFD0021B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppTheme.crimson.withOpacity(0.40),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    key: ValueKey('$label-$active'),
                    color: active ? Colors.white : AppTheme.textLight,
                    size: 22,
                  ),
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                          color: AppTheme.warning, shape: BoxShape.circle),
                      child: Center(
                        child: Text('$badge',
                            style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
            if (active) ...[
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }
}
