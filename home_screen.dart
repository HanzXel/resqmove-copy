import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/pulse_button.dart';
import '../services/request_service.dart';
import '../services/location_service.dart';    // ← NEW
import 'driver/driver_login_screen.dart';

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

            // ── REAL GPS ──────────────────────────────────────────────────────
            // Gets actual device coordinates. Falls back to Cebu City center
            // if GPS is unavailable (permissions denied, GPS off, etc.)
            final location = await LocationService.instance.getCurrentLocation();

            final double lat     = location.latitude;
            final double lng     = location.longitude;
            final String address = location.address ?? 'Cebu City, PH';
            // ─────────────────────────────────────────────────────────────────

            final result = await RequestService.instance.submitRequest(
              emergencyTypeLabel: selectedEmergencyType!,
              latitude: lat,
              longitude: lng,
              address: address,
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
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  width: 44, height: 5,
                  decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
                ),
                // Header banner
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
                // Emergency type list
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
                // Confirm button
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
  String _locationLabel = 'Getting location...';

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final result = await LocationService.instance.getCurrentLocation();
    if (mounted) {
      setState(() {
        _locationLabel = result.address ?? 'Cebu City, PH';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _HeroSection(locationLabel: _locationLabel),
            _QuickAccessSection(),
            _StatsBar(),
            _ServicesSection(),
            _HotlineSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HERO SECTION
// ─────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final String locationLabel;
  const _HeroSection({required this.locationLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Container(
            height: 540,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFFFF5F5), Color(0xFFFFFFFF), Color(0xFFECF3FF)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(right: -60, top: -60,
            child: Container(width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.crimson.withOpacity(0.09), Colors.transparent],
                  stops: const [0.3, 1.0],
                )),
            ),
          ),
          Positioned(left: -70, bottom: 30,
            child: Container(width: 240, height: 240,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.blue.withOpacity(0.08), Colors.transparent],
                  stops: const [0.3, 1.0],
                )),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Positioned(right: 30, top: 120,
              child: _CrossIcon(size: 32, color: AppTheme.crimson.withOpacity(0.09))),
          Positioned(left: 26, top: 230,
              child: _CrossIcon(size: 20, color: AppTheme.blue.withOpacity(0.10))),
          Positioned(right: 90, bottom: 90,
              child: _CrossIcon(size: 16, color: AppTheme.crimson.withOpacity(0.07))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 18),
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        _LogoBadge(),
                        const SizedBox(width: 11),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('ResQmove',
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800,
                                  color: AppTheme.textDark, letterSpacing: 0.3)),
                          Text('Emergency Services',
                              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w500,
                                  color: AppTheme.textLight, letterSpacing: 0.5)),
                        ]),
                      ]),
                      _OnlineBadge(),
                    ],
                  ),
                  const SizedBox(height: 42),
                  _HeroHeadline(),
                  const SizedBox(height: 18),
                  // Location pill — NOW SHOWS REAL GPS LOCATION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 28, height: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.transparent, AppTheme.crimson]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.crimson),
                          const SizedBox(width: 6),
                          Text(
                            locationLabel,   // ← REAL location now
                            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMid, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 28, height: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppTheme.blue, Colors.transparent]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 38),
                  // Main CTA
                  PulseButton(
                    label: 'REQUEST AMBULANCE',
                    icon: Icons.airport_shuttle_rounded,
                    onTap: () => _showRequestAmbulanceModal(context),
                  ),
                  const SizedBox(height: 20),
                  // Driver link
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const DriverLoginScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppTheme.blue.withOpacity(0.25)),
                        boxShadow: [
                          BoxShadow(color: AppTheme.blue.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 5)),
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: AppTheme.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_shipping_rounded, size: 16, color: AppTheme.blue),
                        ),
                        const SizedBox(width: 11),
                        Text('Are you a driver? Sign in here',
                            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.blue, fontWeight: FontWeight.w700)),
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

// ─────────────────────────────────────────────
//  LOGO & ONLINE BADGE
// ─────────────────────────────────────────────

class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF1A35), Color(0xFFD0021B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: AppTheme.crimson.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 7)),
          BoxShadow(color: AppTheme.crimson.withOpacity(0.15), blurRadius: 5, offset: const Offset(0, 2)),
        ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
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
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
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
          boxShadow: [BoxShadow(
            color: widget.color.withOpacity(0.3 + _ctrl.value * 0.35),
            blurRadius: 4 + _ctrl.value * 5,
            spreadRadius: _ctrl.value * 2,
          )],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HERO HEADLINE
// ─────────────────────────────────────────────

class _HeroHeadline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Emergency', textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 50, fontWeight: FontWeight.w900,
                color: AppTheme.textDark, height: 1.0, letterSpacing: -2.5)),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF1A35), Color(0xFFD0021B)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text('Ambulance', textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 50, fontWeight: FontWeight.w900,
                  color: Colors.white, height: 1.05, letterSpacing: -2.5)),
        ),
        Text('Service', textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 50, fontWeight: FontWeight.w900,
                color: AppTheme.textDark, height: 1.0, letterSpacing: -2.5)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  CROSS & DOT GRID PAINTERS
// ─────────────────────────────────────────────

class _CrossIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _CrossIcon({required this.size, required this.color});
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _CrossPainter(color: color)));
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

// ─────────────────────────────────────────────
//  QUICK ACCESS SECTION
// ─────────────────────────────────────────────

class _QuickAccessSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'QUICK ACCESS'),
          const SizedBox(height: 16),
          Row(children: [
            _QuickCard(icon: Icons.phone_rounded,    label: 'Call 911',       subtitle: 'Emergency', color: AppTheme.crimson,         bg: const Color(0xFFFFF0F0)),
            const SizedBox(width: 11),
            _QuickCard(icon: Icons.location_on_rounded, label: 'Share Location', subtitle: 'GPS',    color: AppTheme.blue,            bg: const Color(0xFFEFF4FF)),
            const SizedBox(width: 11),
            _QuickCard(icon: Icons.history_rounded,  label: 'Past Requests',  subtitle: 'History',   color: const Color(0xFF6B48FF),  bg: const Color(0xFFF3F0FF)),
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
      Container(width: 4, height: 16,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppTheme.crimson, AppTheme.crimsonDark],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppTheme.textLight, letterSpacing: 1.4)),
    ]);
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon; final String label, subtitle; final Color color, bg;
  const _QuickCard({required this.icon, required this.label, required this.subtitle, required this.color, required this.bg});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6),
          ],
        ),
        child: Column(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.16))),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 11),
          Text(label, textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textDark, height: 1.2)),
          const SizedBox(height: 3),
          Text(subtitle, textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w500, color: color.withOpacity(0.75))),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STATS BAR
// ─────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 26, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(value: '--',  label: 'Avg. Response', icon: Icons.timer_outlined,          color: AppTheme.warning),
          _StatDivider(),
          _StatItem(value: '0',   label: 'Availability',  icon: Icons.airport_shuttle_rounded,  color: AppTheme.crimson),
          _StatDivider(),
          _StatItem(value: '0',   label: 'Lives Saved',   icon: Icons.favorite_rounded,          color: AppTheme.success),
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
      Container(width: 44, height: 44,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.18))),
        child: Icon(icon, color: color, size: 20),
      ),
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
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.transparent, AppTheme.border, Colors.transparent],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  SERVICES SECTION
// ─────────────────────────────────────────────

class _ServicesSection extends StatelessWidget {
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
                Container(width: 4, height: 22,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.crimson, AppTheme.crimsonDark],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Our Services',
                    style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.blue.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.blue.withOpacity(0.18)),
                ),
                child: Row(children: [
                  Text('View all', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.blue)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.blue),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 13, mainAxisSpacing: 13, childAspectRatio: 1.15,
            children: const [
              _ServiceCard(icon: Icons.emergency_rounded,       label: 'Emergency\nResponse',  color: AppTheme.crimson, bg: Color(0xFFFFF0F0), tag: 'Priority'),
              _ServiceCard(icon: Icons.airport_shuttle_rounded, label: 'Patient\nTransport',   color: AppTheme.blue,   bg: Color(0xFFEFF4FF), tag: 'Non-Emergency'),
              _ServiceCard(icon: Icons.medical_services_rounded,label: 'Event Medical\nStandby',color: AppTheme.blue,  bg: Color(0xFFEFF4FF), tag: 'Planned'),
              _ServiceCard(icon: Icons.favorite_rounded,        label: 'Basic Life\nSupport',  color: AppTheme.crimson, bg: Color(0xFFFFF0F0), tag: 'Critical'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon; final String label, tag; final Color color, bg;
  const _ServiceCard({required this.icon, required this.label, required this.color, required this.bg, required this.tag});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.10), blurRadius: 22, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 46, height: 46,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: color.withOpacity(0.18))),
              child: Icon(icon, color: color, size: 23),
            ),
            Flexible(child: Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.18))),
              child: Text(tag, overflow: TextOverflow.ellipsis, maxLines: 1,
                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
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
    );
  }
}

// ─────────────────────────────────────────────
//  HOTLINE SECTION
// ─────────────────────────────────────────────

class _HotlineSection extends StatelessWidget {
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
              Text('Hotline not set',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textDark, letterSpacing: 0.3)),
              Row(children: [
                Container(width: 7, height: 7,
                    decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Available 24/7',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w600)),
              ]),
            ])),
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF1A35), Color(0xFFB71C1C)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 7))],
              ),
              child: const Icon(Icons.call_rounded, color: Colors.white, size: 24),
            ),
          ]),
        ),
      ),
    );
  }
}
