import 'dart:ui';
import 'package:flutter/material.dart';

/// Theme-aware colors via BuildContext extension.
extension ThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Backgrounds
  Color get bg => isDark ? AppTheme.bgDark : AppTheme.lightBg;
  Color get card => isDark ? AppTheme.bgCard : AppTheme.lightCard;
  Color get cardDark => isDark ? AppTheme.bgCardDeep : const Color(0xFFF1F3F5);
  Color get surface => isDark ? AppTheme.bgSurface : AppTheme.lightSurface;

  // Text
  Color get text1 => isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
  Color get text2 => isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
  Color get text3 => isDark ? AppTheme.textMuted : AppTheme.lightTextMuted;

  // Borders
  Color get border => isDark ? const Color(0xFF2A1F4E) : AppTheme.lightBorder;
  Color get borderSubtle => isDark ? const Color(0xFF1A1040) : const Color(0xFFEDE9FE);

  // Glass
  Color get glass => isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000);
  Color get glassStrong => isDark ? const Color(0x28FFFFFF) : const Color(0x18000000);

  // Nav bar bg
  Color get navBg => isDark ? const Color(0xFF06060F) : Colors.white;
}

class AppTheme {
  // ── Brand Colors ────────────────────────────────────────
  static const Color primary = Color(0xFF7C3AED);       // Vibrant Purple
  static const Color primaryLight = Color(0xFF9F67FF);
  static const Color primaryDark = Color(0xFF5B21B6);
  static const Color accent = Color(0xFF06B6D4);        // Neon Cyan

  // Neon glow colors
  static const Color neonPurple = Color(0xFF8B5CF6);
  static const Color neonBlue = Color(0xFF3B82F6);
  static const Color neonCyan = Color(0xFF06B6D4);
  static const Color neonPink = Color(0xFFF472B6);      // Refined — softer pink for multi-color gradients
  static const Color neonGreen = Color(0xFF10B981);
  static const Color neonMagenta = Color(0xFFF472B6);   // Alias for neonPink — used in gradient contexts
  static const Color neonLavender = Color(0xFFA78BFA);  // NEW — softer purple for subtle accents

  // ── Background (dark theme) ─────────────────────────────
  static const Color bgDark = Color(0xFF040811);        // Deeper, richer dark — almost pure black with blue-purple hint
  static const Color bgCard = Color(0xFF0C0A1D);        // Deeper card
  static const Color bgCardDeep = Color(0xFF080716);    // Even darker card
  static const Color bgSurface = Color(0xFF110E24);     // Richer elevated surface
  static const Color bgGlass = Color(0x0EFFFFFF);       // More subtle glassmorphism overlay

  // ── Text ────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF0EDFF);   // Slightly purple-tinted white
  static const Color textSecondary = Color(0xFF8B7EB0); // Slightly richer muted purple
  static const Color textMuted = Color(0xFF4E4470);     // Adjusted deep muted

  // ── Status Colors ───────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Tier Colors ─────────────────────────────────────────
  static const Color tierVip = Color(0xFFFBBF24);
  static const Color tierPro = Color(0xFF8B5CF6);
  static const Color tierStandard = Color(0xFF06B6D4);

  // ── Neon Glow Utilities ─────────────────────────────────

  /// Primary neon glow shadow
  static List<BoxShadow> neonGlow({Color? color, double radius = 20, double spread = 0}) => [
    BoxShadow(
      color: (color ?? primary).withValues(alpha: 0.5),
      blurRadius: radius,
      spreadRadius: spread,
    ),
    BoxShadow(
      color: (color ?? primary).withValues(alpha: 0.2),
      blurRadius: radius * 2.5,
      spreadRadius: spread,
    ),
  ];

  /// Subtle card glow
  static List<BoxShadow> cardGlow({Color? color}) => [
    BoxShadow(
      color: (color ?? primary).withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 4),
    ),
  ];

  /// Glassmorphism decoration
  static BoxDecoration glassDecoration({
    double borderRadius = 16,
    Color? glowColor,
    double borderOpacity = 0.2,
  }) => BoxDecoration(
    color: bgGlass,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: (glowColor ?? primary).withValues(alpha: borderOpacity),
    ),
    boxShadow: cardGlow(color: glowColor),
  );

  /// Gaming card decoration — the signature look
  static BoxDecoration gamingCard({
    double borderRadius = 16,
    Color? glowColor,
    double borderAlpha = 0.15,
    bool intense = false,
    bool gradientBorder = false,
  }) {
    final resolvedGlow = glowColor ?? primary;

    if (gradientBorder) {
      // Gradient border is achieved via a container with gradient + inner container
      // Return the outer decoration; caller nests an inner container with bgCard fill
      return BoxDecoration(
        gradient: LinearGradient(
          colors: [
            resolvedGlow.withValues(alpha: 0.6),
            neonCyan.withValues(alpha: 0.3),
            resolvedGlow.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: intense
            ? neonGlow(color: resolvedGlow, radius: 16, spread: -2)
            : cardGlow(color: resolvedGlow),
      );
    }

    return BoxDecoration(
      color: bgCard,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: resolvedGlow.withValues(alpha: borderAlpha),
        width: intense ? 1.5 : 1.0,
      ),
      boxShadow: intense
          ? neonGlow(color: resolvedGlow, radius: 16, spread: -2)
          : cardGlow(color: resolvedGlow),
    );
  }

  /// Glassmorphism card decoration — frosted glass effect with configurable opacity
  static BoxDecoration glassCard({
    double borderRadius = 16,
    double opacity = 0.08,
    Color? tintColor,
    Color? borderColor,
    double borderWidth = 1.0,
  }) {
    final tint = tintColor ?? Colors.white;
    return BoxDecoration(
      color: tint.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: (borderColor ?? Colors.white).withValues(alpha: opacity * 2.5),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: primary.withValues(alpha: 0.06),
          blurRadius: 40,
          spreadRadius: -4,
        ),
      ],
    );
  }

  /// Neon gradient — purple to cyan (primary brand gradient)
  static const LinearGradient neonGradient = LinearGradient(
    colors: [neonPurple, Color(0xFF6366F1), neonCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient neonGradientSubtle = LinearGradient(
    colors: [Color(0x407C3AED), Color(0x406366F1), Color(0x4006B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Premium gradient — 4-color sweep for premium surfaces
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [neonPurple, primary, Color(0xFF6366F1), neonCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Shimmer gradient — for loading shimmer / skeleton effects
  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x18FFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.5, -0.3),
    end: Alignment(1.5, 0.3),
  );

  /// Button gradient — purple to cyan
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Accent gradient — cyan to blue
  static const LinearGradient accentGradient = LinearGradient(
    colors: [neonCyan, neonBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient button builder
  static Widget gradientButton({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
    double height = 52,
    double borderRadius = 14,
    List<Color>? colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors ?? const [Color(0xFF7C3AED), Color(0xFF6366F1)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: (colors?.first ?? primary).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Stat card for gaming stats
  static Widget statBadge(String value, String label, {Color? color}) {
    final c = color ?? neonCyan;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(
          color: c,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        )),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
          color: textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ██  DARK THEME
  // ═══════════════════════════════════════════════════════════

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primary,
      primaryContainer: primaryDark,
      secondary: accent,
      surface: bgCard,
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: bgDark,
    fontFamily: 'Inter',

    // AppBar — transparent blend with background
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primary.withValues(alpha: 0.08)),
      ),
    ),

    // Elevated Buttons — gradient-ready base
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryLight,
        side: BorderSide(color: primary.withValues(alpha: 0.4)),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Text Buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryLight,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input fields — darker with purple accent
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary.withValues(alpha: 0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      labelStyle: const TextStyle(color: textSecondary),
    ),

    // Bottom Nav — deep dark with neon
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF06060F),
      selectedItemColor: primary,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),

    // Tab Bar
    tabBarTheme: TabBarThemeData(
      indicator: BoxDecoration(
        gradient: buttonGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.white,
      unselectedLabelColor: textMuted,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),

    // Text theme — bolder, more impactful
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -1),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      bodySmall: TextStyle(color: textMuted),
    ),

    dividerTheme: DividerThemeData(
      color: primary.withValues(alpha: 0.1),
      thickness: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: bgCard,
      contentTextStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: primary.withValues(alpha: 0.2)),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: primary.withValues(alpha: 0.15)),
      ),
    ),

    // BottomSheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: bgSurface,
      selectedColor: primary.withValues(alpha: 0.2),
      side: BorderSide(color: primary.withValues(alpha: 0.15)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
    ),
  );

  // ═══════════════════════════════════════════════════════════
  // ██  LIGHT THEME
  // ═══════════════════════════════════════════════════════════

  static const Color lightBg = Color(0xFFF8F7FF);         // Softer blue-white, less harsh
  static const Color lightCard = Color(0xFFFFFFFF);        // Pure white
  static const Color lightSurface = Color(0xFFF0EDFF);     // Soft lavender surface
  static const Color lightTextPrimary = Color(0xFF0F0A2E); // Deeper purple-black for better contrast
  static const Color lightTextSecondary = Color(0xFF5B5080); // Richer secondary text
  static const Color lightTextMuted = Color(0xFF9B90C0);   // Adjusted muted
  static const Color lightBorder = Color(0xFFE8E5F5);      // Lavender border

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
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: lightTextPrimary),
    ),

    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 0,
      shadowColor: primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: lightBorder),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        elevation: 2,
        shadowColor: primary.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary.withValues(alpha: 0.4)),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    // Input fields — polished light styling with subtle purple shadows
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: lightTextMuted, fontSize: 14),
      labelStyle: TextStyle(color: lightTextSecondary),
      floatingLabelStyle: const TextStyle(color: primary, fontWeight: FontWeight.w600),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primary,
      unselectedItemColor: lightTextMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
    ),

    // Tab Bar — light
    tabBarTheme: TabBarThemeData(
      indicator: BoxDecoration(
        gradient: buttonGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.white,
      unselectedLabelColor: lightTextMuted,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w800, letterSpacing: -1),
      displayMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: lightTextPrimary),
      bodyMedium: TextStyle(color: lightTextSecondary),
      bodySmall: TextStyle(color: lightTextMuted),
    ),

    dividerTheme: DividerThemeData(color: lightBorder, thickness: 1),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightTextPrimary,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: lightCard,
      shadowColor: primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: lightBorder),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.white,
      shadowColor: primary.withValues(alpha: 0.08),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    // Chip — light
    chipTheme: ChipThemeData(
      backgroundColor: lightSurface,
      selectedColor: primary.withValues(alpha: 0.12),
      side: BorderSide(color: lightBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(color: lightTextSecondary, fontSize: 13),
    ),
  );
}
