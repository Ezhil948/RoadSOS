import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color surfaceDark = Color(0xFF12121A);
  static const Color surfaceElevated = Color(0xFF1C1C28);
  static const Color borderDark = Color(0xFF2A2A3D);
  static const Color primaryRed = Color(0xFFFF3B30);
  static const Color primaryRedDim = Color(0xFF7A1A15);
  static const Color accentBlue = Color(0xFF0A84FF);
  static const Color accentGreen = Color(0xFF30D158);
  static const Color accentAmber = Color(0xFFFF9F0A);
  static const Color accentPurple = Color(0xFFBF5AF2);
  static const Color accentTeal = Color(0xFF5AC8FA);
  static const Color accentPink = Color(0xFFFF375F);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0x99EBEBF5); // ~60% opacity white
  static const Color textMuted = Color(0x4DEBEBF5);     // ~30% opacity

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        secondary: accentBlue,
        surface: surfaceDark,
        error: primaryRed,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: textPrimary),
        headlineSmall: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: textPrimary),
        titleMedium: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.1, color: textSecondary),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: textMuted),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        unselectedItemColor: textMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size.fromHeight(54),
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
    );
  }
}
