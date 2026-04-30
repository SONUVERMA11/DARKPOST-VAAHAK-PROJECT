import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette — Underground Cipher Aesthetic
  static const Color bg = Color(0xFF07070D);
  static const Color surface = Color(0xFF0E0E1A);
  static const Color surfaceHigh = Color(0xFF161628);
  static const Color primary = Color(0xFF00FF88);
  static const Color primaryDim = Color(0xFF00994F);
  static const Color accent = Color(0xFF00C8FF);
  static const Color danger = Color(0xFFFF3B5C);
  static const Color warning = Color(0xFFFFB800);
  static const Color textPrimary = Color(0xFFE8E8F5);
  static const Color textSecondary = Color(0xFF8888AA);
  static const Color textMuted = Color(0xFF44445A);
  static const Color border = Color(0xFF1E1E35);
  static const Color borderGlow = Color(0xFF00FF8822);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          background: bg,
          surface: surface,
          primary: primary,
          secondary: accent,
          error: danger,
        ),
        textTheme: GoogleFonts.spaceGroteskTextTheme().copyWith(
          displayLarge: GoogleFonts.spaceGrotesk(
            color: textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
          displayMedium: GoogleFonts.spaceGrotesk(
            color: textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: GoogleFonts.spaceGrotesk(
            color: textPrimary,
            fontSize: 16,
          ),
          bodyMedium: GoogleFonts.spaceGrotesk(
            color: textSecondary,
            fontSize: 14,
          ),
          labelSmall: GoogleFonts.sourceCodePro(
            color: textMuted,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          centerTitle: false,
        ),
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 1,
        ),
      );

  // Mono font style for IDs, hashes, keys
  static TextStyle mono({
    Color color = textPrimary,
    double size = 13,
    FontWeight weight = FontWeight.normal,
  }) =>
      GoogleFonts.sourceCodePro(
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0.5,
      );

  // Glow box decoration
  static BoxDecoration glowBox({
    Color glowColor = primary,
    double radius = 12,
    double glowSpread = 0,
    double glowBlur = 16,
  }) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glowColor.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.08),
            blurRadius: glowBlur,
            spreadRadius: glowSpread,
          ),
        ],
      );
}
