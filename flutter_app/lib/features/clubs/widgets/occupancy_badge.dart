import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class OccupancyBadge extends StatelessWidget {
  final int current;
  final int capacity;
  final bool compact;

  const OccupancyBadge({
    super.key,
    required this.current,
    required this.capacity,
    this.compact = false,
  });

  double get _ratio => capacity > 0 ? (current / capacity).clamp(0.0, 1.0) : 0;

  Color get _color {
    if (_ratio < 0.5) return AppTheme.success;
    if (_ratio < 0.8) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_rounded, size: 10, color: _color),
            const SizedBox(width: 3),
            Text(
              '$current/$capacity',
              style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_rounded, size: 16, color: _color),
          const SizedBox(width: 6),
          Text(
            '$current / $capacity',
            style: TextStyle(
              color: _color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _ratio,
                backgroundColor: context.surface,
                valueColor: AlwaysStoppedAnimation(_color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
