import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Core palette — white dominant, red + blue accents
  static const Color crimson = Color(0xFFD0021B);
  static const Color crimsonDark = Color(0xFF9B0015);
  static const Color crimsonLight = Color(0xFFFF1A35);
  static const Color blue = Color(0xFF1565C0);
  static const Color blueLight = Color(0xFF1E88E5);
  static const Color blueDark = Color(0xFF0D47A1);

  // White-dominant backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F7FA);
  static const Color surfaceMid = Color(0xFFEDF0F5);
  static const Color border = Color(0xFFDDE3EE);

  // Text
  static const Color textDark = Color(0xFF0D1B2A);
  static const Color textMid = Color(0xFF4A5568);
  static const Color textLight = Color(0xFF8A97A8);

  // Status
  static const Color success = Color(0xFF00C851);
  static const Color warning = Color(0xFFFFB300);
  static const Color snow = Color(0xFFFFFFFF);
  static const Color silver = Color(0xFF8A97A8);

  // Legacy aliases (kept for existing widgets that still reference them)
  static const Color navy = background;
  static const Color navyMid = surfaceLight;
  static const Color navyLight = border;
  static const Color surface = surfaceLight;
  static const Color steel = textLight;
  static const Color accent = blue;

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.light(
          primary: crimson,
          secondary: blue,
          surface: surfaceLight,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: textDark,
          contentTextStyle: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: border),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceLight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          hintStyle: GoogleFonts.outfit(
            color: textLight,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: blue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: crimson),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: crimson, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: border),
            foregroundColor: textDark,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        splashFactory: InkSparkle.splashFactory,
        textTheme: GoogleFonts.outfitTextTheme().apply(
          bodyColor: textDark,
          displayColor: textDark,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: textDark),
          titleTextStyle: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textDark,
            letterSpacing: 0.5,
          ),
        ),
      );
}
