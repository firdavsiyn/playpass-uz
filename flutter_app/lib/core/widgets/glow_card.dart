import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bento-grid card with a soft aurora glow inside (glucose-monitor reference,
/// kept in the navy + lime palette). Dark navy base, a radial glow from a
/// focal point, hairline border, rounded 22.
class GlowCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double height;
  final EdgeInsets padding;

  /// Focal point of the glow (0,0 = top-left … 1,1 = bottom-right).
  final Alignment glowAt;
  final VoidCallback? onTap;

  const GlowCard({
    super.key,
    required this.child,
    this.glowColor = AppTheme.primary,
    this.height = 0,
    this.padding = const EdgeInsets.all(16),
    this.glowAt = const Alignment(0.6, 0.2),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: height > 0 ? height : null,
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.border),
        ),
        child: Stack(
          children: [
            // Aurora glow
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: glowAt,
                    radius: 0.95,
                    colors: [
                      glowColor.withValues(alpha: 0.38),
                      glowColor.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Small label used at the top of a glow card.
class GlowCardLabel extends StatelessWidget {
  final String text;
  const GlowCardLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: context.text2,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
}
