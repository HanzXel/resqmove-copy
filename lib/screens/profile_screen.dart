import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../services/registration_service.dart';
import '../models/models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fullNameCtrl    = TextEditingController();
  final _contactCtrl     = TextEditingController();
  final _locationCtrl    = TextEditingController();
  final _ecNameCtrl      = TextEditingController();
  final _ecNumberCtrl    = TextEditingController();

  String? _selectedHospital;
  bool _isLoading   = true;
  bool _isSaving    = false;
  String? _errorMsg;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  static const List<String> _hospitals = [
    'Chong Hua Hospital',
    'Cebu Doctors\' University Hospital',
    'Vicente Sotto Memorial Medical Center',
    'Perpetual Succour Hospital',
    'Cebu Velez General Hospital',
    'St. Vincent General Hospital',
    'UC Med - University of Cebu Medical Center',
    'Brokenshire Memorial Hospital',
    'Cebu City Medical Center',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _contactCtrl.dispose();
    _locationCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecNumberCtrl.dispose();
    super.dispose();
  }

  // ── Profile picture picker ─────────────────────────────────────────────────

  Future<void> _pickProfileImage() async {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 44, height: 5,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 20),
              Text('Profile Photo', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppTheme.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.blue),
                ),
                title: Text('Take a photo', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textDark)),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (picked != null && mounted) setState(() => _profileImage = File(picked.path));
                },
              ),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppTheme.crimson.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.crimson),
                ),
                title: Text('Choose from gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textDark)),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (picked != null && mounted) setState(() => _profileImage = File(picked.path));
                },
              ),
              if (_profileImage != null)
                ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delete_rounded, color: Colors.red),
                  ),
                  title: Text('Remove photo', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _profileImage = null);
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Load profile from service ──────────────────────────────────────────────

  Future<void> _loadProfile() async {
    setState(() { _isLoading = true; _errorMsg = null; });

    final result = await ProfileService.instance.getPatientProfile();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.data != null) {
      final user = result.data!;
      // If the service returned non-empty data, use it
      if (user.fullName.isNotEmpty || user.contactNumber.isNotEmpty) {
        _fullNameCtrl.text   = user.fullName;
        _contactCtrl.text    = user.contactNumber;
        _locationCtrl.text   = user.address ?? '';
        _ecNameCtrl.text     = user.emergencyContact?.name ?? '';
        _ecNumberCtrl.text   = user.emergencyContact?.contactNumber ?? '';
        _selectedHospital    = _hospitals.contains(user.preferredHospital)
            ? user.preferredHospital
            : null;
        setState(() {});
        return;
      }
    }

    // [FIX 2] Fallback: read directly from local SharedPreferences registration data
    final reg = await RegistrationService.instance.loadRegistration();
    if (!mounted) return;
    if (reg != null && !reg.isEmpty) {
      _fullNameCtrl.text  = reg.fullName;
      _contactCtrl.text   = reg.mobilePrimary;
      _locationCtrl.text  = reg.address.isNotEmpty ? reg.address : reg.barangay;
      _ecNameCtrl.text    = reg.ecName;
      _ecNumberCtrl.text  = reg.mobileSecondary;
    }
    setState(() {});
  }

  // ── Save profile via service ───────────────────────────────────────────────

  Future<void> _saveProfile() async {
    HapticFeedback.mediumImpact();
    setState(() { _isSaving = true; _errorMsg = null; });

    final user = UserModel(
      id: AuthService.instance.currentUser?.id,
      fullName: _fullNameCtrl.text.trim(),
      contactNumber: _contactCtrl.text.trim(),
      address: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      preferredHospital: _selectedHospital,
      emergencyContact: (_ecNameCtrl.text.trim().isNotEmpty ||
              _ecNumberCtrl.text.trim().isNotEmpty)
          ? EmergencyContact(
              name: _ecNameCtrl.text.trim(),
              contactNumber: _ecNumberCtrl.text.trim(),
            )
          : null,
    );

    final result = await ProfileService.instance.updatePatientProfile(user);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Profile saved successfully!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      setState(() => _errorMsg = result.errorMessage ?? 'Failed to save profile.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  expandedHeight: 280,
                  pinned: true,
                  elevation: 0,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(height: 1, color: AppTheme.border),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0D1B2A), Color(0xFF1A2E47), Color(0xFF0D1B2A)],
                            ),
                          ),
                        ),
                        Positioned(right: -60, top: -60,
                          child: Container(width: 280, height: 280,
                            decoration: BoxDecoration(shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [AppTheme.crimson.withOpacity(0.22), Colors.transparent])),
                          ),
                        ),
                        Positioned(left: -40, bottom: -30,
                          child: Container(width: 200, height: 200,
                            decoration: BoxDecoration(shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [AppTheme.blue.withOpacity(0.2), Colors.transparent])),
                          ),
                        ),
                        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
                        SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _pickProfileImage,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 96, height: 96,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.07)]),
                                        border: Border.all(color: Colors.white.withOpacity(0.28), width: 3),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 10))],
                                      ),
                                      child: _profileImage != null
                                          ? ClipOval(child: Image.file(_profileImage!, fit: BoxFit.cover, width: 96, height: 96))
                                          : const Icon(Icons.person_rounded, color: Colors.white54, size: 52),
                                    ),
                                    Positioned(bottom: 2, right: 2,
                                      child: Container(
                                        width: 30, height: 30,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF1565C0)]),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFF0D1B2A), width: 2.5),
                                          boxShadow: [BoxShadow(color: AppTheme.blue.withOpacity(0.45), blurRadius: 10)],
                                        ),
                                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _fullNameCtrl.text.isEmpty ? 'Your Name' : _fullNameCtrl.text,
                                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _HeaderBadge(icon: Icons.verified_rounded, label: 'Member', color: AppTheme.crimson),
                                  const SizedBox(width: 8),
                                  _HeaderBadge(icon: Icons.location_on_rounded, label: 'Cebu City', color: AppTheme.blue),
                                  const SizedBox(width: 8),
                                  _HeaderBadge(icon: Icons.star_rounded, label: 'Active', color: AppTheme.warning),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Error banner
                        if (_errorMsg != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.crimson.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.crimson.withOpacity(0.25)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_errorMsg!,
                                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.crimson))),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ],

                        _SectionTitle(title: 'Personal Information', icon: Icons.person_outline_rounded, color: AppTheme.blue),
                        const SizedBox(height: 14),
                        _ProfileCard(children: [
                          _ProfileField(label: 'Full Name', hint: 'Enter your full name',
                              icon: Icons.badge_outlined, controller: _fullNameCtrl,
                              onChanged: (_) => setState(() {})),
                          _CardDivider(),
                          _ProfileField(label: 'Contact Number', hint: 'Enter your phone number',
                              icon: Icons.phone_outlined, controller: _contactCtrl,
                              keyboard: TextInputType.phone),
                          _CardDivider(),
                          _ProfileField(label: 'Location / Address', hint: 'Enter your home address',
                              icon: Icons.location_on_outlined, controller: _locationCtrl, isLast: true),
                        ]),

                        const SizedBox(height: 28),

                        _SectionTitle(title: 'Emergency Contact', icon: Icons.contact_emergency_outlined, color: AppTheme.crimson),
                        const SizedBox(height: 14),
                        _ProfileCard(accentColor: AppTheme.crimson, children: [
                          _ProfileField(label: 'Contact Name', hint: 'Full name of emergency contact',
                              icon: Icons.person_pin_outlined, controller: _ecNameCtrl),
                          _CardDivider(),
                          _ProfileField(label: 'Contact Number', hint: 'Phone number',
                              icon: Icons.phone_in_talk_outlined, controller: _ecNumberCtrl,
                              keyboard: TextInputType.phone, isLast: true),
                        ]),

                        const SizedBox(height: 28),

                        _SectionTitle(title: 'Medical Preferences', icon: Icons.local_hospital_outlined, color: AppTheme.blue),
                        const SizedBox(height: 14),
                        _HospitalDropdownCard(
                          selectedHospital: _selectedHospital,
                          hospitals: _hospitals,
                          onChanged: (v) => setState(() => _selectedHospital = v),
                        ),

                        const SizedBox(height: 36),

                        Row(children: [
                          Expanded(child: _QuickActionCard(icon: Icons.history_rounded, label: 'Request\nHistory', color: const Color(0xFF6B48FF))),
                          const SizedBox(width: 12),
                          Expanded(child: _QuickActionCard(icon: Icons.help_outline_rounded, label: 'Help &\nSupport', color: AppTheme.blue)),
                          const SizedBox(width: 12),
                          Expanded(child: _QuickActionCard(icon: Icons.notifications_outlined, label: 'Notification\nSettings', color: AppTheme.warning)),
                        ]),

                        const SizedBox(height: 28),

                        GestureDetector(
                          onTap: _isSaving ? null : _saveProfile,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E88E5), Color(0xFF1565C0), Color(0xFF0D47A1)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(color: AppTheme.blue.withOpacity(0.48), blurRadius: 28, offset: const Offset(0, 12)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isSaving)
                                  const SizedBox(width: 22, height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                else
                                  const Icon(Icons.save_rounded, color: Colors.white, size: 22),
                                const SizedBox(width: 12),
                                Text(_isSaving ? 'SAVING...' : 'SAVE PROFILE',
                                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800,
                                        color: Colors.white, letterSpacing: 1.0)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Painters & Widgets ────────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.025)..style = PaintingStyle.fill;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }
  @override bool shouldRepaint(_DotGridPainter old) => false;
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _HeaderBadge({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(22), border: Border.all(color: color.withOpacity(0.36))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12), const SizedBox(width: 5),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title; final IconData icon; final Color color;
  const _SectionTitle({required this.title, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 12),
      Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
    ]);
  }
}

class _ProfileCard extends StatelessWidget {
  final List<Widget> children; final Color? accentColor;
  const _ProfileCard({required this.children, this.accentColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor?.withOpacity(0.18) ?? AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(children: children),
    );
  }
}

class _HospitalDropdownCard extends StatelessWidget {
  final String? selectedHospital; final List<String> hospitals; final ValueChanged<String?> onChanged;
  const _HospitalDropdownCard({required this.selectedHospital, required this.hospitals, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: selectedHospital != null ? AppTheme.blue.withOpacity(0.3) : AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 7))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(color: AppTheme.blue.withOpacity(0.09), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.blue.withOpacity(0.16))),
              child: const Icon(Icons.local_hospital_outlined, color: AppTheme.blue, size: 19)),
            const SizedBox(width: 13),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Default Hospital', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              Text('For ambulance routing', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textLight)),
            ]),
          ]),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedHospital,
                hint: Text('Select preferred hospital', style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textLight)),
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded, color: AppTheme.textLight),
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                items: hospitals.map((h) =>
                    DropdownMenuItem(value: h, child: Text(h, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label, hint; final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboard; final ValueChanged<String>? onChanged; final bool isLast;
  const _ProfileField({required this.label, required this.hint, required this.icon,
      required this.controller, this.keyboard = TextInputType.text, this.onChanged, this.isLast = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 20, 18, isLast ? 20 : 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border)),
            child: Icon(icon, color: AppTheme.textLight, size: 19)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600,
                color: AppTheme.textLight, letterSpacing: 0.3)),
            const SizedBox(height: 6),
            TextField(controller: controller, keyboardType: keyboard, onChanged: onChanged,
              style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textDark, fontWeight: FontWeight.w600),
              decoration: InputDecoration(hintText: hint,
                hintStyle: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textLight),
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)),
          ])),
        ]),
        if (!isLast) const SizedBox(height: 10),
      ]),
    );
  }
}

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 16));
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _QuickActionCard({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.14)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.18))),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700,
                  color: AppTheme.textDark, height: 1.3)),
        ]),
      ),
    );
  }
}
