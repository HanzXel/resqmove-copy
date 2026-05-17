import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../services/request_service.dart';
import '../services/registration_service.dart';
import '../services/session_service.dart';
import 'driver/driver_login_screen.dart';
import 'services_screen.dart';

// ─────────────────────────────────────────────
//  PREPAREDNESS SHARE COPY (barangay-aware)
// ─────────────────────────────────────────────

String _preparednessShareBody(String? barangay) {
  final b = (barangay != null && barangay.isNotEmpty) ? barangay : 'our barangay';
  return '🚑 ResQmove is now available in $b!\n\n'
      'Download the app now so you\'re ready when an emergency happens. '
      'You can call for an ambulance in seconds.\n\n'
      '✅ Free to download\n'
      '✅ Register your address for faster dispatch\n'
      '✅ Real-time ambulance tracking\n\n'
      'Install it now. Share with family & neighbors in $b.';
}

Future<({double lat, double lng, String address})> _resolvePickupForRequest() async {
  const double fallbackLat = 10.3220;
  const double fallbackLng = 123.8920;
  final reg = await RegistrationService.instance.loadRegistration();
  final savedAddress = reg?.address.trim();
  String address = (savedAddress != null && savedAddress.isNotEmpty)
      ? savedAddress
      : 'Cebu City, PH';

  var lat = fallbackLat;
  var lng = fallbackLng;

  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    return (lat: lat, lng: lng, address: address);
  }

  try {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    lat = pos.latitude;
    lng = pos.longitude;
  } catch (_) {}

  return (lat: lat, lng: lng, address: address);
}

// ─────────────────────────────────────────────
//  REQUEST AMBULANCE MODAL
// ─────────────────────────────────────────────

void _showRequestAmbulanceModal(BuildContext context) {
  String? selectedEmergencyType;
  bool isSubmitting = false;

  const List<Map<String, dynamic>> emergencyTypes = [
    {'label': 'Cardiac Arrest',                   'icon': Icons.favorite_border_rounded},
    {'label': 'Stroke',                            'icon': Icons.psychology_rounded},
    {'label': 'Severe Trauma / Injury',            'icon': Icons.personal_injury_rounded},
    {'label': 'Road Traffic Accident',             'icon': Icons.car_crash_rounded},
    {'label': 'Difficulty Breathing',              'icon': Icons.air_rounded},
    {'label': 'Unconscious / Unresponsive',        'icon': Icons.hotel_rounded},
    {'label': 'Seizure',                           'icon': Icons.bolt_rounded},
    {'label': 'Severe Bleeding',                   'icon': Icons.water_drop_rounded},
    {'label': 'Childbirth / Obstetric Emergency',  'icon': Icons.child_care_rounded},
    {'label': 'Other Emergency',                   'icon': Icons.emergency_rounded},
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {

          Future<void> handleConfirm() async {
            if (selectedEmergencyType == null || isSubmitting) return;
            HapticFeedback.heavyImpact();
            setModalState(() => isSubmitting = true);

            // [FIX] Ensure the patient has a valid auth token before submitting.
            // On first launch or after a cold-start Render delay, the token may
            // not have been obtained by SessionService.syncPatientFromRegistration.
            // Re-authenticating here guarantees the request has a Bearer token.
            final authed = await SessionService.instance.ensurePatientAuthenticated();
            if (!authed) {
              if (ctx.mounted) {
                setModalState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'Could not authenticate. Please check your connection.',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
                      )),
                    ]),
                    backgroundColor: AppTheme.crimson,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
              return;
            }

            final loc = await _resolvePickupForRequest();

            final result = await RequestService.instance.submitRequest(
              emergencyTypeLabel: selectedEmergencyType!,
              latitude: loc.lat,
              longitude: loc.lng,
              address: loc.address,
            );

            if (!ctx.mounted) return;
            Navigator.pop(ctx);

            final snackColor = result.success ? AppTheme.success : AppTheme.crimson;
            final snackIcon  = result.success
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded;
            final snackText  = result.success
                ? 'Request submitted! Help is on the way.'
                : (result.errorMessage ?? 'Request failed. Please try again.');

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  Icon(snackIcon, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(snackText,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white))),
                ]),
                backgroundColor: snackColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }

          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  width: 44, height: 5,
                  decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF1A35), Color(0xFFC80014), Color(0xFF9B0015)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.40), blurRadius: 30, offset: const Offset(0, 12))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Request Ambulance',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('Select your emergency type',
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Container(width: 4, height: 16,
                        decoration: BoxDecoration(color: AppTheme.crimson, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Text('What is the emergency?',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700,
                            color: AppTheme.textDark, letterSpacing: 0.2)),
                  ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: emergencyTypes.length,
                    itemBuilder: (context, i) {
                      final type     = emergencyTypes[i];
                      final selected = selectedEmergencyType == type['label'];
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setModalState(() => selectedEmergencyType = type['label'] as String);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.crimson.withOpacity(0.05) : const Color(0xFFF8FAFB),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected ? AppTheme.crimson.withOpacity(0.5) : const Color(0xFFE8ECF0),
                              width: selected ? 1.5 : 1,
                            ),
                            boxShadow: selected
                                ? [BoxShadow(color: AppTheme.crimson.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 3))]
                                : [],
                          ),
                          child: Row(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: selected ? AppTheme.crimson.withOpacity(0.12) : Colors.white,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: selected ? AppTheme.crimson.withOpacity(0.3) : const Color(0xFFE8ECF0),
                                ),
                              ),
                              child: Icon(type['icon'] as IconData,
                                  color: selected ? AppTheme.crimson : AppTheme.textLight, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(type['label'] as String,
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      color: selected ? AppTheme.textDark : AppTheme.textMid)),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                key: ValueKey(selected),
                                color: selected ? AppTheme.crimson : const Color(0xFFCDD5E0),
                                size: 22,
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 44),
                  child: GestureDetector(
                    onTap: (selectedEmergencyType != null && !isSubmitting) ? handleConfirm : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: (selectedEmergencyType != null && !isSubmitting)
                            ? const LinearGradient(
                                colors: [Color(0xFFFF1A35), Color(0xFFD0021B), Color(0xFF9B0015)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              )
                            : null,
                        color: (selectedEmergencyType == null || isSubmitting)
                            ? const Color(0xFFF0F2F5)
                            : null,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: (selectedEmergencyType != null && !isSubmitting)
                            ? [BoxShadow(color: AppTheme.crimson.withOpacity(0.45), blurRadius: 28, offset: const Offset(0, 12))]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSubmitting)
                            const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          else
                            Icon(Icons.airport_shuttle_rounded,
                                color: selectedEmergencyType != null ? Colors.white : AppTheme.textLight,
                                size: 22),
                          const SizedBox(width: 10),
                          Text(
                            isSubmitting ? 'SUBMITTING...' : 'CONFIRM REQUEST',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w800,
                                color: (selectedEmergencyType != null && !isSubmitting)
                                    ? Colors.white
                                    : AppTheme.textLight,
                                letterSpacing: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ─────────────────────────────────────────────
//  HOME SCREEN
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _preparednessVisible = true;
  String? _userBarangay;
  AppStatsModel _stats = AppStatsModel.empty();

  @override
  void initState() {
    super.initState();
    _loadBarangay();
    _loadStats();
  }

  Future<void> _loadBarangay() async {
    final data = await RegistrationService.instance.loadRegistration();
    if (mounted && data != null && data.barangay.isNotEmpty) {
      setState(() => _userBarangay = data.barangay);
    }
  }

  Future<void> _loadStats() async {
    final stats = await RequestService.instance.getAppStats();
    if (mounted) setState(() => _stats = stats);
  }

  // [FIX] Navigate to the Services tab (index 1) via the MainShell
  void _goToServices() {
    // Navigate to Services tab by pushing the screen directly.
    // This works whether HomeScreen is inside MainShell or standalone.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServicesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _HeroSection(),
            if (_preparednessVisible)
              _EmergencyPreparednessBanner(
                barangay: _userBarangay,
                onDismiss: () => setState(() => _preparednessVisible = false),
              ),
            _QuickAccessSection(),
            _StatsBar(stats: _stats),
            // [FIX] Pass onViewAll so "View All" button switches to Services tab
            _ServicesSection(onViewAll: _goToServices),
            _HotlineSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  EMERGENCY PREPAREDNESS BANNER
// ═══════════════════════════════════════════════════════════

class _EmergencyPreparednessBanner extends StatefulWidget {
  final VoidCallback onDismiss;
  final String? barangay;

  const _EmergencyPreparednessBanner({
    required this.onDismiss,
    this.barangay,
  });

  @override
  State<_EmergencyPreparednessBanner> createState() =>
      _EmergencyPreparednessBannerState();
}

class _EmergencyPreparednessBannerState
    extends State<_EmergencyPreparednessBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  String get _barangayLabel =>
      (widget.barangay != null && widget.barangay!.isNotEmpty)
          ? widget.barangay!
          : 'your barangay';

  bool get _hasBarangay =>
      widget.barangay != null && widget.barangay!.isNotEmpty;

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareCommunitySheet(barangay: widget.barangay),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: AnimatedBuilder(
        animation: _shimmerCtrl,
        builder: (context, child) {
          final shimmerOffset = _shimmerCtrl.value;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B35).withOpacity(0.25 + shimmerOffset * 0.1),
                  const Color(0xFFFF8C00).withOpacity(0.18),
                  const Color(0xFFFF6B35).withOpacity(0.25 + shimmerOffset * 0.1),
                ],
                stops: [0.0, shimmerOffset, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8C00).withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(2),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20, top: -20,
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [const Color(0xFFFF8C00).withOpacity(0.18), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -10, bottom: -10,
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [const Color(0xFF00C9FF).withOpacity(0.12), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PulsingOrangeIcon(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF8C00).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFF8C00).withOpacity(0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_city_rounded, size: 10, color: Color(0xFFFF8C00)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _hasBarangay
                                            ? '📢  ${_barangayLabel.toUpperCase()}'
                                            : '⚠️  COMMUNITY NOTICE',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5, fontWeight: FontWeight.w800,
                                          color: const Color(0xFFFF8C00), letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Be Ready Before\nAn Emergency Strikes',
                                style: GoogleFonts.outfit(
                                  fontSize: 17, fontWeight: FontWeight.w900,
                                  color: Colors.white, height: 1.2, letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onDismiss();
                          },
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _hasBarangay
                          ? 'ResQmove is now available in $_barangayLabel. '
                            'Install the app in advance so you can call for an ambulance instantly — '
                            'share this with your neighbors and barangay officials.'
                          : 'ResQmove is now available in your barangay. Install the app in advance so you can call for an ambulance instantly when every second counts.',
                      style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.white70, height: 1.55),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: const [
                        _TipChip(icon: Icons.download_rounded,    label: 'Install now',       color: Color(0xFF00C9FF)),
                        _TipChip(icon: Icons.person_add_rounded,  label: 'Register profile',  color: Color(0xFF7CFC00)),
                        _TipChip(icon: Icons.share_rounded,       label: 'Share with others', color: Color(0xFFFF8C00)),
                        _TipChip(icon: Icons.location_on_rounded, label: 'Enable GPS',        color: Color(0xFFD4A5FF)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              _showShareSheet(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF8C00), Color(0xFFFF6B35)],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: const Color(0xFFFF8C00).withOpacity(0.40), blurRadius: 16, offset: const Offset(0, 6))],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.campaign_rounded, color: Colors.white, size: 17),
                                  const SizedBox(width: 7),
                                  Text('Spread the Word',
                                      style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _showPreparednessGuide(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.16)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 16),
                                const SizedBox(width: 6),
                                Text('Learn more',
                                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingOrangeIcon extends StatefulWidget {
  @override
  State<_PulsingOrangeIcon> createState() => _PulsingOrangeIconState();
}

class _PulsingOrangeIconState extends State<_PulsingOrangeIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFFF8C00).withOpacity(0.15 + _c.value * 0.10),
          border: Border.all(color: const Color(0xFFFF8C00).withOpacity(0.3 + _c.value * 0.2)),
          boxShadow: [BoxShadow(color: const Color(0xFFFF8C00).withOpacity(0.2 + _c.value * 0.15), blurRadius: 12 + _c.value * 8)],
        ),
        child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFFFF8C00), size: 26),
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _TipChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

void _showPreparednessGuide(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 14),
              width: 44, height: 5,
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF0F3460)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C00).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFF8C00).withOpacity(0.35)),
                  ),
                  child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFFFF8C00), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Emergency Preparedness', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text('How to use ResQmove before an emergency', style: GoogleFonts.outfit(fontSize: 11, color: Colors.white60)),
                ])),
              ]),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: const [
                  _GuideStep(number: '1', title: 'Install the App Now',
                    body: 'Download ResQmove and keep it on your home screen. During an emergency, you won\'t have time to search for an app.',
                    icon: Icons.download_rounded, color: Color(0xFF00C9FF)),
                  _GuideStep(number: '2', title: 'Register Your Profile',
                    body: 'Sign up with your basic details and home address. This speeds up dispatch — especially when GPS is slow or inaccurate.',
                    icon: Icons.person_add_rounded, color: Color(0xFF7CFC00)),
                  _GuideStep(number: '3', title: 'Enable Location Access',
                    body: 'Allow ResQmove to access your GPS. Your exact location is sent to the command center the moment you request help.',
                    icon: Icons.location_on_rounded, color: Color(0xFFD4A5FF)),
                  _GuideStep(number: '4', title: 'Save Emergency Contacts',
                    body: 'Add a secondary contact in your profile — a family member or neighbor who can be reached if you are unable to communicate.',
                    icon: Icons.contacts_rounded, color: Color(0xFFFF8C00)),
                  _GuideStep(number: '5', title: 'Share with Your Barangay',
                    body: 'Tell your neighbors, family, and barangay officials about ResQmove. The more residents who install it, the faster emergencies can be handled.',
                    icon: Icons.campaign_rounded, color: AppTheme.crimson),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GuideStep extends StatelessWidget {
  final String number, title, body;
  final IconData icon;
  final Color color;
  const _GuideStep({required this.number, required this.title, required this.body, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.25))),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
                  child: Center(child: Text(number, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textDark))),
              ]),
              const SizedBox(height: 7),
              Text(body, style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textMid, height: 1.5)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ShareCommunitySheet extends StatelessWidget {
  final String? barangay;
  const _ShareCommunitySheet({this.barangay});

  String get _barangayLabel =>
      (barangay != null && barangay!.isNotEmpty) ? barangay! : 'our barangay';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 40),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.only(top: 14), width: 44, height: 5,
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3))),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF8C00), Color(0xFFFF6B35)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: const Color(0xFFFF8C00).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.3))),
                child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Spread the Word', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Help $_barangayLabel stay prepared', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
              ])),
            ]),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Share this message with neighbors, family, and barangay officials:',
                style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMid, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 14),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFF7F9FC), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 28, height: 28, decoration: BoxDecoration(color: AppTheme.crimson, borderRadius: BorderRadius.circular(9)),
                      child: const Icon(Icons.add, color: Colors.white, size: 16)),
                  const SizedBox(width: 8),
                  Text('ResQmove', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                ]),
                const SizedBox(height: 10),
                Text(_preparednessShareBody(barangay), style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textMid, height: 1.55)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              _ShareChannelButton(
                icon: Icons.facebook_rounded, label: 'Share on Facebook', color: const Color(0xFF1877F2),
                onTap: () async {
                  final text = _preparednessShareBody(barangay);
                  Navigator.pop(context);
                  await Share.share(text, subject: 'ResQmove — $_barangayLabel');
                },
              ),
              const SizedBox(height: 10),
              _ShareChannelButton(
                icon: Icons.chat_bubble_rounded, label: 'Share via SMS / Viber', color: const Color(0xFF7360F2),
                onTap: () async {
                  final text = _preparednessShareBody(barangay);
                  Navigator.pop(context);
                  final uri = Uri(scheme: 'sms', queryParameters: {'body': text});
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.platformDefault);
                    } else {
                      await Share.share(text);
                    }
                  } catch (_) {
                    await Share.share(text);
                  }
                },
              ),
              const SizedBox(height: 10),
              _ShareChannelButton(
                icon: Icons.share_rounded, label: 'More sharing options', color: AppTheme.textMid,
                onTap: () async {
                  final text = _preparednessShareBody(barangay);
                  Navigator.pop(context);
                  await Share.share(text);
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ShareChannelButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function() onTap;
  const _ShareChannelButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        await onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color.withOpacity(0.6)),
        ]),
      ),
    );
  }
}

class _HomeDualActionButtons extends StatelessWidget {
  final VoidCallback onNonEmergency;
  final VoidCallback onEmergency;

  const _HomeDualActionButtons({required this.onNonEmergency, required this.onEmergency});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () { HapticFeedback.mediumImpact(); onNonEmergency(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(colors: [Color(0xFF00A86B), Color(0xFF00C851), Color(0xFF009952)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: AppTheme.success.withOpacity(0.42), blurRadius: 22, offset: const Offset(0, 8))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 22)),
                const SizedBox(width: 14),
                Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('NON-EMERGENCY', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.6)),
                  Text('Transport booking — pick date, time & locations',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.88), height: 1.25)),
                ])),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.85), size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () { HapticFeedback.heavyImpact(); onEmergency(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(colors: [Color(0xFFFF1A35), Color(0xFFD0021B), Color(0xFF9B0015)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.25))),
                  child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 22)),
                const SizedBox(width: 14),
                Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('EMERGENCY', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
                  Text('Immediate help — request ambulance now', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70, height: 1.25)),
                ])),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.85), size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Container(height: 540, decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFFFFF5F5), Color(0xFFFFFFFF), Color(0xFFECF3FF)], stops: [0.0, 0.5, 1.0]),
          )),
          Positioned(right: -60, top: -60, child: Container(width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppTheme.crimson.withOpacity(0.09), Colors.transparent], stops: const [0.3, 1.0])))),
          Positioned(left: -70, bottom: 30, child: Container(width: 240, height: 240,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppTheme.blue.withOpacity(0.08), Colors.transparent], stops: const [0.3, 1.0])))),
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Positioned(right: 30, top: 120, child: _CrossIcon(size: 32, color: AppTheme.crimson.withOpacity(0.09))),
          Positioned(left: 26, top: 230, child: _CrossIcon(size: 20, color: AppTheme.blue.withOpacity(0.10))),
          Positioned(right: 90, bottom: 90, child: _CrossIcon(size: 16, color: AppTheme.crimson.withOpacity(0.07))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        _LogoBadge(),
                        const SizedBox(width: 11),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('ResQmove', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textDark, letterSpacing: 0.3)),
                          Text('Emergency Services', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.textLight, letterSpacing: 0.5)),
                        ]),
                      ]),
                      _OnlineBadge(),
                    ],
                  ),
                  const SizedBox(height: 42),
                  _HeroHeadline(),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 28, height: 2.5, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppTheme.crimson]), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppTheme.border),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)]),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.crimson),
                          const SizedBox(width: 6),
                          Text('Cebu City, PH', style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMid, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 28, height: 2.5, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.blue, Colors.transparent]), borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _HomeDualActionButtons(
                    onNonEmergency: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NonEmergencyBookingScreen())),
                    onEmergency: () => _showRequestAmbulanceModal(context),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverLoginScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppTheme.blue.withOpacity(0.25)),
                        boxShadow: [BoxShadow(color: AppTheme.blue.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 5)), BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 30, height: 30, decoration: BoxDecoration(color: AppTheme.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.local_shipping_rounded, size: 16, color: AppTheme.blue)),
                        const SizedBox(width: 11),
                        Text('Are you a driver? Sign in here', style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.blue, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppTheme.blue),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF1A35), Color(0xFFD0021B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 7)), BoxShadow(color: AppTheme.crimson.withOpacity(0.15), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 26),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.success.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: AppTheme.success.withOpacity(0.12), blurRadius: 12)],
      ),
      child: Row(children: [
        _PulsingDot(color: AppTheme.success),
        const SizedBox(width: 8),
        Text('Online', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.success)),
      ]),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: widget.color, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color.withOpacity(0.3 + _ctrl.value * 0.35), blurRadius: 4 + _ctrl.value * 5, spreadRadius: _ctrl.value * 2)],
        ),
      ),
    );
  }
}

class _HeroHeadline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Emergency', textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 50, fontWeight: FontWeight.w900, color: AppTheme.textDark, height: 1.0, letterSpacing: -2.5)),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFFFF1A35), Color(0xFFD0021B)], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(bounds),
          child: Text('Ambulance', textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 50, fontWeight: FontWeight.w900, color: Colors.white, height: 1.05, letterSpacing: -2.5)),
        ),
        Text('Service', textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 50, fontWeight: FontWeight.w900, color: AppTheme.textDark, height: 1.0, letterSpacing: -2.5)),
      ],
    );
  }
}

class _CrossIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _CrossIcon({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _CrossPainter(color: color)));
}

class _CrossPainter extends CustomPainter {
  final Color color;
  _CrossPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = size.width * 0.22..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
  }
  @override bool shouldRepaint(_CrossPainter old) => false;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF0D1B2A).withOpacity(0.025)..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }
  @override bool shouldRepaint(_DotGridPainter old) => false;
}

class _QuickAccessSection extends StatelessWidget {
  Future<void> _call911() async {
    final uri = Uri(scheme: 'tel', path: '911');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _shareLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      await Share.share('My location: Cebu City, PH\nPlease call emergency services immediately.');
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      final mapsUrl = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
      await Share.share(
        'I need help! My location:\n$mapsUrl\n(${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})',
        subject: 'Emergency Location',
      );
    } catch (_) {
      await Share.share('My location: Cebu City, PH\nPlease call emergency services immediately.');
    }
  }

  void _showRequestHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'QUICK ACCESS'),
          const SizedBox(height: 16),
          Row(children: [
            _QuickCard(
              icon: Icons.phone_rounded,
              label: 'Call 911',
              subtitle: 'Emergency',
              color: AppTheme.crimson,
              bg: const Color(0xFFFFF0F0),
              onTap: () { HapticFeedback.heavyImpact(); _call911(); },
            ),
            const SizedBox(width: 11),
            _QuickCard(
              icon: Icons.location_on_rounded,
              label: 'Share Location',
              subtitle: 'GPS',
              color: AppTheme.blue,
              bg: const Color(0xFFEFF4FF),
              onTap: () { HapticFeedback.mediumImpact(); _shareLocation(); },
            ),
            const SizedBox(width: 11),
            _QuickCard(
              icon: Icons.history_rounded,
              label: 'Past Requests',
              subtitle: 'History',
              color: const Color(0xFF6B48FF),
              bg: const Color(0xFFF3F0FF),
              onTap: () { HapticFeedback.selectionClick(); _showRequestHistory(context); },
            ),
          ]),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 4, height: 16, decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.crimson, AppTheme.crimsonDark], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(2),
      )),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textLight, letterSpacing: 1.4)),
    ]);
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon; final String label, subtitle; final Color color, bg;
  final VoidCallback? onTap;
  const _QuickCard({required this.icon, required this.label, required this.subtitle, required this.color, required this.bg, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(0.12)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 6)), BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
          ),
          child: Column(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.16))),
                child: Icon(icon, color: color, size: 23)),
            const SizedBox(height: 11),
            Text(label, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textDark, height: 1.2)),
            const SizedBox(height: 3),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w500, color: color.withOpacity(0.75))),
          ]),
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final AppStatsModel stats;
  const _StatsBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 26, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10)), BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(value: stats.avgResponseTime, label: 'Avg. Response', icon: Icons.timer_outlined,         color: AppTheme.warning),
          _StatDivider(),
          _StatItem(value: stats.availableUnits.toString(),  label: 'Availability',  icon: Icons.airport_shuttle_rounded, color: AppTheme.crimson),
          _StatDivider(),
          _StatItem(value: stats.livesSaved.toString(),  label: 'Lives Saved',   icon: Icons.favorite_rounded,         color: AppTheme.success),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label; final IconData icon; final Color color;
  const _StatItem({required this.value, required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.18))),
          child: Icon(icon, color: color, size: 20)),
      const SizedBox(height: 10),
      Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 56,
    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppTheme.border, Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
  );
}

class _ServicesSection extends StatelessWidget {
  // [FIX] Accept a callback so tapping "View All" switches to the Services tab
  final VoidCallback? onViewAll;
  const _ServicesSection({this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(width: 4, height: 22, decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.crimson, AppTheme.crimsonDark], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(2),
                )),
                const SizedBox(width: 12),
                Text('Our Services', style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              ]),
              // [FIX] "View All" is now a tappable GestureDetector
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (onViewAll != null) {
                    onViewAll!();
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesScreen()));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.blue.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.blue.withOpacity(0.18))),
                  child: Row(children: [
                    Text('View all', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.blue)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.blue),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 13, mainAxisSpacing: 13, childAspectRatio: 1.15,
            children: [
              // [FIX] Each card now navigates to its service screen
              _ServiceCard(
                icon: Icons.emergency_rounded, label: 'Emergency\nResponse',
                color: AppTheme.crimson, bg: const Color(0xFFFFF0F0), tag: 'Priority',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyDetailScreen())),
              ),
              _ServiceCard(
                icon: Icons.airport_shuttle_rounded, label: 'Patient\nTransport',
                color: AppTheme.blue, bg: const Color(0xFFEFF4FF), tag: 'Non-Emergency',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NonEmergencyBookingScreen())),
              ),
              _ServiceCard(
                icon: Icons.medical_services_rounded, label: 'Event Medical\nStandby',
                color: AppTheme.blue, bg: const Color(0xFFEFF4FF), tag: 'Planned',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventStandbyBookingScreen())),
              ),
              _ServiceCard(
                icon: Icons.favorite_rounded, label: 'Basic Life\nSupport',
                color: AppTheme.crimson, bg: const Color(0xFFFFF0F0), tag: 'Critical',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BLSDetailScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon; final String label, tag; final Color color, bg;
  final VoidCallback? onTap; // [FIX] make cards tappable
  const _ServiceCard({required this.icon, required this.label, required this.color, required this.bg, required this.tag, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap?.call(); },
      child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: color.withOpacity(0.12)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 22, offset: const Offset(0, 8)), BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.18))),
                child: Icon(icon, color: color, size: 23)),
            Flexible(child: Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.18))),
              child: Text(tag, overflow: TextOverflow.ellipsis, maxLines: 1, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
            )),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textDark, height: 1.3)),
            const SizedBox(height: 6),
            Row(children: [
              Text('Tap to proceed', style: GoogleFonts.outfit(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
              const SizedBox(width: 3),
              Icon(Icons.arrow_forward_rounded, size: 11, color: color),
            ]),
          ]),
        ],
      ),
    ), // Container
    ); // GestureDetector
  }
}

// ─────────────────────────────────────────────
//  REQUEST HISTORY SHEET
// ─────────────────────────────────────────────

class _RequestHistorySheet extends StatefulWidget {
  @override
  State<_RequestHistorySheet> createState() => _RequestHistorySheetState();
}

class _RequestHistorySheetState extends State<_RequestHistorySheet> {
  bool _loading = true;
  List<AmbulanceRequestModel> _requests = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await RequestService.instance.getRequestHistory();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _requests = result.requests;
      _error = result.success ? null : result.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 14),
              width: 44, height: 5,
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B48FF), Color(0xFF4A2FBF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: const Color(0xFF6B48FF).withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Request History', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text('Your past ambulance requests', style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70)),
                ]),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(_error!, textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid)),
                        ))
                      : _requests.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.inbox_rounded, size: 56, color: AppTheme.textLight.withOpacity(0.4)),
                                  const SizedBox(height: 14),
                                  Text('No requests yet', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                                  const SizedBox(height: 8),
                                  Text('Your ambulance request history will appear here.', textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMid, height: 1.5)),
                                ]),
                              ),
                            )
                          : ListView.separated(
                              controller: ctrl,
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                              itemCount: _requests.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _HistoryItem(request: _requests[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final AmbulanceRequestModel request;
  const _HistoryItem({required this.request});

  Color get _statusColor {
    switch (request.status) {
      case RequestStatus.completed:  return AppTheme.success;
      case RequestStatus.cancelled:  return AppTheme.textLight;
      case RequestStatus.declined:   return AppTheme.textLight;
      case RequestStatus.inProgress: return AppTheme.success;
      case RequestStatus.accepted:   return AppTheme.blue;
      case RequestStatus.pending:    return AppTheme.warning;
    }
  }

  String get _statusLabel {
    switch (request.status) {
      case RequestStatus.completed:  return 'Completed';
      case RequestStatus.cancelled:  return 'Cancelled';
      case RequestStatus.declined:   return 'Declined';
      case RequestStatus.inProgress: return 'In Progress';
      case RequestStatus.accepted:   return 'Accepted';
      case RequestStatus.pending:    return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = request.requestedAt;
    final dateStr = date != null
        ? '${date.day}/${date.month}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : 'Unknown date';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _statusColor.withOpacity(0.22)),
          ),
          child: Icon(Icons.airport_shuttle_rounded, color: _statusColor, size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(request.emergencyType.label,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          const SizedBox(height: 3),
          Text(request.pickupLocation.address ?? dateStr,
              style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textLight), overflow: TextOverflow.ellipsis),
          if (request.pickupLocation.address != null) ...[
            const SizedBox(height: 1),
            Text(dateStr, style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textLight.withOpacity(0.7))),
          ],
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _statusColor.withOpacity(0.22)),
          ),
          child: Text(_statusLabel, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  HOTLINE SECTION — wired to dial the number
// ─────────────────────────────────────────────

class _HotlineSection extends StatelessWidget {
  Future<void> _callHotline() async {
    final uri = Uri(scheme: 'tel', path: AppConfig.hotlineNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.blue.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(color: AppTheme.blue.withOpacity(0.08), blurRadius: 22, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              width: 62, height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.blue.withOpacity(0.12), AppTheme.blue.withOpacity(0.06)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.blue.withOpacity(0.22)),
              ),
              child: const Icon(Icons.phone_rounded, color: AppTheme.blue, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Emergency Hotline',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textLight, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              Text(AppConfig.hotlineDisplay,
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textDark, letterSpacing: 0.3)),
              Row(children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Available 24/7', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w600)),
              ]),
            ])),
            GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact();
                _callHotline();
              },
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF1A35), Color(0xFFB71C1C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 7))],
                ),
                child: const Icon(Icons.call_rounded, color: Colors.white, size: 24),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
