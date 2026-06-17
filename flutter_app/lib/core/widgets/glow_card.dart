import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// Bento-grid card with a soft aurora glow inside (glucose-monitor reference,
/// kept in the navy + lime palette). Dark navy base, a radial glow from a
/// focal point, hairline border, rounded 22.
///
/// Set [glass]:true to render as a liquid-glass surface (frosted body +
/// specular sheen + lensing rim) via [GlassSurface], keeping the same aurora
/// glow trapped inside the frost. The opaque default ([glass]:false) is
/// unchanged for existing callers.
class GlowCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double height;
  final EdgeInsets padding;

  /// Focal point of the glow (0,0 = top-left … 1,1 = bottom-right).
  final Alignment glowAt;
  final VoidCallback? onTap;

  /// Render as frosted liquid glass instead of an opaque card.
  final bool glass;

  /// Only meaningful when [glass]. Adds the one budgeted real BackdropFilter —
  /// never use inside a scrolling list.
  final bool real;

  /// Only meaningful when [glass]. Uses the stronger fill so the card reads
  /// solid inside a scroll view.
  final bool strong;

  const GlowCard({
    super.key,
    required this.child,
    this.glowColor = AppTheme.primary,
    this.height = 0,
    this.padding = const EdgeInsets.all(16),
    this.glowAt = const Alignment(0.6, 0.2),
    this.onTap,
    this.glass = false,
    this.real = false,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    if (glass) {
      return GlassSurface(
        radius: 22,
        padding: padding,
        height: height > 0 ? height : null,
        glowColor: glowColor,
        glowAt: glowAt,
        onTap: onTap,
        real: real,
        strong: strong,
        child: child,
      );
    }

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
