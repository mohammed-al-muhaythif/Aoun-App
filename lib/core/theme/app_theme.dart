import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const purple = Color(0xFF7F77DD);
  static const purpleDark = Color(0xFF6A60C9);
  static const purpleLight = Color(0xFFEFEDFB);
  static const purpleAccent = Color(0xFFAFA7F0);

  static const statusInProgress = Color(0xFFF59E0B); // amber
  static const statusCompleted = Color(0xFF22C55E);  // green
  static const statusOverdue = Color(0xFFEF4444);    // red
  static const statusPending = Color(0xFF94A3B8);    // slate

  static const priorityHigh = Color(0xFFEF4444);
  static const priorityMedium = Color(0xFFF59E0B);
  static const priorityLow = Color(0xFF22C55E);

  static const surface = Color(0xFFF7F7FB);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  /// Linear gradient used on hero headers (welcome card, screen banners).
  static const purpleGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [purpleDark, purple, purpleAccent],
  );
}

ThemeData buildAwanTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.purple,
    primary: AppColors.purple,
    brightness: Brightness.light,
  );

  // Cairo for Arabic UI typography.
  final textTheme = GoogleFonts.cairoTextTheme().apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: AppColors.surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.purple,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cairo(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        textStyle: GoogleFonts.cairo(
            fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
      labelStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.purpleLight,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      iconTheme: const WidgetStatePropertyAll(
        IconThemeData(color: AppColors.purple),
      ),
    ),
  );
}
