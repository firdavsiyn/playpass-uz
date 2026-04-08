import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Neon-styled shimmer loading effect for skeleton loaders.
/// Wraps any child with an animated purple-to-cyan gradient sweep.
class NeonShimmer extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final Duration duration;

  const NeonShimmer({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.duration = const Duration(milliseconds: 1500),
  });

  /// Quick rectangular shimmer block
  factory NeonShimmer.block({
    double width = double.infinity,
    double height = 60,
    double borderRadius = 14,
  }) => NeonShimmer(
    borderRadius: borderRadius,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
  );

  /// Quick circular shimmer
  factory NeonShimmer.circle({double size = 48}) => NeonShimmer(
    borderRadius: size / 2,
    child: Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        shape: BoxShape.circle,
      ),
    ),
  );

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-0.5 + 2.0 * _controller.value, 0),
              colors: const [
                Color(0x00000000),
                Color(0x337C3AED),
                Color(0x2206B6D4),
                Color(0x00000000),
              ],
              stops: const [0.0, 0.4, 0.6, 1.0],
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

/// A skeleton card matching the gaming card style with shimmer
class NeonSkeletonCard extends StatelessWidget {
  final double height;
  final double borderRadius;

  const NeonSkeletonCard({
    super.key,
    this.height = 100,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return NeonShimmer(
      borderRadius: borderRadius,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}
