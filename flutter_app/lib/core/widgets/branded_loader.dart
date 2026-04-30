import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand-styled loading indicator with the purple→cyan gradient ring.
/// Drop-in replacement for [CircularProgressIndicator] when consistency
/// with the app theme matters more than platform conventions.
class BrandedLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final String? label;

  const BrandedLoader({
    super.key,
    this.size = 38,
    this.strokeWidth = 3.0,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _GradientArcPainter(strokeWidth: strokeWidth),
              child: const _Spinner(),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(
              label!,
              style: TextStyle(
                color: context.text3,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner();
  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Transform.rotate(
          angle: _ctrl.value * 6.283,
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _GradientArcPainter extends CustomPainter {
  final double strokeWidth;
  const _GradientArcPainter({required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Animated gradient arc — drawn on top using SweepGradient
    // The rotation comes from the parent _Spinner's Transform.
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: const [
          AppTheme.primary,
          AppTheme.primary,
          AppTheme.neonCyan,
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, arcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
