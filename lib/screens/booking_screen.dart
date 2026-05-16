// booking_screen.dart
// NOTE: This screen is a legacy form — the main emergency flow now goes through
// the modal on HomeScreen. This screen is kept for any direct deep-links that
// land here. It is now wired to the real backend via RequestService.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/input_field.dart';
import '../services/request_service.dart';
import '../services/registration_service.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  int _selectedEmergency = 0;
  int _selectedCondition = 0;
  bool _useGps = true;
  bool _isSubmitting = false;

  late final AnimationController _submitAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.96,
    upperBound: 1.0,
    value: 1.0,
  );

  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();

  String? _nameError;
  String? _contactError;
  String? _locationError;

  final List<Map<String, dynamic>> _emergencyTypes = [
    {'label': 'Cardiac Arrest', 'apiLabel': 'Cardiac Arrest', 'icon': Icons.favorite_border_rounded, 'color': AppTheme.crimson},
    {'label': 'Accident', 'apiLabel': 'Road Traffic Accident', 'icon': Icons.car_crash_rounded, 'color': const Color(0xFFE65100)},
    {'label': 'Breathing', 'apiLabel': 'Difficulty Breathing', 'icon': Icons.air_rounded, 'color': AppTheme.blue},
    {'label': 'Other', 'apiLabel': 'Other Emergency', 'icon': Icons.more_horiz_rounded, 'color': const Color(0xFF6B48FF)},
  ];

  final List<Map<String, dynamic>> _conditionLevels = [
    {'label': 'Critical', 'color': AppTheme.crimson, 'icon': Icons.warning_rounded, 'desc': 'Immediate'},
    {'label': 'Serious', 'color': AppTheme.warning, 'icon': Icons.error_outline_rounded, 'desc': 'Urgent'},
    {'label': 'Stable', 'color': AppTheme.success, 'icon': Icons.check_circle_outline_rounded, 'desc': 'Stable'},
  ];

  @override
  void initState() {
    super.initState();
    _prefillFromRegistration();
  }

  Future<void> _prefillFromRegistration() async {
    final reg = await RegistrationService.instance.loadRegistration();
    if (!mounted || reg == null) return;
    setState(() {
      if (reg.fullName.isNotEmpty) _nameCtrl.text = reg.fullName;
      if (reg.mobilePrimary.isNotEmpty) _contactCtrl.text = reg.mobilePrimary;
      if (reg.address.isNotEmpty && !_useGps) _locationCtrl.text = reg.address;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _locationCtrl.dispose();
    _hospitalCtrl.dispose();
    _submitAnim.dispose();
    super.dispose();
  }

  bool _validateForm() {
    setState(() {
      _nameError = _nameCtrl.text.trim().isEmpty ? 'Full name is required' : null;
      _contactError = _contactCtrl.text.trim().length < 8 ? 'Enter a valid contact number' : null;
      _locationError = _locationCtrl.text.trim().isEmpty && !_useGps ? 'Location is required' : null;
    });
    return _nameError == null && _contactError == null && _locationError == null;
  }

  Future<void> _submitRequest() async {
    if (!_validateForm()) return;
    HapticFeedback.heavyImpact();
    unawaited(_submitAnim.animateTo(0.96).then((_) => _submitAnim.animateTo(1.0)));
    setState(() => _isSubmitting = true);

    // Resolve pickup location
    double lat = 10.3220, lng = 123.8920;
    String address = _locationCtrl.text.trim();

    if (_useGps) {
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {}

      // Use registered address as human-readable label if GPS-only
      if (address.isEmpty) {
        final reg = await RegistrationService.instance.loadRegistration();
        if (reg != null && reg.address.isNotEmpty) address = reg.address;
      }
    }

    final emergencyLabel = _emergencyTypes[_selectedEmergency]['apiLabel'] as String;
    final conditionNote = _conditionLevels[_selectedCondition]['label'] as String;
    final hospital = _hospitalCtrl.text.trim();
    final notes = [
      'Patient: ${_nameCtrl.text.trim()}',
      'Contact: ${_contactCtrl.text.trim()}',
      'Condition: $conditionNote',
      if (hospital.isNotEmpty) 'Preferred hospital: $hospital',
    ].join(' | ');

    final result = await RequestService.instance.submitRequest(
      emergencyTypeLabel: emergencyLabel,
      latitude: lat,
      longitude: lng,
      address: address.isNotEmpty ? address : null,
      notes: notes,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      _showSuccessSheet();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(result.errorMessage ?? 'Request failed. Please try again.',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white))),
          ]),
          backgroundColor: AppTheme.crimson,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 44, height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 24),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00C851)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.success.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Request Submitted!',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textDark)),
            const SizedBox(height: 10),
            Text('A dispatcher will call you to confirm within 2 minutes.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid, height: 1.5)),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF1A35), Color(0xFFD0021B)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Text('Done', textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildInfoBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Patient Information', Icons.person_outline_rounded, AppTheme.blue),
                  const SizedBox(height: 14),
                  _buildPatientFields(),
                  const SizedBox(height: 28),
                  _buildSectionHeader('Type of Emergency', Icons.emergency_rounded, AppTheme.crimson),
                  const SizedBox(height: 14),
                  _buildEmergencySelector(),
                  const SizedBox(height: 28),
                  _buildSectionHeader('Patient Condition', Icons.health_and_safety_rounded, AppTheme.success),
                  const SizedBox(height: 14),
                  _buildConditionSelector(),
                  const SizedBox(height: 28),
                  _buildSectionHeader('Location', Icons.location_on_outlined, AppTheme.blue),
                  const SizedBox(height: 14),
                  _buildLocationField(),
                  const SizedBox(height: 28),
                  _buildSectionHeader('Preferred Hospital', Icons.local_hospital_outlined, AppTheme.textLight, optional: true),
                  const SizedBox(height: 14),
                  InputField(
                    hint: 'Hospital name (optional)',
                    icon: Icons.local_hospital_outlined,
                    controller: _hospitalCtrl,
                  ),
                  const SizedBox(height: 36),
                  _buildSubmitButton(),
                  const SizedBox(height: 14),
                  _buildDisclaimerRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textDark, size: 17),
        ),
      ),
      title: Text('Request Ambulance',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.textDark, fontSize: 18)),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 13, color: AppTheme.warning),
              const SizedBox(width: 5),
              Text('~8 min',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.warning)),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.border),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF1A35), Color(0xFFD0021B), Color(0xFF9B0015)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Accuracy Saves Lives',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 3),
                Text('Provide accurate details for the fastest dispatch.',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, IconData icon, Color color, {bool optional = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
        if (optional) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.surfaceMid, borderRadius: BorderRadius.circular(8)),
            child: Text('Optional',
                style: GoogleFonts.outfit(fontSize: 9.5, color: AppTheme.textLight, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  Widget _buildPatientFields() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          _FieldRow(hint: 'Full name', icon: Icons.person_outline_rounded,
              controller: _nameCtrl, errorText: _nameError,
              onChanged: (_) => setState(() => _nameError = null)),
          Container(height: 1, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
          _FieldRow(hint: 'Contact number', icon: Icons.phone_outlined,
              controller: _contactCtrl, keyboardType: TextInputType.phone,
              errorText: _contactError, onChanged: (_) => setState(() => _contactError = null)),
        ],
      ),
    );
  }

  Widget _buildEmergencySelector() {
    return Row(
      children: List.generate(_emergencyTypes.length, (i) {
        final selected = _selectedEmergency == i;
        final color = _emergencyTypes[i]['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedEmergency = i); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.only(right: i < 3 ? 9 : 0),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: selected ? color : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.5 : 1),
                boxShadow: selected
                    ? [BoxShadow(color: color.withOpacity(0.38), blurRadius: 16, offset: const Offset(0, 6))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  Icon(_emergencyTypes[i]['icon'], color: selected ? Colors.white : AppTheme.textLight, size: 22),
                  const SizedBox(height: 7),
                  Text(_emergencyTypes[i]['label'],
                      style: GoogleFonts.outfit(fontSize: 10.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.white : AppTheme.textMid)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildConditionSelector() {
    return Row(
      children: List.generate(_conditionLevels.length, (i) {
        final selected = _selectedCondition == i;
        final color = _conditionLevels[i]['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedCondition = i); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.5 : 1),
                boxShadow: selected
                    ? [BoxShadow(color: color.withOpacity(0.16), blurRadius: 14, offset: const Offset(0, 5))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Icon(_conditionLevels[i]['icon'], color: selected ? color : AppTheme.textLight, size: 22),
                  const SizedBox(height: 6),
                  Text(_conditionLevels[i]['label'],
                      style: GoogleFonts.outfit(fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? color : AppTheme.textMid)),
                  const SizedBox(height: 2),
                  Text(_conditionLevels[i]['desc'],
                      style: GoogleFonts.outfit(fontSize: 9.5,
                          color: selected ? color.withOpacity(0.75) : AppTheme.textLight,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLocationField() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _locationError != null ? AppTheme.crimson.withOpacity(0.5) : AppTheme.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: _FieldRow(
            hint: 'Your current location',
            icon: Icons.location_on_outlined,
            controller: _locationCtrl,
            enabled: !_useGps,
            errorText: _locationError,
            onChanged: (_) => setState(() => _locationError = null),
            isLast: true,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() {
            _useGps = !_useGps;
            if (_useGps) { _locationCtrl.clear(); _locationError = null; }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: _useGps ? AppTheme.blue.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _useGps ? AppTheme.blue.withOpacity(0.35) : AppTheme.border, width: _useGps ? 1.5 : 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: AppTheme.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.my_location_rounded, color: AppTheme.blue, size: 19)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Use GPS Location', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                  Text('Auto-detect current coordinates', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textLight)),
                ])),
                Switch(
                  value: _useGps,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() { _useGps = v; if (v) { _locationCtrl.clear(); _locationError = null; } });
                  },
                  activeColor: AppTheme.blue,
                  activeTrackColor: AppTheme.blue.withOpacity(0.25),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ScaleTransition(
      scale: _submitAnim,
      child: GestureDetector(
        onTap: _isSubmitting ? null : _submitRequest,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF1A35), Color(0xFFD0021B), Color(0xFF9B0015)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
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
              if (!_isSubmitting)
                const Icon(Icons.emergency_rounded, color: Colors.white, size: 22)
              else
                const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
              const SizedBox(width: 12),
              Text(_isSubmitting ? 'SUBMITTING...' : 'REQUEST AMBULANCE',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.info_outline_rounded, size: 13, color: AppTheme.textLight),
        const SizedBox(width: 6),
        Flexible(child: Text('Dispatcher will call you within 2 minutes to confirm.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textLight, height: 1.4))),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED FIELD WIDGET
// ─────────────────────────────────────────────
class _FieldRow extends StatelessWidget {
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool isLast;

  const _FieldRow({
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.enabled = true,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 18, 16, isLast ? 18 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Icon(icon, color: AppTheme.textLight, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  enabled: enabled,
                  onChanged: onChanged,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textLight, fontWeight: FontWeight.w400),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: AppTheme.crimson),
              const SizedBox(width: 5),
              Text(errorText!, style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.crimson, fontWeight: FontWeight.w500)),
            ]),
          ],
          if (!isLast) const SizedBox(height: 8),
        ],
      ),
    );
  }
}
