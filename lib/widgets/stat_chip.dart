import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatChip extends StatelessWidget {
  final String value;
  final String label;

  const StatChip({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.crimson,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: AppTheme.textMid,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
