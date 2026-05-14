import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class PulseButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const PulseButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _ringAnim1;
  late Animation<double> _ringAnim2;
  late Animation<double> _opacityAnim1;
  late Animation<double> _opacityAnim2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _ringAnim1 = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    _ringAnim2 = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _opacityAnim1 = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    _opacityAnim2 = Tween<double>(begin: 0.25, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SizedBox(
            width: double.infinity,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse ring 2 (outer)
                Opacity(
                  opacity: _opacityAnim2.value,
                  child: Transform.scale(
                    scale: _ringAnim2.value,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        color: AppTheme.crimson,
                      ),
                    ),
                  ),
                ),
                // Pulse ring 1 (inner)
                Opacity(
                  opacity: _opacityAnim1.value,
                  child: Transform.scale(
                    scale: _ringAnim1.value,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        color: AppTheme.crimson,
                      ),
                    ),
                  ),
                ),
                // Main button
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(
                      colors: [AppTheme.crimsonLight, AppTheme.crimson],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.crimson.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.label,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
