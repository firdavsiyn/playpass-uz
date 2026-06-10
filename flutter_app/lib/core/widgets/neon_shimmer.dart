import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Soft, theme-aware shimmer loading effect for skeleton loaders.
///
/// Design notes:
///  - The base fill is theme-aware (`context.surface`) so skeletons are
///    LIGHT on the light theme and DARK on the dark theme — never a black
///    hole on a white screen.
///  - The sweep is a NEUTRAL highlight (soft white), not a neon rainbow.
///    A purple→cyan sweep reads as a harsh colored bar; a neutral one
///    reads as a calm "loading" pulse, like every polished app.
class NeonShimmer extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final Duration duration;

  const NeonShimmer({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.duration = const Duration(milliseconds: 1400),
  });

  /// Quick rectangular shimmer block. Theme-aware fill via Builder.
  factory NeonShimmer.block({
    double width = double.infinity,
    double height = 60,
    double borderRadius = 14,
    Color? fillColor,
  }) {
    return NeonShimmer(
      borderRadius: borderRadius,
      child: Builder(
        builder: (ctx) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: fillColor ?? ctx.surface,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }

  /// Quick circular shimmer.
  factory NeonShimmer.circle({double size = 48, Color? fillColor}) {
    return NeonShimmer(
      borderRadius: size / 2,
      child: Builder(
        builder: (ctx) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fillColor ?? ctx.surface,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  State<NeonShimmer> createState() => _NeonShimmerState();
}

class _NeonShimmerState extends State<NeonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Neutral highlight, intensity tuned per theme. On dark surfaces a
    // brighter white reads well; on light surfaces a softer one avoids glare.
    final highlight = context.isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.65);

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-0.3 + 2.0 * _controller.value, 0),
              colors: [
                const Color(0x00FFFFFF),
                highlight,
                const Color(0x00FFFFFF),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A skeleton card with a soft, theme-aware shimmer.
class NeonSkeletonCard extends StatelessWidget {
  final double height;
  final double borderRadius;
  final Color? fillColor;

  const NeonSkeletonCard({
    super.key,
    this.height = 100,
    this.borderRadius = 16,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    // Default fill is theme-aware — never a hardcoded dark color.
    final fill = fillColor ?? context.surface;
    return NeonShimmer(
      borderRadius: borderRadius,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: context.borderSubtle),
        ),
      ),
    );
  }
}
