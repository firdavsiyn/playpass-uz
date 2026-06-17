import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Minimalist live-graph wave — a thin damped sine line with a lime marker at
/// the tip (glucose-monitor "live graph" reference). Decorative; conveys
/// "live / active" without real data.
class MiniWave extends StatelessWidget {
  final double height;
  final Color color;
  final Color markerColor;

  /// Soft refracted underglow beneath the line (canvas MaskFilter). Gate to
  /// hero usage only.
  final bool glow;

  const MiniWave({
    super.key,
    this.height = 40,
    this.color = AppTheme.softBlue,
    this.markerColor = AppTheme.accent,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(color: color, marker: markerColor, glow: glow),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;
  final Color marker;
  final bool glow;
  _WavePainter({required this.color, required this.marker, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final midY = size.height / 2;
    // Damped sine: amplitude decays toward the right, ending flat at the tip.
    const cycles = 2.4;
    Offset? tip;
    for (double x = 0; x <= size.width; x += 1) {
      final t = x / size.width;
      final amp = (size.height * 0.42) * (1 - t * 0.85);
      final y = midY - amp * math.sin(t * cycles * 2 * math.pi);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      tip = Offset(x, y);
    }
    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    if (tip != null) {
      // lime tip marker (triangle-ish dot)
      canvas.drawCircle(tip, 3.5, Paint()..color = marker);
      canvas.drawCircle(
          tip, 6, Paint()..color = marker.withValues(alpha: 0.25));
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.color != color || old.marker != marker || old.glow != glow;
}
