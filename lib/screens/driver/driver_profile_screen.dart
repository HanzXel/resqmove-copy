import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  bool _isEditing = false;
  final _fullNameCtrl = TextEditingController();
  final _driverIdCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _unitIdCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _unitTypeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFromSession();
  }

  /// Pre-fill fields with data from the logged-in driver session
  void _loadFromSession() {
    final driver = AuthService.instance.currentDriver;
    if (driver == null) return;
    _fullNameCtrl.text = driver.fullName;
    _driverIdCtrl.text = driver.driverId;
    _contactCtrl.text = driver.contactNumber;
    _unitIdCtrl.text = driver.unitId ?? '';
    _hospitalCtrl.text = driver.hospitalName ?? '';
    _unitTypeCtrl.text = driver.unitType ?? '';
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose(); _driverIdCtrl.dispose(); _contactCtrl.dispose();
    _unitIdCtrl.dispose(); _hospitalCtrl.dispose(); _unitTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final base = AuthService.instance.currentDriver;
    if (base == null) return;

    setState(() {
      _isEditing = false;
    });

    final updated = DriverModel(
      id: base.id,
      fullName: _fullNameCtrl.text.trim(),
      driverId: base.driverId,
      contactNumber: _contactCtrl.text.trim(),
      unitId: _unitIdCtrl.text.trim().isEmpty ? null : _unitIdCtrl.text.trim(),
      hospitalName: _hospitalCtrl.text.trim().isEmpty ? null : _hospitalCtrl.text.trim(),
      unitType: _unitTypeCtrl.text.trim().isEmpty ? null : _unitTypeCtrl.text.trim(),
      status: base.status,
    );

    final result = await ProfileService.instance.updateDriverProfile(updated);
    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver profile saved!', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Save failed.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.crimson,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.crimson.withOpacity(0.09),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.crimson.withOpacity(0.25)),
                ),
                child: const Icon(Icons.logout_rounded, color: AppTheme.crimson, size: 34),
              ),
              const SizedBox(height: 22),
              Text('Log Out', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textDark)),
              const SizedBox(height: 10),
              Text('Are you sure you want to log out of the driver portal?',
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid, height: 1.45),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Center(child: Text('Cancel',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMid))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await AuthService.instance.logout();
                        if (!context.mounted) return;
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF1A35), Color(0xFFD0021B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.40), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Center(child: Text('Log Out',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: 300,
            pinned: true,
            automaticallyImplyLeading: false,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppTheme.border),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(color: AppTheme.textDark),
                child: Stack(
                  children: [
                    Positioned(right: -60, top: -60,
                      child: Container(width: 260, height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [AppTheme.crimson.withOpacity(0.28), Colors.transparent]),
                        ),
                      ),
                    ),
                    Positioned(left: -40, bottom: -20,
                      child: Container(width: 200, height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [AppTheme.blue.withOpacity(0.22), Colors.transparent]),
                        ),
                      ),
                    ),
                    Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
                    SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 14),
                          Stack(
                            children: [
                              Container(
                                width: 100, height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Colors.white.withOpacity(0.16), Colors.white.withOpacity(0.07)],
                                  ),
                                  border: Border.all(color: Colors.white.withOpacity(0.26), width: 3),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.32), blurRadius: 24, offset: const Offset(0, 10))],
                                ),
                                child: const Icon(Icons.person_rounded, color: Colors.white60, size: 54),
                              ),
                              Positioned(
                                bottom: 2, right: 2,
                                child: Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF1A35), AppTheme.crimson],
                                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.textDark, width: 2.5),
                                    boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.5), blurRadius: 12)],
                                  ),
                                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _fullNameCtrl.text.isEmpty ? 'Profile Not Set' : _fullNameCtrl.text,
                            style: GoogleFonts.outfit(fontSize: 23, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _driverIdCtrl.text.isEmpty ? 'ResQmove Driver' : _driverIdCtrl.text,
                            style: GoogleFonts.outfit(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _HeaderChip(icon: Icons.verified_rounded, label: 'Verified', color: AppTheme.success),
                              const SizedBox(width: 8),
                              _HeaderChip(icon: Icons.star_rounded, label: 'Active Duty', color: AppTheme.warning),
                              const SizedBox(width: 8),
                              _HeaderChip(icon: Icons.shield_rounded, label: 'Certified', color: AppTheme.blue),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick stats
                  _SectionLabel(label: "Today's Summary", icon: Icons.bar_chart_rounded, color: AppTheme.blue),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      _MiniStat(label: 'Trips\nCompleted', color: AppTheme.success,
                          icon: Icons.check_circle_outline_rounded, value: '0'),
                      SizedBox(width: 11),
                      _MiniStat(label: 'Pending\nRequests', color: AppTheme.warning,
                          icon: Icons.notifications_active_rounded, value: '0'),
                      SizedBox(width: 11),
                      _MiniStat(label: 'Avg\nResponse', color: AppTheme.crimson,
                          icon: Icons.timer_outlined, value: '--'),
                    ],
                  ),

                  const SizedBox(height: 30),

                  _SectionLabel(label: 'Driver Information', icon: Icons.badge_outlined, color: AppTheme.blue),
                  const SizedBox(height: 14),
                  _InfoCard(
                    children: [
                      _ProfileField(icon: Icons.person_outline_rounded, label: 'Full Name',
                          hint: 'Enter your full name', controller: _fullNameCtrl,
                          isEditable: _isEditing, onChanged: (_) => setState(() {})),
                      _Divider(),
                      _ProfileField(icon: Icons.badge_outlined, label: 'Driver ID',
                          hint: 'Enter your driver ID', controller: _driverIdCtrl,
                          isEditable: _isEditing, onChanged: (_) => setState(() {})),
                      _Divider(),
                      _ProfileField(icon: Icons.phone_outlined, label: 'Contact',
                          hint: 'Enter your contact number', controller: _contactCtrl,
                          isEditable: _isEditing, keyboard: TextInputType.phone),
                    ],
                  ),

                  const SizedBox(height: 26),

                  _SectionLabel(label: 'Ambulance Unit', icon: Icons.local_shipping_rounded, color: AppTheme.crimson),
                  const SizedBox(height: 14),
                  _InfoCard(
                    accentColor: AppTheme.crimson,
                    children: [
                      _ProfileField(icon: Icons.local_shipping_rounded, label: 'Unit ID',
                          hint: 'Enter ambulance unit ID', controller: _unitIdCtrl, isEditable: _isEditing),
                      _Divider(),
                      _ProfileField(icon: Icons.local_hospital_outlined, label: 'Hospital',
                          hint: 'Enter assigned hospital', controller: _hospitalCtrl, isEditable: _isEditing),
                      _Divider(),
                      _ProfileField(icon: Icons.medical_services_outlined, label: 'Unit Type',
                          hint: 'ALS / BLS / etc.', controller: _unitTypeCtrl, isEditable: _isEditing),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Edit / Save button
                  if (!_isEditing)
                    GestureDetector(
                      onTap: () => setState(() => _isEditing = true),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 19),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppTheme.blue.withOpacity(0.35), width: 1.5),
                          boxShadow: [BoxShadow(color: AppTheme.blue.withOpacity(0.09), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_rounded, color: AppTheme.blue, size: 20),
                            const SizedBox(width: 10),
                            Text('EDIT PROFILE',
                                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800,
                                    color: AppTheme.blue, letterSpacing: 1.0)),
                          ],
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _saveProfile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 19),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E88E5), Color(0xFF1565C0), Color(0xFF0D47A1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(color: AppTheme.blue.withOpacity(0.45), blurRadius: 26, offset: const Offset(0, 11)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text('SAVE PROFILE',
                                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: 1.0)),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

                  GestureDetector(
                    onTap: () => _logout(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 19),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppTheme.crimson.withOpacity(0.28)),
                        boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.06), blurRadius: 12)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout_rounded, color: AppTheme.crimson, size: 20),
                          const SizedBox(width: 10),
                          Text('LOG OUT',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800,
                                  color: AppTheme.crimson, letterSpacing: 1.0)),
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

// ═══════════════════════════════════════════
//  LOCAL WIDGETS
// ═══════════════════════════════════════════

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..style = PaintingStyle.fill;
    const spacing = 22.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }
  @override bool shouldRepaint(_DotGridPainter old) => false;
}

class _HeaderChip extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _HeaderChip({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.38)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12), const SizedBox(width: 5),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label; final IconData icon; final Color color;
  const _SectionLabel({required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
      const SizedBox(width: 12),
      Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
    ]);
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children; final Color? accentColor;
  const _InfoCard({required this.children, this.accentColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor?.withOpacity(0.16) ?? AppTheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final IconData icon; final String label, hint;
  final TextEditingController controller;
  final TextInputType keyboard; final bool isEditable;
  final ValueChanged<String>? onChanged;
  const _ProfileField({
    required this.icon, required this.label, required this.hint,
    required this.controller, required this.isEditable,
    this.keyboard = TextInputType.text, this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, color: AppTheme.textLight, size: 17),
        ),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 10.5, color: AppTheme.textLight,
              fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          const SizedBox(height: 5),
          TextField(
            controller: controller, keyboardType: keyboard,
            readOnly: !isEditable, onChanged: isEditable ? onChanged : null,
            style: GoogleFonts.outfit(fontSize: 15, color: AppTheme.textDark, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textLight, fontWeight: FontWeight.w400),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
          ),
        ])),
        if (isEditable)
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppTheme.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_outlined, color: AppTheme.blue, size: 14),
          ),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 18));
}

class _MiniStat extends StatelessWidget {
  final String label; final Color color; final IconData icon; final String value;
  const _MiniStat({required this.label, required this.color, required this.icon, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.12)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 11),
          Text(value, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textDark)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 9.5, color: AppTheme.textLight, height: 1.3)),
        ]),
      ),
    );
  }
}
