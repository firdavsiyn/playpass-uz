import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Personalized recommendation card on the home screen.
/// Backed by the DB function `get_home_recommendations()` — returns 0-N
/// cards based on user history, time of day, subscription state.
class SmartHintCard extends ConsumerWidget {
  final Map<String, dynamic> hint;
  const SmartHintCard({super.key, required this.hint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = hint['type'] as String? ?? 'unknown';
    final title = hint['title'] as String? ?? '';
    final subtitle = hint['subtitle'] as String? ?? '';
    final action = hint['action'] as String?;

    final colors = _gradientFor(type);
    final iconData = _iconFor(type);

    return GestureDetector(
      onTap: action != null
          ? () {
              HapticFeedback.lightImpact();
              context.push(action);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.$1.withValues(alpha: 0.15),
              colors.$2.withValues(alpha: 0.06)
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.$1.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colors.$1, colors.$2]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: colors.$1.withValues(alpha: 0.4), blurRadius: 10),
                ],
              ),
              child: Icon(iconData, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.text1,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: context.text2, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (action != null)
              Icon(Icons.chevron_right_rounded,
                  color: colors.$1.withValues(alpha: 0.7), size: 22),
          ],
        ),
      ),
    );
  }

  /// (gradient start, gradient end) for each hint type
  (Color, Color) _gradientFor(String type) {
    switch (type) {
      case 'favorite_club':
        return (AppTheme.neonPink, AppTheme.primary);
      case 'comeback':
        return (AppTheme.warning, AppTheme.neonCyan);
      case 'time_suggest':
        return (AppTheme.primary, AppTheme.neonCyan);
      case 'expiring':
        return (AppTheme.error, AppTheme.warning);
      default:
        return (AppTheme.primary, AppTheme.neonCyan);
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'favorite_club':
        return Icons.favorite_rounded;
      case 'comeback':
        return Icons.waving_hand_rounded;
      case 'time_suggest':
        return Icons.nightlight_rounded;
      case 'expiring':
        return Icons.timer_rounded;
      default:
        return Icons.lightbulb_outline_rounded;
    }
  }
}
