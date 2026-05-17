import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../services/registration_service.dart';
import '../services/request_service.dart';
import '../models/models.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'services_screen.dart';
import 'tracking_screen.dart';

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

  // SharedPreferences key for persisting profile picture path
  static const String _profileImageKey = 'resqmove_profile_image_path';

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
    _loadSavedProfileImage();
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

  // ── [FIX] Copy image to permanent app-documents directory ─────────────────
  // image_picker returns a temp/cache path that Android can delete any time.
  // We copy it to getApplicationDocumentsDirectory() so it survives restarts.

  Future<String?> _copyImageToPermanentStorage(String tempPath) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_picture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final permanentFile = File('${docsDir.path}/$fileName');

      // Delete old permanent file if it exists (cleanup old copies)
      final prefs = await SharedPreferences.getInstance();
      final oldPath = prefs.getString(_profileImageKey);
      if (oldPath != null && oldPath.isNotEmpty && oldPath != tempPath) {
        try { await File(oldPath).delete(); } catch (_) {}
      }

      await File(tempPath).copy(permanentFile.path);
      return permanentFile.path;
    } catch (_) {
      return tempPath; // fallback to original path if copy fails
    }
  }

  // ── Load profile picture from SharedPreferences ────────────────────────────

  Future<void> _loadSavedProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(_profileImageKey);
      if (savedPath != null && savedPath.isNotEmpty) {
        final file = File(savedPath);
        if (await file.exists()) {
          if (mounted) setState(() => _profileImage = file);
        } else {
          // File was deleted/moved, clear the stale path
          await prefs.remove(_profileImageKey);
        }
      }
    } catch (_) {}
  }

  // ── Save profile picture path to SharedPreferences ─────────────────────────

  Future<void> _saveProfileImagePath(String? path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (path != null && path.isNotEmpty) {
        await prefs.setString(_profileImageKey, path);
      } else {
        await prefs.remove(_profileImageKey);
      }
    } catch (_) {}
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
                  if (picked != null && mounted) {
                    // [FIX] Copy to permanent storage so it survives app restarts
                    final permanentPath = await _copyImageToPermanentStorage(picked.path);
                    if (permanentPath != null) {
                      await _saveProfileImagePath(permanentPath);
                      if (mounted) setState(() => _profileImage = File(permanentPath));
                    }
                  }
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
                  if (picked != null && mounted) {
                    // [FIX] Copy to permanent storage so it survives app restarts
                    final permanentPath = await _copyImageToPermanentStorage(picked.path);
                    if (permanentPath != null) {
                      await _saveProfileImagePath(permanentPath);
                      if (mounted) setState(() => _profileImage = File(permanentPath));
                    }
                  }
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
                  onTap: () async {
                    Navigator.pop(context);
                    // Delete the permanent file
                    try { await _profileImage?.delete(); } catch (_) {}
                    setState(() => _profileImage = null);
                    await _saveProfileImagePath(null);
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

    // Fallback: read directly from local SharedPreferences registration data
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

    // Profile image is already saved to permanent storage when picked —
    // no extra action needed here; just confirm path is persisted.
    if (_profileImage != null) {
      await _saveProfileImagePath(_profileImage!.path);
    }

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
                          Expanded(child: _QuickActionCard(
                            icon: Icons.history_rounded, label: 'Request\nHistory', color: const Color(0xFF6B48FF),
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _ProfileRequestHistorySheet(),
                            ),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _QuickActionCard(
                            icon: Icons.help_outline_rounded, label: 'Help &\nSupport', color: AppTheme.blue,
                            // [FIX] Opens a simple help dialog
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('Help & Support', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
                                content: Text(
                                  'For emergency dispatch, call our hotline at 0917-123-4567.\n\nFor app issues, email support@resqmove.ph or contact your barangay health officer.',
                                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid, height: 1.5),
                                ),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: GoogleFonts.outfit(color: AppTheme.blue, fontWeight: FontWeight.w700)))],
                              ),
                            ),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _QuickActionCard(
                            icon: Icons.notifications_outlined, label: 'Notification\nSettings', color: AppTheme.warning,
                            // [FIX] Opens a simple notification info dialog
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
                                content: Text(
                                  'ResQmove sends push notifications for ambulance dispatch updates and request status changes.\n\nTo manage notifications, go to your phone Settings > Apps > ResQmove > Notifications.',
                                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid, height: 1.5),
                                ),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: GoogleFonts.outfit(color: AppTheme.warning, fontWeight: FontWeight.w700)))],
                              ),
                            ),
                          )),
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

                        const SizedBox(height: 20),

                        // [FIX] Logout button
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('Sign Out', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textDark)),
                                content: Text('Are you sure you want to sign out?', style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textMid, fontWeight: FontWeight.w600))),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text('Sign Out', style: GoogleFonts.outfit(color: AppTheme.crimson, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && mounted) {
                              await AuthService.instance.logout();
                              await RegistrationService.instance.clearRegistration();
                              // Navigate to root and rebuild AppBootstrap
                              if (mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const _RelaunchApp()),
                                  (_) => false,
                                );
                              }
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppTheme.crimson.withOpacity(0.35)),
                              boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 5))],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.logout_rounded, color: AppTheme.crimson, size: 20),
                                const SizedBox(width: 12),
                                Text('SIGN OUT',
                                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.crimson, letterSpacing: 0.8)),
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

// _ProfileField — unified style, identical to _LabeledFieldRow in booking_screen.dart
// Same icon size, font sizes, content padding, and grey-pill container so all
// input fields across the app look and feel the same.
class _ProfileField extends StatelessWidget {
  final String label, hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboard;
  final ValueChanged<String>? onChanged;
  final bool isLast;

  const _ProfileField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboard = TextInputType.text,
    this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, isLast ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row — matches _LabeledFieldRow exactly
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(icon, color: AppTheme.textLight, size: 17),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textLight,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // Input box — same grey pill, same padding as booking screen fields
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.transparent),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              onChanged: onChanged,
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
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
              ),
            ),
          ),
          if (!isLast) const SizedBox(height: 16),
        ],
      ),
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
  final VoidCallback? onTap; // [FIX] make cards functional
  const _QuickActionCard({required this.icon, required this.label, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap?.call(); },
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

// Request history sheet for the Profile screen
class _ProfileRequestHistorySheet extends StatefulWidget {
  @override
  State<_ProfileRequestHistorySheet> createState() => _ProfileRequestHistorySheetState();
}

class _ProfileRequestHistorySheetState extends State<_ProfileRequestHistorySheet> {
  List<AmbulanceRequestModel> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await RequestService.instance.getRequestHistory();
      if (mounted) setState(() { _requests = result.requests; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 44, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 20),
          Text('Request History', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF1A1F36))),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ))
          else if (_requests.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No requests yet', style: GoogleFonts.outfit(fontSize: 15, color: Colors.grey.shade400)),
              ]),
            ))
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _requests.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = _requests[i];
                  final status = r.status.label;
                  final type = r.emergencyType.label;
                  final date = r.requestedAt != null
                      ? '${r.requestedAt!.year}-${r.requestedAt!.month.toString().padLeft(2,'0')}-${r.requestedAt!.day.toString().padLeft(2,'0')}'
                      : '';
                  final color = r.status == RequestStatus.completed ? Colors.green
                      : r.status == RequestStatus.cancelled ? Colors.red
                      : Colors.orange;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.1),
                      child: Icon(Icons.emergency_rounded, color: color, size: 18),
                    ),
                    title: Text(type, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text(date, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(status, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
// Uses runApp-equivalent restart by pushing to a new root route.
class _RelaunchApp extends StatefulWidget {
  const _RelaunchApp();
  @override
  State<_RelaunchApp> createState() => _RelaunchAppState();
}

class _RelaunchAppState extends State<_RelaunchApp> {
  bool? _registered;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ok = await RegistrationService.instance.isRegistered();
    if (mounted) setState(() => _registered = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_registered == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_registered == false) {
      return RegisterScreen(
        onRegistered: () => setState(() => _registered = true),
      );
    }
    // Show all 4 patient tabs freshly
    return _PatientShell();
  }
}

// A slimmed-down copy of MainShell used only post-logout inside ProfileScreen
class _PatientShell extends StatefulWidget {
  @override
  State<_PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<_PatientShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    ServicesScreen(),
    TrackingScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services_rounded), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on_rounded), label: 'Track'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
