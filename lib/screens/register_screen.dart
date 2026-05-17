// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Register Screen
//  lib/screens/register_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config/app_config.dart';
import '../services/registration_service.dart';
import '../services/session_service.dart';
import 'driver/driver_login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegistered;
  final VoidCallback? onRequestSignIn;

  const RegisterScreen({
    super.key,
    required this.onRegistered,
    this.onRequestSignIn,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────
  final _fullNameCtrl = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _mobile1Ctrl  = TextEditingController();
  final _mobile2Ctrl  = TextEditingController();
  final _ecNameCtrl   = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _agreed   = false;
  String? _selectedBarangay;

  // ── Cebu Barangays ────────────────────────────────────────────────────────
  static const List<String> _cebuBarangays = [
    'Adlaon', 'Agsungot', 'Apas', 'Bacayan', 'Banilad', 'Basak Pardo',
    'Basak San Nicolas', 'Binaliw', 'Bonbon', 'Budlaan', 'Bulacao',
    'Buot-Matnog', 'Busay', 'Calamba', 'Cambinocot', 'Capitol Site',
    'Carreta', 'Central', 'Cogon Pardo', 'Cogon Ramos', 'Day-as',
    'Duljo', 'Ermita', 'Guadalupe', 'Guba', 'Hippodromo', 'Inayawan',
    'Kalubihan', 'Kalunasan', 'Kamagayan', 'Kasambagan', 'Kinasang-an',
    'Labangon', 'Lahug', 'Lorega', 'Lusaran', 'Luz', 'Mabini',
    'Mabolo', 'Malubog', 'Mambaling', 'Mines', 'Mohon', 'Moncada',
    'Montalban', 'Nasipit', 'Nga-an', 'Pamutan', 'Pari-an', 'Paril',
    'Pasil', 'Pit-os', 'Poblacion Pardo', 'Pulangbato', 'Pung-ol-Sibugay',
    'Punta Princesa', 'Quiot Pardo', 'Sambag I', 'Sambag II', 'San Antonio',
    'San Jose', 'San Nicolas Proper', 'San Roque', 'Santa Cruz', 'Santo Niño',
    'Sapangdaku', 'Sawang Calero', 'Sinsin', 'Sirao', 'Suba', 'Sudlon I',
    'Sudlon II', 'T. Padilla', 'Talamban', 'Taptap', 'Tejero', 'Tinago',
    'Tisa', 'To-ong Pardo', 'Tuburan', 'Tugbongan',
    // Mandaue barangays
    'Alang-alang', 'Bakilid', 'Bankal', 'Baring', 'Basak', 'Cambaro',
    'Canduman', 'Casili', 'Casuntingan', 'Centro (Mandaue)', 'Cubacub',
    'Guizo', 'Ibabao-Estancia', 'Jagobiao', 'Labogon', 'Looc', 'Maguikay',
    'Mantuyong', 'Opao', 'Pakna-an', 'Pagsabungan', 'Paknaan', 'Subangdaku',
    'Tabok', 'Tawason', 'Tingub', 'Tipolo', 'Umapad',
    // Lapu-Lapu barangays
    'Agus', 'Babag', 'Bankal (Lapu-Lapu)', 'Basak (Lapu-Lapu)', 'Buaya',
    'Calawisan', 'Canjulao', 'Caubian', 'Caw-oy', 'Cawhagan', 'Gun-ob',
    'Ibo', 'Looc (Lapu-Lapu)', 'Mactan', 'Maribago', 'Marigondon',
    'Pajac', 'Pajo', 'Pangan-an', 'Poblacion (Lapu-Lapu)', 'Punta Engaño',
    'Pusok', 'Sabang', 'San Vicente', 'Santa Rosa', 'Subabasbas',
    'Talima', 'Tingo', 'Tungasan',
  ];

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _fullNameCtrl.dispose();
    _addressCtrl.dispose();
    _mobile1Ctrl.dispose();
    _mobile2Ctrl.dispose();
    _ecNameCtrl.dispose();
    super.dispose();
  }

  // ── Save & proceed ────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedBarangay == null) {
      _showToast('Please select your barangay.', error: true);
      return;
    }
    if (!_agreed) {
      _showToast('Please agree to the terms to continue.', error: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    final data = RegistrationData(
      fullName:        _fullNameCtrl.text.trim(),
      barangay:        _selectedBarangay!,
      address:         _addressCtrl.text.trim(),
      mobilePrimary:   _mobile1Ctrl.text.trim(),
      mobileSecondary: _mobile2Ctrl.text.trim(),
      ecName:          _ecNameCtrl.text.trim(),
    );

    final ok = await RegistrationService.instance.saveRegistration(data);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;

      // [FIX 1] Show success toast then wait before navigating to dashboard
      _showToast('Created Successfully', error: false);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;

      widget.onRegistered();
      unawaited(_syncPatientInBackground());
    } else {
      _showToast('Could not save registration. Please try again.', error: true);
    }
  }

  Future<void> _syncPatientInBackground() async {
    if (AppConfig.useMockApi) return;
    try {
      await SessionService.instance.syncPatientFromRegistration();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RegisterScreen] Background patient sync failed: $e\n$st');
      }
    }
  }

  void _showToast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ]),
        backgroundColor: error ? AppTheme.crimson : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Personal Info ─────────────────────────────────
                      _SectionLabel(
                        icon: Icons.person_outline_rounded,
                        label: 'Personal Information',
                        color: AppTheme.blue,
                      ),
                      const SizedBox(height: 14),
                      _FormCard(children: [
                        _Field(
                          ctrl: _fullNameCtrl,
                          label: 'Full Name',
                          hint: 'Juan Dela Cruz',
                          icon: Icons.badge_outlined,
                          validator: _required,
                        ),
                        // ── Barangay Dropdown ────────────────────────
                        _BarangayDropdownField(
                          value: _selectedBarangay,
                          barangays: _cebuBarangays,
                          onChanged: (v) => setState(() => _selectedBarangay = v),
                        ),
                        _Field(
                          ctrl: _addressCtrl,
                          label: 'Full Address',
                          hint: 'Street, Barangay, City',
                          icon: Icons.home_outlined,
                          maxLines: 2,
                          isLast: true,
                        ),
                      ]),

                      const SizedBox(height: 28),

                      // ── Contact Numbers ───────────────────────────────
                      _SectionLabel(
                        icon: Icons.phone_outlined,
                        label: 'Contact Numbers',
                        color: AppTheme.crimson,
                      ),
                      const SizedBox(height: 8),
                      _InfoNote(
                        text:
                            'Mobile No. 1 is used to identify and contact you. '
                            'Mobile No. 2 is for your emergency contact person.',
                      ),
                      const SizedBox(height: 14),
                      _FormCard(accentColor: AppTheme.crimson, children: [
                        _Field(
                          ctrl: _mobile1Ctrl,
                          label: 'Mobile No. 1 — Primary (You)',
                          hint: '09XX XXX XXXX',
                          icon: Icons.smartphone_rounded,
                          keyboard: TextInputType.phone,
                          validator: _requiredPhone,
                          prefix: _PhonePrefix(label: 'PRIMARY'),
                        ),
                        _Field(
                          ctrl: _mobile2Ctrl,
                          label: 'Mobile No. 2 — Emergency Contact',
                          hint: '09XX XXX XXXX',
                          icon: Icons.contact_phone_outlined,
                          keyboard: TextInputType.phone,
                          prefix: _PhonePrefix(
                              label: 'EMERGENCY', color: AppTheme.warning),
                          isLast: true,
                        ),
                      ]),

                      const SizedBox(height: 28),

                      // ── Emergency Contact Name ─────────────────────────
                      _SectionLabel(
                        icon: Icons.contact_emergency_outlined,
                        label: 'Emergency Contact Person',
                        color: const Color(0xFF6B48FF),
                      ),
                      const SizedBox(height: 14),
                      _FormCard(
                          accentColor: const Color(0xFF6B48FF),
                          children: [
                            _Field(
                              ctrl: _ecNameCtrl,
                              label: 'Contact Person\'s Full Name',
                              hint: 'Name of person to call in emergency',
                              icon: Icons.person_pin_outlined,
                              isLast: true,
                            ),
                          ]),

                      const SizedBox(height: 28),

                      _GpsNoticeCard(),

                      const SizedBox(height: 24),

                      // ── Already have profile ──────────────────────────
                      if (widget.onRequestSignIn != null)
                        Center(
                          child: TextButton(
                            onPressed: _isSaving ? null : () {
                              HapticFeedback.selectionClick();
                              widget.onRequestSignIn!();
                            },
                            child: Text(
                              'Already have a profile? Sign in with your phone',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.blue,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),

                      if (widget.onRequestSignIn != null) const SizedBox(height: 4),

                      // ── [FIX 1] Driver Login link ─────────────────────
                      Center(
                        child: TextButton.icon(
                          onPressed: _isSaving ? null : () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DriverLoginScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.local_shipping_rounded,
                              size: 15, color: AppTheme.crimson),
                          label: Text(
                            'Are you a driver? Go to Driver Login',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.crimson,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Agreement checkbox ────────────────────────────
                      _AgreementRow(
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                      ),

                      const SizedBox(height: 30),

                      // ── Submit button ─────────────────────────────────
                      GestureDetector(
                        onTap: _isSaving ? null : _submit,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            gradient: _agreed
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFF1A35),
                                      Color(0xFFD0021B),
                                      Color(0xFF9B0015),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: _agreed ? null : const Color(0xFFF0F2F5),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: _agreed
                                ? [
                                    BoxShadow(
                                      color: AppTheme.crimson.withOpacity(0.48),
                                      blurRadius: 30,
                                      offset: const Offset(0, 12),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isSaving)
                                const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white))
                              else
                                Icon(
                                  Icons.how_to_reg_rounded,
                                  color: _agreed ? Colors.white : AppTheme.textLight,
                                  size: 22,
                                ),
                              const SizedBox(width: 12),
                              Text(
                                _isSaving ? 'REGISTERING...' : 'CREATE MY PROFILE',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _agreed ? Colors.white : AppTheme.textLight,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
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
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          height: 300,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1B2A), Color(0xFF1A2E47), Color(0xFF0F3460)],
            ),
          ),
        ),
        Positioned(
          right: -50, top: -50,
          child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.crimson.withOpacity(0.28), Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          left: -40, bottom: 10,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.blue.withOpacity(0.22), Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF1A35), Color(0xFFD0021B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.crimson.withOpacity(0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Text('ResQmove',
                      style: GoogleFonts.outfit(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 0.3,
                      )),
                ]),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.crimson.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.crimson.withOpacity(0.35)),
                  ),
                  child: Text('📋  QUICK REGISTRATION',
                      style: GoogleFonts.outfit(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: const Color(0xFFFF6B6B), letterSpacing: 1.0,
                      )),
                ),
                const SizedBox(height: 12),
                Text('Create Your\nSafety Profile',
                    style: GoogleFonts.outfit(
                      fontSize: 34, fontWeight: FontWeight.w900,
                      color: Colors.white, height: 1.1, letterSpacing: -1.0,
                    )),
                const SizedBox(height: 10),
                Text(
                  'Register your details so we can reach you faster '
                  'in an emergency — even if GPS is slow or unavailable.',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: Colors.white60, height: 1.55),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Validators ────────────────────────────────────────────────────────────
  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  String? _requiredPhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    if (v.trim().length < 7) return 'Enter a valid phone number';
    return null;
  }
}

// ─────────────────────────────────────────────
//  BARANGAY DROPDOWN FIELD
// ─────────────────────────────────────────────

class _BarangayDropdownField extends StatelessWidget {
  final String? value;
  final List<String> barangays;
  final ValueChanged<String?> onChanged;

  const _BarangayDropdownField({
    required this.value,
    required this.barangays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: Text('Select your barangay',
                style: GoogleFonts.outfit(
                    fontSize: 15, color: const Color(0xFFADB5BD))),
            icon: const Icon(Icons.expand_more_rounded,
                color: Color(0xFFADB5BD), size: 20),
            style: GoogleFonts.outfit(
                fontSize: 15,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w500),
            items: barangays
                .map((b) => DropdownMenuItem(
                    value: b,
                    child: Text(b, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  REUSABLE WIDGETS
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 12),
      Text(label,
          style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark)),
    ]);
  }
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  final Color? accentColor;

  const _FormCard({required this.children, this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: children
          .expand((child) => [child, const SizedBox(height: 10)])
          .toList()
        ..removeLast(),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboard;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool isLast;
  final Widget? prefix;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.isLast = false,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isLast ? 8 : 8, 16, isLast ? 16 : 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          maxLines: maxLines,
          validator: validator,
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
            suffixIcon: prefix,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 18,
            ),
            errorStyle: GoogleFonts.outfit(
              fontSize: 11,
              color: AppTheme.crimson,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhonePrefix extends StatelessWidget {
  final String label;
  final Color color;

  const _PhonePrefix(
      {required this.label, this.color = const Color(0xFF1E88E5)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
            fontSize: 8.5, fontWeight: FontWeight.w800,
            color: color, letterSpacing: 0.5,
          )),
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.blue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.blue.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.blue, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.outfit(
                    fontSize: 12, color: AppTheme.blue, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _GpsNoticeCard extends StatelessWidget {
  const _GpsNoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF7CFC00).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF7CFC00).withOpacity(0.25)),
            ),
            child: const Icon(Icons.gps_fixed_rounded,
                color: Color(0xFF7CFC00), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GPS + Profile = Faster Response',
                    style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 5),
                Text(
                  'Your GPS location is shared automatically when you request help. '
                  'Your profile details serve as a reliable backup when GPS is slow or inaccurate.',
                  style: GoogleFonts.outfit(
                      fontSize: 11.5, color: Colors.white60, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _AgreementRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: value ? AppTheme.crimson : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: value ? AppTheme.crimson : AppTheme.border,
                width: 1.5,
              ),
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: AppTheme.crimson.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: value
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'I agree that this information will be used by ResQmove to '
              'facilitate emergency ambulance services on my behalf.',
              style: GoogleFonts.outfit(
                  fontSize: 12.5, color: AppTheme.textMid, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
