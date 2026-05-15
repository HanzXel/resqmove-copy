import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  // Controllers
  final _firstNameCtrl      = TextEditingController();
  final _lastNameCtrl       = TextEditingController();
  final _licenseCtrl        = TextEditingController();
  final _phoneCtrl          = TextEditingController();
  final _emailCtrl          = TextEditingController();
  final _addressCtrl        = TextEditingController();
  final _usernameCtrl       = TextEditingController();
  final _passwordCtrl       = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String? _selectedUnit;
  String? _selectedExperience;
  bool _obscurePassword        = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading              = false;
  bool _agreedToTerms          = false;
  String? _errorMessage;

  int _currentStep = 0; // 0 = Personal, 1 = Assignment, 2 = Account

  // ── Data ──────────────────────────────────────────────────────────────────
  static const List<String> _units = [
    'RESQ-101 · Chong Hua Hospital',
    'RESQ-102 · Cebu Doctors\' University Hospital',
    'RESQ-103 · Vicente Sotto Memorial Medical Center',
    'RESQ-104 · Perpetual Succour Hospital',
    'RESQ-105 · Cebu Velez General Hospital',
    'RESQ-106 · UC Med',
    'RESQ-107 · Cebu City Medical Center',
  ];

  static const List<String> _experienceLevels = [
    'Less than 1 year',
    '1 – 3 years',
    '3 – 5 years',
    '5 – 10 years',
    '10+ years',
  ];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _licenseCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  String? _validateStep() {
    if (_currentStep == 0) {
      if (_firstNameCtrl.text.trim().isEmpty) return 'Please enter your first name.';
      if (_lastNameCtrl.text.trim().isEmpty)  return 'Please enter your last name.';
      if (_licenseCtrl.text.trim().isEmpty)   return 'Please enter your driver\'s license number.';
      if (_phoneCtrl.text.trim().isEmpty)     return 'Please enter your phone number.';
    } else if (_currentStep == 1) {
      if (_selectedUnit == null)       return 'Please select an ambulance unit.';
      if (_selectedExperience == null) return 'Please select your experience level.';
    } else if (_currentStep == 2) {
      if (_usernameCtrl.text.trim().isEmpty)  return 'Please choose a username.';
      if (_passwordCtrl.text.length < 8)      return 'Password must be at least 8 characters.';
      if (_passwordCtrl.text != _confirmPasswordCtrl.text) return 'Passwords do not match.';
      if (!_agreedToTerms) return 'You must agree to the terms and conditions.';
    }
    return null;
  }

  void _nextStep() {
    HapticFeedback.selectionClick();
    final error = _validateStep();
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    setState(() {
      _errorMessage = null;
      if (_currentStep < 2) _currentStep++;
    });
  }

  void _prevStep() {
    HapticFeedback.selectionClick();
    setState(() {
      _errorMessage = null;
      if (_currentStep > 0) _currentStep--;
    });
  }

  Map<String, String?> _parsedUnit() {
    final u = _selectedUnit;
    if (u == null || u.isEmpty) return {};
    final parts = u
        .split(RegExp(r'\s*·\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return {};
    return {
      'unit_id': parts.first,
      if (parts.length > 1) 'hospital': parts.sublist(1).join(' · '),
    };
  }

  Future<void> _submit() async {
    final error = _validateStep();
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() { _isLoading = true; _errorMessage = null; });

    final unit = _parsedUnit();
    final fullName =
        '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();

    final result = await AuthService.instance.registerDriver(
      driverId: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      fullName: fullName,
      contactNumber: _phoneCtrl.text.trim(),
      unitId: unit['unit_id'],
      hospitalName: unit['hospital'],
      unitType: _selectedExperience,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      setState(() => _errorMessage = result.errorMessage ?? 'Registration failed.');
      return;
    }

    // Show success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(
        onDone: () {
          Navigator.of(context).pop(); // close dialog
          Navigator.of(context).pop(); // back to login
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Column(
        children: [
          _RegisterHeroHeader(
            onBack: () => Navigator.pop(context),
            currentStep: _currentStep,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step indicator
                  _StepIndicator(currentStep: _currentStep),
                  const SizedBox(height: 28),

                  // Error banner
                  if (_errorMessage != null) ...[
                    _ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: 20),
                  ],

                  // Step content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_currentStep),
                      child: _buildCurrentStep(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Navigation buttons
                  _buildNavButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _StepPersonal(
        firstNameCtrl: _firstNameCtrl,
        lastNameCtrl: _lastNameCtrl,
        licenseCtrl: _licenseCtrl,
        phoneCtrl: _phoneCtrl,
        emailCtrl: _emailCtrl,
        addressCtrl: _addressCtrl,
      );
      case 1: return _StepAssignment(
        selectedUnit: _selectedUnit,
        selectedExperience: _selectedExperience,
        units: _units,
        experienceLevels: _experienceLevels,
        onUnitChanged: (v) => setState(() => _selectedUnit = v),
        onExperienceChanged: (v) => setState(() => _selectedExperience = v),
      );
      case 2: return _StepAccount(
        usernameCtrl: _usernameCtrl,
        passwordCtrl: _passwordCtrl,
        confirmPasswordCtrl: _confirmPasswordCtrl,
        obscurePassword: _obscurePassword,
        obscureConfirmPassword: _obscureConfirmPassword,
        agreedToTerms: _agreedToTerms,
        onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
        onToggleConfirmPassword: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        onTermsChanged: (v) => setState(() => _agreedToTerms = v ?? false),
      );
      default: return const SizedBox();
    }
  }

  Widget _buildNavButtons() {
    return Row(
      children: [
        // Back button (hidden on first step)
        if (_currentStep > 0) ...[
          Expanded(
            child: GestureDetector(
              onTap: _prevStep,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppTheme.textMid),
                    const SizedBox(width: 8),
                    Text('Back', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textMid)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Next / Submit button
        Expanded(
          flex: _currentStep > 0 ? 2 : 1,
          child: GestureDetector(
            onTap: _isLoading ? null : (_currentStep < 2 ? _nextStep : _submit),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF1A35), Color(0xFFD0021B), Color(0xFF9B0015)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppTheme.crimson.withOpacity(0.48), blurRadius: 28, offset: const Offset(0, 12)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  else
                    Icon(
                      _currentStep < 2 ? Icons.arrow_forward_rounded : Icons.check_rounded,
                      color: Colors.white, size: 22,
                    ),
                  const SizedBox(width: 10),
                  Text(
                    _isLoading ? 'SUBMITTING...' : (_currentStep < 2 ? 'NEXT' : 'SUBMIT'),
                    style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  STEP WIDGETS
// ═══════════════════════════════════════════════════════════

class _StepPersonal extends StatelessWidget {
  final TextEditingController firstNameCtrl, lastNameCtrl, licenseCtrl,
      phoneCtrl, emailCtrl, addressCtrl;

  const _StepPersonal({
    required this.firstNameCtrl, required this.lastNameCtrl,
    required this.licenseCtrl,  required this.phoneCtrl,
    required this.emailCtrl,    required this.addressCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          icon: Icons.person_outline_rounded,
          title: 'Personal Information',
          subtitle: 'Your basic biographical details',
        ),
        const SizedBox(height: 18),
        _FieldCard(children: [
          _RegField(label: 'First Name',  hint: 'Juan',       icon: Icons.badge_outlined,       controller: firstNameCtrl),
          _FieldDivider(),
          _RegField(label: 'Last Name',   hint: 'Dela Cruz',  icon: Icons.badge_outlined,       controller: lastNameCtrl),
          _FieldDivider(),
          _RegField(label: 'Phone Number', hint: '09XX XXX XXXX', icon: Icons.phone_outlined,   controller: phoneCtrl, keyboard: TextInputType.phone),
          _FieldDivider(),
          _RegField(label: 'Email Address', hint: 'you@email.com', icon: Icons.email_outlined,  controller: emailCtrl, keyboard: TextInputType.emailAddress),
          _FieldDivider(),
          _RegField(label: 'Home Address', hint: 'Street, Barangay, City', icon: Icons.home_outlined, controller: addressCtrl, isLast: true),
        ]),
        const SizedBox(height: 20),
        _FieldCard(children: [
          _RegField(label: "Driver's License No.", hint: 'e.g. N01-12-345678', icon: Icons.credit_card_rounded, controller: licenseCtrl, isLast: true),
        ]),
      ],
    );
  }
}

class _StepAssignment extends StatelessWidget {
  final String? selectedUnit, selectedExperience;
  final List<String> units, experienceLevels;
  final ValueChanged<String?> onUnitChanged, onExperienceChanged;

  const _StepAssignment({
    required this.selectedUnit,    required this.selectedExperience,
    required this.units,           required this.experienceLevels,
    required this.onUnitChanged,   required this.onExperienceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          icon: Icons.local_shipping_rounded,
          title: 'Assignment Details',
          subtitle: 'Your ambulance unit and experience',
        ),
        const SizedBox(height: 18),

        // Unit assignment
        _DropdownCard(
          icon: Icons.airport_shuttle_rounded,
          label: 'Ambulance Unit',
          hint: 'Select your assigned unit',
          value: selectedUnit,
          items: units,
          onChanged: onUnitChanged,
        ),
        const SizedBox(height: 14),

        // Experience
        _DropdownCard(
          icon: Icons.timer_outlined,
          label: 'Years of Experience',
          hint: 'Select experience level',
          value: selectedExperience,
          items: experienceLevels,
          onChanged: onExperienceChanged,
        ),
        const SizedBox(height: 20),

        // Info box
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.blue.withOpacity(0.07), AppTheme.blue.withOpacity(0.02)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.blue.withOpacity(0.16)),
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppTheme.blue, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Your assignment will be verified by the ResQmove command center before activation.',
                  style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textMid, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepAccount extends StatelessWidget {
  final TextEditingController usernameCtrl, passwordCtrl, confirmPasswordCtrl;
  final bool obscurePassword, obscureConfirmPassword, agreedToTerms;
  final VoidCallback onTogglePassword, onToggleConfirmPassword;
  final ValueChanged<bool?> onTermsChanged;

  const _StepAccount({
    required this.usernameCtrl,           required this.passwordCtrl,
    required this.confirmPasswordCtrl,    required this.obscurePassword,
    required this.obscureConfirmPassword, required this.agreedToTerms,
    required this.onTogglePassword,       required this.onToggleConfirmPassword,
    required this.onTermsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          icon: Icons.lock_outline_rounded,
          title: 'Account Credentials',
          subtitle: 'Set up your driver login',
        ),
        const SizedBox(height: 18),
        _FieldCard(children: [
          _RegField(label: 'Username / Driver ID', hint: 'Choose a unique username',
              icon: Icons.person_outline_rounded, controller: usernameCtrl),
          _FieldDivider(),
          _RegField(label: 'Password', hint: 'Minimum 8 characters',
              icon: Icons.lock_outline_rounded, controller: passwordCtrl,
              obscure: obscurePassword,
              suffix: GestureDetector(
                onTap: onTogglePassword,
                child: Icon(
                  obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.textLight, size: 19,
                ),
              )),
          _FieldDivider(),
          _RegField(label: 'Confirm Password', hint: 'Re-enter your password',
              icon: Icons.lock_reset_rounded, controller: confirmPasswordCtrl,
              obscure: obscureConfirmPassword, isLast: true,
              suffix: GestureDetector(
                onTap: onToggleConfirmPassword,
                child: Icon(
                  obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.textLight, size: 19,
                ),
              )),
        ]),
        const SizedBox(height: 20),

        // Terms checkbox
        GestureDetector(
          onTap: () => onTermsChanged(!agreedToTerms),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: agreedToTerms ? AppTheme.success.withOpacity(0.4) : AppTheme.border,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: agreedToTerms ? AppTheme.success : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: agreedToTerms ? AppTheme.success : AppTheme.border, width: 2),
                    boxShadow: agreedToTerms
                        ? [BoxShadow(color: AppTheme.success.withOpacity(0.35), blurRadius: 8)]
                        : [],
                  ),
                  child: agreedToTerms
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMid, height: 1.4),
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.blue),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.blue),
                        ),
                        const TextSpan(text: ' of ResQmove.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════

class _StepTitle extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  const _StepTitle({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF1A35), Color(0xFFD0021B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
            Text(subtitle,
                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = ['Personal', 'Assignment', 'Account'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // connector line
          final leftDone = i ~/ 2 < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: leftDone
                      ? [AppTheme.crimson, AppTheme.crimson]
                      : [AppTheme.border, AppTheme.border],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final done    = stepIndex < currentStep;
        final active  = stepIndex == currentStep;
        final color   = done || active ? AppTheme.crimson : AppTheme.border;

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: done ? AppTheme.crimson : (active ? AppTheme.crimson.withOpacity(0.12) : AppTheme.surfaceLight),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: done || active ? 2 : 1.5),
                boxShadow: active ? [BoxShadow(color: AppTheme.crimson.withOpacity(0.3), blurRadius: 10)] : [],
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
                    : Text('${stepIndex + 1}',
                        style: GoogleFonts.outfit(
                            fontSize: 14, fontWeight: FontWeight.w800,
                            color: active ? AppTheme.crimson : AppTheme.textLight)),
              ),
            ),
            const SizedBox(height: 5),
            Text(steps[stepIndex],
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppTheme.crimson : AppTheme.textLight)),
          ],
        );
      }),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final List<Widget> children;
  const _FieldCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(children: children),
    );
  }
}

class _FieldDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 18));
}

class _RegField extends StatelessWidget {
  final String label, hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscure, isLast;
  final Widget? suffix;
  final TextInputType keyboard;

  const _RegField({
    required this.label, required this.hint, required this.icon,
    required this.controller,
    this.obscure = false, this.isLast = false,
    this.suffix, this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, isLast ? 18 : 10),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, color: AppTheme.textLight, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w600,
                    color: AppTheme.textLight, letterSpacing: 0.2)),
                const SizedBox(height: 5),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      obscureText: obscure,
                      keyboardType: keyboard,
                      style: GoogleFonts.outfit(fontSize: 15, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textLight),
                        border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (suffix != null) suffix!,
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownCard extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownCard({
    required this.icon, required this.label, required this.hint,
    required this.value, required this.items, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: value != null ? AppTheme.crimson.withOpacity(0.3) : AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16)],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: value != null ? AppTheme.crimson.withOpacity(0.09) : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: value != null ? AppTheme.crimson.withOpacity(0.2) : AppTheme.border),
            ),
            child: Icon(icon, color: value != null ? AppTheme.crimson : AppTheme.textLight, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w600,
                    color: AppTheme.textLight, letterSpacing: 0.2)),
                const SizedBox(height: 4),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    hint: Text(hint, style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textLight)),
                    icon: const Icon(Icons.expand_more_rounded, color: AppTheme.textLight, size: 18),
                    style: GoogleFonts.outfit(fontSize: 13.5, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                    isDense: true,
                    items: items.map((u) => DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: onChanged,
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

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Text(message,
                style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.crimson, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HERO HEADER
// ─────────────────────────────────────────────

class _RegisterHeroHeader extends StatelessWidget {
  final VoidCallback onBack;
  final int currentStep;
  const _RegisterHeroHeader({required this.onBack, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const stepLabels = ['Personal Info', 'Assignment', 'Account Setup'];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: AppTheme.textDark),
      child: Stack(
        children: [
          Positioned(right: -50, top: -50,
            child: Container(width: 260, height: 260,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppTheme.crimson.withOpacity(0.28), Colors.transparent]))),
          ),
          Positioned(left: -30, bottom: -30,
            child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppTheme.blue.withOpacity(0.22), Colors.transparent]))),
          ),
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
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
                  const SizedBox(height: 22),
                  Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF1A35), Color(0xFFD0021B)]),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 5))],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 23),
                    ),
                    const SizedBox(width: 11),
                    Text('ResQmove',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppTheme.success.withOpacity(0.35)),
                      ),
                      child: Text('Driver Registration',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text('Step ${currentStep + 1} of 3',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500)),
                  Text(stepLabels[currentStep],
                      style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.025)..style = PaintingStyle.fill;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }
  @override bool shouldRepaint(_DotGridPainter old) => false;
}

// ─────────────────────────────────────────────
//  SUCCESS DIALOG
// ─────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessDialog({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.success, Color(0xFF2E7D32)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.success.withOpacity(0.40), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 20),
            Text('Registration Submitted!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textDark)),
            const SizedBox(height: 10),
            Text(
              'Your driver registration has been sent to the ResQmove command center for verification. You will be notified once your account is approved.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMid, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onDone,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF1A35), Color(0xFFD0021B)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.40), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: Text('Back to Login',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
