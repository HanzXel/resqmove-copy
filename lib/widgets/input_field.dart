import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class InputField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? errorText;

  const InputField({
    super.key,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.onChanged,
    this.enabled = true,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? AppTheme.surfaceLight : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        onChanged: onChanged,
        style: GoogleFonts.outfit(
          color: AppTheme.textDark,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          errorText: errorText,
          hintStyle: GoogleFonts.outfit(
            color: AppTheme.textLight,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(icon, color: AppTheme.textLight, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        ),
      ),
    );
  }
}
