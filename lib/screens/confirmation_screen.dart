import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  late final Animation<double> _scaleAnim = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
  );
  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
  );
  late final Animation<double> _slideAnim = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Stack(
        children: [
          // Background decorative blobs
          Positioned(
            right: -80, top: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.success.withOpacity(0.10), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            left: -60, bottom: 100,
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.blue.withOpacity(0.08), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                children: [
                  // ── Success Animation ──
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 160, height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.success.withOpacity(0.08),
                                AppTheme.success.withOpacity(0.02),
                              ],
                            ),
                            border: Border.all(color: AppTheme.success.withOpacity(0.15), width: 2),
                          ),
                        ),
                        Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.success.withOpacity(0.16),
                                AppTheme.success.withOpacity(0.06),
                              ],
                            ),
                            border: Border.all(color: AppTheme.success.withOpacity(0.25), width: 1.5),
                          ),
                        ),
                        Container(
                          width: 84, height: 84,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppTheme.success.withOpacity(0.50), blurRadius: 32, offset: const Offset(0, 12)),
                              BoxShadow(color: AppTheme.success.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Title ──
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        Text(
                          'Booking Confirmed!',
                          style: GoogleFonts.outfit(
                            fontSize: 32, fontWeight: FontWeight.w900,
                            color: AppTheme.textDark, letterSpacing: -1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'An ambulance has been dispatched to\nyour location. Stay calm and safe.',
                          style: GoogleFonts.outfit(
                            fontSize: 15, color: AppTheme.textMid, height: 1.55,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Info Card ──
                  AnimatedBuilder(
                    animation: _slideAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, 30 * (1 - _slideAnim.value)),
                      child: Opacity(opacity: _slideAnim.value.clamp(0.0, 1.0), child: child),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 32, offset: const Offset(0, 12)),
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ETA highlight
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF8E1), Color(0xFFFFFDF5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 56, height: 56,
                                  decoration: BoxDecoration(
                                    color: AppTheme.warning.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                                  ),
                                  child: const Icon(Icons.timer_rounded, color: AppTheme.warning, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Estimated Arrival',
                                        style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
                                    Text('~6 minutes',
                                        style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900,
                                            color: AppTheme.warning, letterSpacing: -0.5)),
                                  ],
                                ),
                                const Spacer(),
                                _PulsingDot(color: AppTheme.warning),
                              ],
                            ),
                          ),
                          Container(height: 1, color: AppTheme.border),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _InfoRow(
                                  icon: Icons.airport_shuttle_rounded,
                                  iconColor: AppTheme.crimson,
                                  label: 'Ambulance Unit',
                                  value: 'RESQ-145',
                                ),
                                const SizedBox(height: 16),
                                _InfoRow(
                                  icon: Icons.badge_outlined,
                                  iconColor: AppTheme.blue,
                                  label: 'Reference Number',
                                  value: '#RQ-20240789',
                                ),
                                const SizedBox(height: 16),
                                _InfoRow(
                                  icon: Icons.radio_button_checked_rounded,
                                  iconColor: AppTheme.success,
                                  label: 'Status',
                                  value: 'En Route',
                                  valueColor: AppTheme.success,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Action Buttons ──
                  AnimatedBuilder(
                    animation: _slideAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, 40 * (1 - _slideAnim.value)),
                      child: Opacity(opacity: _slideAnim.value.clamp(0.0, 1.0), child: child),
                    ),
                    child: Column(
                      children: [
                        // Track button
                        GestureDetector(
                          onTap: () => HapticFeedback.mediumImpact(),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 19),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF1A35), Color(0xFFD0021B), Color(0xFF9B0015)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(color: AppTheme.crimson.withOpacity(0.48), blurRadius: 28, offset: const Offset(0, 12)),
                                BoxShadow(color: AppTheme.crimson.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Text('TRACK AMBULANCE',
                                    style: GoogleFonts.outfit(
                                        fontSize: 16, fontWeight: FontWeight.w800,
                                        color: Colors.white, letterSpacing: 1.2)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Call & Home Row
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => HapticFeedback.selectionClick(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppTheme.border),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.phone_rounded, color: AppTheme.success, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Call',
                                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppTheme.border),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.home_rounded, color: AppTheme.blue, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Home',
                                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: iconColor.withOpacity(0.2)),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Text(label, style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 15, fontWeight: FontWeight.w800,
            color: valueColor ?? AppTheme.textDark,
          ),
        ),
      ],
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
    vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color: widget.color.withOpacity(0.3 + _ctrl.value * 0.4),
            blurRadius: 4 + _ctrl.value * 8,
            spreadRadius: _ctrl.value * 3,
          )],
        ),
      ),
    );
  }
}
