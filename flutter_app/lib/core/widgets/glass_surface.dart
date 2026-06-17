import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable liquid-glass surface. Navy frost body + specular sheen + lensing
/// rim + contact shadow. `real:true` adds the ONE budgeted BackdropFilter;
/// `real:false` (default) is single-pass fake glass — safe in scroll views.
///
/// Perf contract: at most ONE real BackdropFilter on screen at any instant
/// (owned by the bottom nav by default; a modal sheet may borrow it since the
/// nav is occluded). Callers that pass `real:true` MUST wrap this in their own
/// RepaintBoundary. Never put a `real:true` surface inside a scrolling list.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final BorderRadius? customRadius;
  final EdgeInsets padding;
  final double? height;
  final bool real;
  final bool strong;
  final double? blurSigma;
  final Color? glowColor;
  final Alignment? glowAt;
  final VoidCallback? onTap;

  /// Overrides the structural hairline color (default: context.border). Use for
  /// per-category accent tints (e.g. quick-action tiles).
  final Color? borderColor;

  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 22,
    this.customRadius,
    this.padding = const EdgeInsets.all(16),
    this.height,
    this.real = false,
    this.strong = false,
    this.blurSigma,
    this.glowColor,
    this.glowAt,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final br = customRadius ?? BorderRadius.circular(radius);
    final isDark = context.isDark;
    final fill = strong
        ? context.glassFillStrong
        : (real ? context.glassFillReal : context.glassFill);
    // Light content has more luminance variance → needs more diffusion.
    final sigma = blurSigma ?? (isDark ? 16.0 : 18.0);

    final stackChildren = <Widget>[
      if (real)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
            child: const SizedBox.expand(),
          ),
        ),
      // Tint body + structural hairline.
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: borderColor ?? context.border, width: 1),
            borderRadius: br,
          ),
        ),
      ),
      // Aurora glow trapped inside the frost (optional).
      if (glowColor != null)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: br,
              gradient: RadialGradient(
                center: glowAt ?? const Alignment(0.6, 0.2),
                radius: 0.95,
                colors: [
                  glowColor!.withValues(alpha: 0.34),
                  glowColor!.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      // Top specular sheen ("wet glass" highlight).
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: radius * 1.9,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.glassSheen,
                  context.glassSheen.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      // Lensing rim highlight (top-left → transparent).
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _RimPainter(br, context.glassRim)),
        ),
      ),
      // Content — always crisp, never inside blur/sheen.
      Padding(padding: padding, child: child),
    ];

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.10),
              blurRadius: 40,
              spreadRadius: -6,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.passthrough, children: stackChildren),
      ),
    );

    if (height != null) {
      surface = SizedBox(height: height, child: surface);
    }
    if (onTap != null) {
      surface = GestureDetector(onTap: onTap, child: surface);
    }
    return surface;
  }
}

/// 1.2px gradient stroke that lenses the top-left corner (light → transparent).
class _RimPainter extends CustomPainter {
  final BorderRadius radius;
  final Color rim;
  _RimPainter(this.radius, this.rim);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(0.6);
    final rrect = radius.toRRect(inset);
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        rim,
        rim.withValues(alpha: rim.a * 0.30),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(rect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = shader;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _RimPainter old) =>
      old.rim != rim || old.radius != radius;
}
