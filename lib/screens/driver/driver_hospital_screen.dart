import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class DriverHospitalScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const DriverHospitalScreen({super.key, required this.request});

  @override
  State<DriverHospitalScreen> createState() => _DriverHospitalScreenState();
}

class _DriverHospitalScreenState extends State<DriverHospitalScreen> {
  String? _selectedHospital;

  static const List<Map<String, dynamic>> _hospitals = [
    {'name': 'Chong Hua Hospital', 'distance': '1.2 km', 'eta': '4 min', 'icon': Icons.local_hospital_rounded},
    {'name': 'Cebu Doctors\' University Hospital', 'distance': '2.0 km', 'eta': '7 min', 'icon': Icons.local_hospital_rounded},
    {'name': 'Vicente Sotto Memorial Medical Center', 'distance': '2.8 km', 'eta': '9 min', 'icon': Icons.local_hospital_rounded},
    {'name': 'Perpetual Succour Hospital', 'distance': '3.1 km', 'eta': '11 min', 'icon': Icons.local_hospital_rounded},
    {'name': 'Cebu City Medical Center', 'distance': '1.8 km', 'eta': '6 min', 'icon': Icons.local_hospital_rounded},
  ];

  void _confirmHospital() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Destination Set', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17))),
          ],
        ),
        content: Text(
          'Heading to $_selectedHospital with patient on board.',
          style: GoogleFonts.outfit(color: AppTheme.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // [BUG FIX] popUntil(isFirst) was returning all the way to the
              // patient HomeScreen.  The correct stack at this point is:
              //   MainShell → DriverLoginScreen → DriverShell → DriverNavigationScreen → DriverActiveTripScreen → DriverHospitalScreen → [this dialog]
              // We want to land on DriverShell, so pop: dialog + hospital +
              // active trip + navigation = 4 levels above DriverShell.
              Navigator.pop(context);      // 1: close this dialog
              Navigator.pop(context);      // 2: DriverHospitalScreen
              Navigator.pop(context);      // 3: DriverActiveTripScreen
              Navigator.pop(context);      // 4: DriverNavigationScreen
              // Now we are back on DriverShell (dashboard).
            },
            child: Text('Done', style: GoogleFonts.outfit(color: AppTheme.blue, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textDark, size: 18),
          ),
        ),
        title: Text('Select Hospital', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.textDark, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: Column(
        children: [
          // Header info
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.blue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppTheme.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.person_add_rounded, color: AppTheme.blue, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient on board', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                      Text('Select destination hospital below', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textLight)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Hospital list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _hospitals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final h = _hospitals[i];
                final selected = _selectedHospital == h['name'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedHospital = h['name']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.blue.withOpacity(0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? AppTheme.blue.withOpacity(0.5) : AppTheme.border,
                        width: selected ? 1.5 : 1,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.blue.withOpacity(0.12) : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(Icons.local_hospital_rounded, color: selected ? AppTheme.blue : AppTheme.textLight, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h['name'], style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.near_me_rounded, size: 12, color: AppTheme.textLight),
                                  const SizedBox(width: 3),
                                  Text(h['distance'], style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textLight)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.timer_outlined, size: 12, color: AppTheme.warning),
                                  const SizedBox(width: 3),
                                  Text(h['eta'], style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: selected ? AppTheme.blue : AppTheme.textLight,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Confirm button
          Padding(
            padding: const EdgeInsets.all(20),
            child: GestureDetector(
              onTap: _selectedHospital != null ? _confirmHospital : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: _selectedHospital != null
                      ? const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF1565C0)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  color: _selectedHospital == null ? AppTheme.surfaceMid : null,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _selectedHospital != null
                      ? [BoxShadow(color: AppTheme.blue.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_hospital_rounded, color: _selectedHospital != null ? Colors.white : AppTheme.textLight, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'CONFIRM DESTINATION',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _selectedHospital != null ? Colors.white : AppTheme.textLight,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
