import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── DARK THEME (Police Navy) ──────────────────────────────────────────────
const kDarkBg         = Color(0xFF0F172A);  // Slate 900 - Deep Navy Canvas
const kDarkSurface    = Color(0xFF1E293B);  // Slate 800 - Card Surface
const kDarkBorder     = Color(0xFF334155);  // Slate 700 - Dividers
const kDarkMuted      = Color(0xFF64748B);  // Slate 500 - Muted
const kDarkText       = Color(0xFFF8FAFC);  // Slate 50 - Primary Text
const kDarkSubtext    = Color(0xFF94A3B8);  // Slate 400 - Secondary text

// ── LIGHT THEME (Standard) ────────────────────────────────────────────────
const kLightBg        = Color(0xFFF1F5F9);  // Slate 100
const kLightSurface   = Color(0xFFFFFFFF);  // White Card Surface
const kLightBorder    = Color(0xFFCBD5E1);  // Slate 300
const kLightMuted     = Color(0xFF94A3B8);  // Slate 400
const kLightText      = Color(0xFF0F172A);  // Slate 900
const kLightSubtext   = Color(0xFF475569);  // Slate 600

// Accent colors (identical across themes)
const kAccentGreen    = Color(0xFF10B981);  // Emerald 500
const kAccentGreenDim = Color(0xFF059669);  // Emerald 600
const kAccentRed      = Color(0xFFEF4444);  // Red 500
const kAccentAmber    = Color(0xFFF59E0B);  // Amber 500
const kAccentBlue     = Color(0xFF3B82F6);  // Blue 500
const kBadgeBg        = Color(0xFF334155);  // Slate 700

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kDarkBg,
      primaryColor: kAccentBlue,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: kAccentBlue,
        secondary: kAccentGreen,
        surface: kDarkSurface,
        background: kDarkBg,
        error: kAccentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kDarkBg,
        elevation: 0,
        iconTheme: IconThemeData(color: kDarkText),
        titleTextStyle: TextStyle(color: kDarkText, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: kDarkSurface,
        selectedItemColor: kAccentBlue,
        unselectedItemColor: kDarkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      dividerTheme: const DividerThemeData(
        color: kDarkBorder,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: kDarkSurface,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kDarkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      textTheme: _buildTextTheme(kDarkText, kDarkSubtext),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: kLightBg,
      primaryColor: kAccentBlue,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary: kAccentBlue,
        secondary: kAccentGreen,
        surface: kLightSurface,
        background: kLightBg,
        error: kAccentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kLightBg,
        elevation: 0,
        iconTheme: IconThemeData(color: kLightText),
        titleTextStyle: TextStyle(color: kLightText, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: kLightSurface,
        selectedItemColor: kAccentBlue,
        unselectedItemColor: kLightMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      dividerTheme: const DividerThemeData(
        color: kLightBorder,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: kLightSurface,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kLightBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      textTheme: _buildTextTheme(kLightText, kLightSubtext),
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: primary),
      displayMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: primary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: secondary),
      labelLarge: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: secondary),
    );
  }

  // Keeping mono properties for compatibility with older code, but using standard fonts where applicable
  static TextStyle get monoLg => GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700);
  static TextStyle get monoMd => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle get monoSm => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500);
}
