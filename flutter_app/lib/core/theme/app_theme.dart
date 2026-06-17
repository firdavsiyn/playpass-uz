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
  Color get text2 =>
      isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
  Color get text3 => isDark ? AppTheme.textMuted : AppTheme.lightTextMuted;

  // Borders (navy-tinted on dark)
  Color get border => isDark ? const Color(0xFF22304F) : AppTheme.lightBorder;
  Color get borderSubtle =>
      isDark ? const Color(0xFF161F36) : const Color(0xFFE3ECFA);

  // Glass (legacy micro-tints — still used for icon-chip overlays)
  Color get glass => isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000);
  Color get glassStrong =>
      isDark ? const Color(0x28FFFFFF) : const Color(0x18000000);

  // ── Liquid Glass tokens (navy frost; never hardcoded white/black bodies
  //    so light mode holds) ──────────────────────────────────────────────
  /// Fake-glass body (no real blur). Higher alpha hides the lack of refraction.
  Color get glassFill => isDark
      ? AppTheme.bgCard.withValues(alpha: 0.62)
      : AppTheme.lightCard.withValues(alpha: 0.70);

  /// Stronger fill for in-scroll tiles / dense rows so they read solid.
  Color get glassFillStrong => isDark
      ? AppTheme.bgCard.withValues(alpha: 0.78)
      : AppTheme.lightCard.withValues(alpha: 0.86);

  /// Lower-alpha body used BEHIND a real BackdropFilter (blur supplies body).
  Color get glassFillReal => isDark
      ? AppTheme.bgCard.withValues(alpha: 0.50)
      : AppTheme.lightCard.withValues(alpha: 0.60);

  /// Top specular sheen start color (wet-glass highlight).
  Color get glassSheen => isDark
      ? Colors.white.withValues(alpha: 0.15)
      : Colors.white.withValues(alpha: 0.30);

  /// Bright rim / lensing edge stop (soft-blue on dark, white on light).
  Color get glassRim =>
      isDark ? const Color(0x59BBD9FF) : const Color(0x73FFFFFF);

  /// Background aurora blob colors (a: top-right, b: bottom-left, c: warm edge).
  ({Color a, Color b, Color c}) get glassBlobs => isDark
      ? (
          a: AppTheme.primaryDark.withValues(alpha: 0.22),
          b: AppTheme.indigo.withValues(alpha: 0.16),
          c: AppTheme.accent.withValues(alpha: 0.05),
        )
      : (
          a: AppTheme.primary.withValues(alpha: 0.06),
          b: AppTheme.indigo.withValues(alpha: 0.05),
          c: Colors.transparent,
        );

  // Nav bar bg (deep navy)
  Color get navBg => isDark ? const Color(0xFF0A1120) : Colors.white;

  // Frozen subscription state (replaces Colors.blueGrey literals)
  Color get frozen =>
      isDark ? const Color(0xFF78909C) : const Color(0xFF546E7A);
  Color get frozenBg => frozen.withValues(alpha: 0.15);
}

class AppTheme {
  // ══════════════════════════════════════════════════════════
  // ██ REBRAND v2 — Navy + Electric Lime (refs: DriveX/cocktail)
  // Palette: royal blue #004797 · lime #E6F945 · soft blue #BBD9FF · white.
  // Token NAMES preserved so screens inherit the new look automatically.
  // ══════════════════════════════════════════════════════════

  // ── Brand Colors ────────────────────────────────────────
  static const Color primary =
      Color(0xFF2E6FE0); // Royal blue (readable on dark)
  static const Color primaryLight = Color(0xFF6FA3F5);
  static const Color primaryDark = Color(0xFF004797); // Brand royal-blue swatch
  static const Color accent =
      Color(0xFFE6F945); // ⚡ Electric lime — CTAs/highlights
  static const Color softBlue =
      Color(0xFFBBD9FF); // Soft blue — chips/secondary

  // Glow / gradient stops (names kept; remapped to navy-blue family)
  static const Color neonPurple = Color(0xFF2E6FE0); // → royal blue
  static const Color neonBlue = Color(0xFF3D7BD9);
  static const Color neonCyan = Color(0xFF4D8DF0); // gradient end (bright blue)
  static const Color neonPink = Color(0xFFE6F945); // → lime (favourites accent)
  static const Color neonGreen = Color(0xFF10B981);
  static const Color neonMagenta = Color(0xFFE6F945); // alias → lime
  static const Color neonLavender = Color(0xFFBBD9FF); // → soft blue

  // ── Background (dark theme, deep navy) ──────────────────
  static const Color bgDark = Color(0xFF070C18); // Deep navy-black
  static const Color bgCard = Color(0xFF0E1626); // Navy card
  static const Color bgCardDeep = Color(0xFF0A111E); // Darker navy card
  static const Color bgSurface = Color(0xFF16203A); // Elevated navy surface
  static const Color bgGlass = Color(0x0EFFFFFF); // Glass overlay

  // ── Text ────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure white
  static const Color textSecondary = Color(0xFF9FB2D0); // Muted blue-grey
  static const Color textMuted = Color(0xFF5A6B8C); // Deep muted blue-grey

  // ── Status Colors ───────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF2E6FE0);

  // ── Tier Colors ─────────────────────────────────────────
  static const Color tierVip = Color(0xFFE6F945); // lime = top tier
  static const Color tierPro = Color(0xFF2E6FE0);
  static const Color tierStandard = Color(0xFFBBD9FF);

  // ── Medal / Loyalty Tier Colors ─────────────────────────
  static const Color medalGold = Color(0xFFFFD700);
  static const Color medalSilver = Color(0xFFC0C0C0);
  static const Color medalBronze = Color(0xFFCD7F32);
  static const Color tierDiamond = Color(0xFF00CED1);

  // Mid-stop for blue gradients (kept name 'indigo' for call-site compat).
  static const Color indigo = Color(0xFF1E5BC6);

  // ── Brand One-offs ──────────────────────────────────────
  static const Color telegram =
      Color(0xFF2AABEE); // Telegram brand (club_detail, profile)
  static const Color streakFlame = Color(0xFFFF6B35); // streak widget flame
  static const Color streakFlameLight =
      Color(0xFFFFB627); // streak flame gradient end

  /// Canonical plan → tier color mapping (single source of truth).
  /// Replaces the duplicated switch in my_subscription / plans / gift_purchase.
  static Color planColor(String id) => switch (id) {
        'vip' => tierVip,
        'pro' => tierPro,
        'standard' => tierStandard,
        _ => const Color(0xFF6B7280),
      };

  // ── Neon Glow Utilities ─────────────────────────────────

  /// Primary neon glow shadow
  static List<BoxShadow> neonGlow(
          {Color? color, double radius = 20, double spread = 0}) =>
      [
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
  @Deprecated('Use GlassSurface + context.glassFill for liquid-glass surfaces')
  static BoxDecoration glassDecoration({
    double borderRadius = 16,
    Color? glowColor,
    double borderOpacity = 0.2,
  }) =>
      BoxDecoration(
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
  @Deprecated('Use GlassSurface + context.glassFill for liquid-glass surfaces')
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

  /// Brand gradient — navy → royal blue
  static const LinearGradient neonGradient = LinearGradient(
    colors: [primaryDark, indigo, neonCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient neonGradientSubtle = LinearGradient(
    colors: [Color(0x40004797), Color(0x401E5BC6), Color(0x404D8DF0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Premium gradient — navy → blue sweep for premium surfaces
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [primaryDark, primary, indigo, neonCyan],
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

  /// Button gradient — navy → royal blue (used for tab indicator etc.)
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [primaryDark, primary],
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
            colors: colors ?? const [primaryDark, primary],
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
        Text(value,
            style: TextStyle(
              color: c,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
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
        fontFamily: 'Poppins',

        // AppBar — transparent blend with background
        appBarTheme: const AppBarTheme(
          backgroundColor: bgDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'SpaceGrotesk',
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
        // Primary CTA = electric lime with dark text (signature look).
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: const Color(0xFF0A1120),
            minimumSize: const Size(double.infinity, 54),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
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
              fontFamily: 'Poppins',
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
              fontFamily: 'Poppins',
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          selectedLabelStyle:
              TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
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
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),

        // Text theme — bolder, more impactful
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -1),
          displayMedium: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          headlineLarge: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          headlineMedium: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: textPrimary,
              fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: textPrimary,
              fontWeight: FontWeight.w700),
          titleLarge: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3),
          titleMedium:
              TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        ),
      );

  // ═══════════════════════════════════════════════════════════
  // ██  LIGHT THEME
  // ═══════════════════════════════════════════════════════════

  static const Color lightBg =
      Color(0xFFF8F7FF); // Softer blue-white, less harsh
  static const Color lightCard = Color(0xFFFFFFFF); // Pure white
  static const Color lightSurface = Color(0xFFF0EDFF); // Soft lavender surface
  static const Color lightTextPrimary =
      Color(0xFF0F0A2E); // Deeper purple-black for better contrast
  static const Color lightTextSecondary =
      Color(0xFF5B5080); // Richer secondary text
  static const Color lightTextMuted = Color(0xFF9B90C0); // Adjusted muted
  static const Color lightBorder = Color(0xFFE8E5F5); // Lavender border

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
        fontFamily: 'Poppins',

        appBarTheme: const AppBarTheme(
          backgroundColor: lightBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'SpaceGrotesk',
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
            backgroundColor: accent,
            foregroundColor: const Color(0xFF0A1120),
            minimumSize: const Size(double.infinity, 54),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary.withValues(alpha: 0.4)),
            minimumSize: const Size(double.infinity, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: TextStyle(color: lightTextMuted, fontSize: 14),
          labelStyle: TextStyle(color: lightTextSecondary),
          floatingLabelStyle:
              const TextStyle(color: primary, fontWeight: FontWeight.w600),
        ),

        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: primary,
          unselectedItemColor: lightTextMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
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
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),

        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: lightTextPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -1),
          displayMedium: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: lightTextPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          headlineLarge: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: lightTextPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          headlineMedium: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: lightTextPrimary,
              fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: lightTextPrimary,
              fontWeight: FontWeight.w700),
          titleLarge: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: lightTextPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3),
          titleMedium:
              TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: lightTextPrimary),
          bodyMedium: TextStyle(color: lightTextSecondary),
          bodySmall: TextStyle(color: lightTextMuted),
        ),

        dividerTheme: DividerThemeData(color: lightBorder, thickness: 1),

        snackBarTheme: SnackBarThemeData(
          backgroundColor: lightTextPrimary,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          labelStyle: TextStyle(color: lightTextSecondary, fontSize: 13),
        ),
      );
}
