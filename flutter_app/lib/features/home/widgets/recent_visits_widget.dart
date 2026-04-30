import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        if (visits.isEmpty) return const _NoVisitsCard();
        return Column(
          children: visits
              .map((v) => _VisitTile(key: ValueKey(v.id), visit: v))
              .toList(),
        );
      },
      loading: () => Column(
        children: List.generate(3, (_) => const _VisitTileSkeleton()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Friendly empty state with QR-scan CTA — only shown when user has 0 visits
class _NoVisitsCard extends StatelessWidget {
  const _NoVisitsCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.go('/scanner');
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withValues(alpha: 0.10),
              AppTheme.neonCyan.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppTheme.primary.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.neonCyan],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Визитов ещё нет',
                      style: TextStyle(
                        color: context.text1,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 2),
                  Text('Отсканируй QR в клубе и получи 1-й визит',
                      style:
                          TextStyle(color: context.text3, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.primary.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final Visit visit;
  const _VisitTile({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM, HH:mm', 'ru').format(visit.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border.withValues(alpha: 0.3)),
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sports_esports,
                color: AppTheme.primaryLight, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.clubName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.text1,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(color: context.text3, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
            ),
            child: Text(
              '${visit.hoursSpent}ч',
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
        color: context.card,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
