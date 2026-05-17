import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// A clean, pill-shaped input field that matches the app's design system.
/// No leading icon — just a soft grey fill, rounded corners, and hint text.
class InputField extends StatelessWidget {
  final String hint;
  final IconData? icon; // kept for API compatibility, ignored visually
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? errorText;
  final bool obscureText;
  final Widget? suffixIcon;

  const InputField({
    super.key,
    required this.hint,
    this.icon, // optional, no longer rendered
    this.keyboardType = TextInputType.text,
    this.controller,
    this.onChanged,
    this.enabled = true,
    this.errorText,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null
                  ? AppTheme.crimson.withOpacity(0.5)
                  : Colors.transparent,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            onChanged: onChanged,
            obscureText: obscureText,
            style: GoogleFonts.outfit(
              color: AppTheme.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(
                color: const Color(0xFFADB5BD),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 18,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[  
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 12, color: AppTheme.crimson),
              const SizedBox(width: 4),
              Text(errorText!,
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppTheme.crimson,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      ],
    );
  }
}
