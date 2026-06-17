import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Static aurora mesh painted behind the body so frosted surfaces have navy
/// light to lens. Two large RadialGradient blobs + a tiny warm edge (dark
/// only). NOT animated, NOT blurred — a gradient is already 'pre-blurred', so
/// this is free compositor work. Without it, a real blur over flat #070C18
/// reads as a grey film instead of frosted navy.
class GlassBackdrop extends StatelessWidget {
  final Widget child;
  const GlassBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final blobs = context.glassBlobs;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: context.bg),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.9, -0.8),
                radius: 0.85,
                colors: [blobs.a, Colors.transparent],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.9, 0.9),
                radius: 0.95,
                colors: [blobs.b, Colors.transparent],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(1.1, 1.1),
                radius: 0.4,
                colors: [blobs.c, Colors.transparent],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
