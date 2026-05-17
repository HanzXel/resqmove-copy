import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'driver_shell.dart';
import 'driver_register_screen.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _selectedUnit;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Unit list (will come from database in future) ──────────────────────────
  // TODO (DB): Replace with a call to GET /units to load this dynamically.
  static const List<String> _units = [
    'RESQ-101 · Chong Hua Hospital',
    'RESQ-102 · Cebu Doctors\' University Hospital',
    'RESQ-103 · Vicente Sotto Memorial Medical Center',
    'RESQ-104 · Perpetual Succour Hospital',
    'RESQ-105 · Cebu Velez General Hospital',
    'RESQ-106 · UC Med',
    'RESQ-107 · Cebu City Medical Center',
  ];

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Basic validation
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your username and password.');
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Extract unit ID from selected dropdown value (e.g. "RESQ-101 · Chong Hua")
    final unitId = _selectedUnit?.split(' · ').first;

    final result = await AuthService.instance.loginAsDriver(
      username: username,
      password: password,
      unitId: unitId,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DriverShell()),
      );
    } else {
      setState(() => _errorMessage = result.errorMessage ?? 'Login failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _LoginHeroHeader(onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title block
                  Text('Welcome back',
                      style: GoogleFonts.outfit(
                          fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textDark, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: AppTheme.crimson, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 9),
                      Text('Authorized ambulance staff only',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.crimson.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.crimson.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: GoogleFonts.outfit(
                                    fontSize: 13, color: AppTheme.crimson, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Credential fields
                  _SectionLabel(icon: Icons.person_outline_rounded, label: 'Credentials'),
                  const SizedBox(height: 14),
                  Column(
                    children: [
                      _LoginFieldRow(
                        label: 'Username / Driver ID',
                        hint: 'Username or Driver ID',
                        icon: Icons.badge_outlined,
                        controller: _usernameCtrl,
                      ),
                      const SizedBox(height: 10),
                      _LoginFieldRow(
                        label: 'Password',
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        controller: _passwordCtrl,
                        obscure: _obscurePassword,
                        suffix: GestureDetector(
                          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          child: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppTheme.textLight,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  // Unit selector
                  _SectionLabel(icon: Icons.local_shipping_rounded, label: 'Assigned Unit (Optional)'),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedUnit != null ? AppTheme.blue.withOpacity(0.4) : AppTheme.border,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedUnit,
                        isExpanded: true,
                        hint: Text('Select ambulance unit',
                            style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textLight)),
                        icon: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.expand_more_rounded, color: AppTheme.textLight, size: 18),
                        ),
                        style: GoogleFonts.outfit(fontSize: 13.5, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                        items: _units.map((u) =>
                            DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _selectedUnit = v),
                      ),
                    ),
                  ),

                  const SizedBox(height: 38),

                  // Sign in button
                  GestureDetector(
                    onTap: _isLoading ? null : _login,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 21),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF1A35), Color(0xFFD0021B), Color(0xFF9B0015)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: AppTheme.crimson.withOpacity(0.50), blurRadius: 32, offset: const Offset(0, 14)),
                          BoxShadow(color: AppTheme.crimson.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_isLoading)
                            const Icon(Icons.login_rounded, color: Colors.white, size: 22)
                          else
                            const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            ),
                          const SizedBox(width: 12),
                          Text(
                            _isLoading ? 'SIGNING IN...' : 'SIGN IN',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── NEW: Register link ────────────────────────────────────
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DriverRegisterScreen()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.success.withOpacity(0.35)),
                        boxShadow: [
                          BoxShadow(color: AppTheme.success.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 6)),
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_add_rounded, color: AppTheme.success, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'New driver? Register here',
                            style: GoogleFonts.outfit(
                                fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.success),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.success),
                        ],
                      ),
                    ),
                  ),
                  // ── END: Register link ────────────────────────────────────

                  const SizedBox(height: 18),

                  // Security notice
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.blue.withOpacity(0.06), AppTheme.blue.withOpacity(0.02)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.blue.withOpacity(0.14)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(Icons.security_rounded, color: AppTheme.blue, size: 19),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Access restricted to registered ResQmove ambulance staff only.',
                            style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textMid, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 52),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HERO HEADER
// ─────────────────────────────────────────────
class _LoginHeroHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _LoginHeroHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: AppTheme.textDark),
      child: Stack(
        children: [
          Positioned(
            right: -50, top: -50,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.crimson.withOpacity(0.28), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            left: -30, bottom: -30,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.blue.withOpacity(0.22), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _DarkDotGridPainter())),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
                    ),
                  ),
                  const SizedBox(height: 34),
                  Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF1A35), Color(0xFFD0021B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 5))],
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 23),
                      ),
                      const SizedBox(width: 11),
                      Text('ResQmove',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                      const SizedBox(width: 11),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.blue.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: AppTheme.blue.withOpacity(0.35)),
                        ),
                        child: Text('Driver Portal',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white.withOpacity(0.14), Colors.white.withOpacity(0.06)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Driver Portal',
                                style: GoogleFonts.outfit(
                                    fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.0)),
                            Text('ResQmove Ambulance Staff',
                                style: GoogleFonts.outfit(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
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

class _DarkDotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..style = PaintingStyle.fill;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DarkDotGridPainter old) => false;
}

// ─────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.blue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.blue.withOpacity(0.16)),
          ),
          child: Icon(icon, color: AppTheme.blue, size: 14),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMid)),
      ],
    );
  }
}

class _LoginFieldRow extends StatelessWidget {
  final String label, hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscure;
  final Widget? suffix;

  const _LoginFieldRow({
    required this.label, required this.hint, required this.icon,
    required this.controller, this.obscure = false, this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: AppTheme.textDark,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              fontSize: 15,
              color: const Color(0xFFADB5BD),
              fontWeight: FontWeight.w400,
            ),
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: suffix,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 18,
            ),
          ),
        ),
      ),
    );
  }
}
