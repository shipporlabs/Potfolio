import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Potfolio brand colours (see the brand guidelines).
class PColors {
  static const blue = Color(0xFF0052FF);
  static const midBlue = Color(0xFF4D86FF);
  static const sky = Color(0xFF99B9FF);
  static const navy = Color(0xFF0A1A3A);
  static const clay = Color(0xFFD9653B);
  static const cream = Color(0xFFFBF6EE);
  static const mist = Color(0xFFF3F6FC);
  static const line = Color(0xFFE3E8F2);
  static const slate = Color(0xFF5B6475);
  static const gain = Color(0xFF0B8A5C);
  static const loss = Color(0xFFD14343);
  static const clayTint = Color(0xFFFFF4EE);
  static const blueTint = Color(0xFFEAF0FF);

  /// Chart order: Blue, Mid Blue, Sky, Navy, then repeats softer.
  static const chart = [blue, midBlue, sky, navy, Color(0xFFB8CEFF), Color(0xFF2E3F66)];
}

TextStyle display(double size, {Color color = PColors.navy, FontWeight weight = FontWeight.w800}) =>
    GoogleFonts.interTight(fontSize: size, fontWeight: weight, color: color, letterSpacing: -size * 0.03, height: 1.08);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: PColors.blue, primary: PColors.blue, surface: Colors.white),
    scaffoldBackgroundColor: PColors.mist,
  );
  final text = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: PColors.navy, displayColor: PColors.navy);
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: PColors.mist,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: PColors.navy,
      titleTextStyle: GoogleFonts.interTight(fontSize: 18, fontWeight: FontWeight.w700, color: PColors.navy),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PColors.navy,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: PColors.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: PColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: PColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: PColors.blue, width: 1.5)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: PColors.blueTint,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
