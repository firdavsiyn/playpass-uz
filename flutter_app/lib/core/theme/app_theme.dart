import 'dart:ui';
import 'package:flutter/material.dart';

/// Theme-aware colors via BuildContext extension.
/// Use `context.card`, `context.surface`, etc. instead of hardcoded AppTheme.bgCard
extension ThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Backgrounds
  Color get bg => isDark ? AppTheme.bgDark : AppTheme.lightBg;
  Color get card => isDark ? AppTheme.bgCard : AppTheme.lightCard;
  Color get cardDark => isDark ? AppTheme.bgCard : const Color(0xFFF1F3F5);
  Color get surface => isDark ? AppTheme.bgSurface : AppTheme.lightSurface;

  // Text
  Color get text1 => isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
  Color get text2 => isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
  Color get text3 => isDark ? AppTheme.textMuted : AppTheme.lightTextMuted;

  // Borders
  Color get border => isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
  Color get borderSubtle => isDark ? const Color(0xFF1F2937) : const Color(0xFFF0F0F0);

  // Glass
  Color get glass => isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000);

  // Nav bar bg
  Color get navBg => isDark ? const Color(0xFF0D0D1A) : Colors.white;
}

class AppTheme {
  // Brand colors
  static const Color primary = Color(0xFF6366F1);       // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accent = Color(0xFF2563EB);        // Electric Blue

  // Neon glow colors
  static const Color neonPurple = Color(0xFF7C3AED);
  static const Color neonBlue = Color(0xFF3B82F6);
  static const Color neonCyan = Color(0xFF06B6D4);
  static const Color neonPink = Color(0xFFEC4899);

  // Background (dark theme)
  static const Color bgDark = Color(0xFF0A0A14);
  static const Color bgCard = Color(0xFF141428);
  static const Color cardDark = Color(0xFF141428); // alias for bgCard
  static const Color bgSurface = Color(0xFF12122A);
  static const Color bgGlass = Color(0x1AFFFFFF);  // 10% white for glassmorphism
  static const Color border = Color(0xFF374151);

  // Text
  static const Color textPrimary = Color(0xFFF8F9FA);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Neon glow utilities ──────────────────────────────────

  /// Primary neon glow shadow
  static List<BoxShadow> neonGlow({Color? color, double radius = 20, double spread = 0}) => [
    BoxShadow(
      color: (color ?? primary).withValues(alpha: 0.4),
      blurRadius: radius,
      spreadRadius: spread,
    ),
    BoxShadow(
      color: (color ?? primary).withValues(alpha: 0.15),
      blurRadius: radius * 2,
      spreadRadius: spread,
    ),
  ];

  /// Subtle card glow
  static List<BoxShadow> cardGlow({Color? color}) => [
    BoxShadow(
      color: (color ?? primary).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 4),
    ),
  ];

  /// Glassmorphism decoration
  static BoxDecoration glassDecoration({
    double borderRadius = 16,
    Color? glowColor,
    double borderOpacity = 0.15,
  }) => BoxDecoration(
    color: bgGlass,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: (glowColor ?? primary).withValues(alpha: borderOpacity),
    ),
    boxShadow: cardGlow(color: glowColor),
  );

  /// Neon gradient for borders and accents
  static const LinearGradient neonGradient = LinearGradient(
    colors: [neonPurple, primary, neonBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient neonGradientSubtle = LinearGradient(
    colors: [Color(0x337C3AED), Color(0x336366F1), Color(0x333B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primary,
      primaryContainer: primaryDark,
      secondary: accent,
      surface: bgCard,
      background: bgDark,
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onBackground: textPrimary,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: bgDark,
    fontFamily: 'Inter',

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF374151)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF374151)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: textMuted),
      labelStyle: const TextStyle(color: textSecondary),
    ),

    // BottomNavBar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF0D0D1A),
      selectedItemColor: primary,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // Text styles
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      bodySmall: TextStyle(color: textMuted),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFF1F2937),
      thickness: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: bgCard,
      contentTextStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // ── Light Theme ────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF8F9FA);
  static const Color lightCard = Colors.white;
  static const Color lightSurface = Color(0xFFF1F3F5);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextMuted = Color(0xFF9CA3AF);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primary,
      primaryContainer: primaryLight,
      secondary: accent,
      surface: lightCard,
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightTextPrimary,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: lightBg,
    fontFamily: 'Inter',

    appBarTheme: const AppBarTheme(
      backgroundColor: lightBg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: lightTextPrimary,
      ),
      iconTheme: IconThemeData(color: lightTextPrimary),
    ),

    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: lightTextMuted),
      labelStyle: const TextStyle(color: lightTextSecondary),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primary,
      unselectedItemColor: lightTextMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: lightTextPrimary),
      bodyMedium: TextStyle(color: lightTextSecondary),
      bodySmall: TextStyle(color: lightTextMuted),
    ),

    dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB), thickness: 1),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightTextPrimary,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
