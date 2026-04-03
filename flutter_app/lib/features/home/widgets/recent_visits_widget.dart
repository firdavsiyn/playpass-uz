import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/visit.dart';
import '../../../core/theme/app_theme.dart';

class RecentVisitsWidget extends StatelessWidget {
  final AsyncValue<List<Visit>> visitsAsync;
  const RecentVisitsWidget({super.key, required this.visitsAsync});

  @override
  Widget build(BuildContext context) {
    return visitsAsync.when(
      data: (visits) {
        if (visits.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Визитов ещё нет. Сканируйте QR в клубе!',
                style: TextStyle(color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Column(
          children: visits.map((v) => _VisitTile(visit: v)).toList(),
        );
      },
      loading: () => Column(
        children: List.generate(3, (_) => const _VisitTileSkeleton()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final Visit visit;
  const _VisitTile({required this.visit});

  Color get _zoneBadgeColor => switch (visit.zoneType) {
    'pro' => const Color(0xFF3B82F6),
    'vip' => const Color(0xFFF59E0B),
    _ => AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM, HH:mm', 'ru').format(visit.createdAt);
    final zoneColor = _zoneBadgeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.06)),
        boxShadow: AppTheme.cardGlow(),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.2),
                  AppTheme.neonPurple.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.sports_esports, color: AppTheme.primaryLight, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        visit.clubName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: zoneColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        visit.zoneLabel,
                        style: TextStyle(color: zoneColor, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr · ${visit.timeSlotLabel}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '-${visit.hoursDeducted}ч',
              style: const TextStyle(
                color: AppTheme.success,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitTileSkeleton extends StatelessWidget {
  const _VisitTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
