import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/visit.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final visitHistoryProvider =
    FutureProvider.family<List<Visit>, DateTime>((ref, month) async {
  return SupabaseService()
      .getVisitHistory(month: month.month, year: month.year);
});

final allTimeStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    return await SupabaseService().getAllTimeVisitStats();
  } catch (_) {
    return {'total_visits': 0, 'total_hours': 0, 'favorite_club': null};
  }
});

class VisitHistoryScreen extends ConsumerWidget {
  const VisitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final visitsAsync = ref.watch(visitHistoryProvider(selectedMonth));
    final statsAsync = ref.watch(allTimeStatsProvider);
    final monthFmt = DateFormat('MMMM yyyy', 'ru');

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        title: const Text('История визитов'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(visitHistoryProvider(selectedMonth));
          ref.invalidate(allTimeStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // ── All-time stats ──
            statsAsync.when(
              data: (stats) => _AllTimeStats(stats: stats),
              loading: () => const SizedBox(height: 4),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // ── Month selector ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded,
                      color: context.text1),
                  onPressed: () {
                    final prev = DateTime(
                        selectedMonth.year, selectedMonth.month - 1);
                    ref.read(selectedMonthProvider.notifier).state = prev;
                  },
                ),
                Text(
                  monthFmt.format(selectedMonth),
                  style: TextStyle(
                    color: context.text1,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded,
                      color: context.text1),
                  onPressed: selectedMonth.month < DateTime.now().month ||
                          selectedMonth.year < DateTime.now().year
                      ? () {
                          final next = DateTime(
                              selectedMonth.year, selectedMonth.month + 1);
                          ref.read(selectedMonthProvider.notifier).state =
                              next;
                        }
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Monthly summary + list ──
            visitsAsync.when(
              data: (visits) => Column(
                children: [
                  _MonthlySummary(visits: visits),
                  const SizedBox(height: 12),
                  if (visits.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'В этом месяце визитов нет',
                          style: TextStyle(color: context.text3),
                        ),
                      ),
                    )
                  else
                    ...visits.map((v) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _VisitRow(visit: v),
                        )),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Text('Ошибка: $e',
                    style: const TextStyle(color: AppTheme.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── All-time stats ─────────────────────────────────────────

class _AllTimeStats extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _AllTimeStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalVisits = stats['total_visits'] as int? ?? 0;
    final totalHours = stats['total_hours'] as int? ?? 0;
    final favoriteClub = stats['favorite_club'] as Map<String, dynamic>?;

    return Column(
      children: [
        // Overall stats row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_today_rounded,
                value: '$totalVisits',
                label: 'Всего визитов',
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.timer_rounded,
                value: '$totalHours ч',
                label: 'Всего часов',
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),

        // Favorite club
        if (favoriteClub != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: Color(0xFFF59E0B), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Любимый клуб',
                        style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        favoriteClub['name'] as String? ?? '',
                        style: TextStyle(
                          color: context.text1,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        favoriteClub['address'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.text3, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${favoriteClub['count']}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      'визитов',
                      style: TextStyle(
                          color: context.text3, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                    color: context.text1,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  )),
              Text(label,
                  style: TextStyle(
                      color: context.text3, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Monthly summary ────────────────────────────────────────

class _MonthlySummary extends StatelessWidget {
  final List<Visit> visits;
  const _MonthlySummary({required this.visits});

  @override
  Widget build(BuildContext context) {
    final totalHours =
        visits.fold(0, (sum, v) => sum + v.hoursDeducted);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
        boxShadow: AppTheme.cardGlow(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'Визитов', value: '${visits.length}'),
          Container(
              width: 1, height: 32, color: context.border),
          _StatItem(label: 'Часов', value: '$totalHours'),
          Container(
              width: 1, height: 32, color: context.border),
          _StatItem(
            label: 'Клубов',
            value: '${visits.map((v) => v.clubId).toSet().length}',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: context.text1,
                fontWeight: FontWeight.w700,
                fontSize: 22)),
        const SizedBox(height: 2),
        Text(label,
            style:
                TextStyle(color: context.text3, fontSize: 12)),
      ],
    );
  }
}

// ── Visit row ──────────────────────────────────────────────

class _VisitRow extends StatelessWidget {
  final Visit visit;
  const _VisitRow({required this.visit});

  Color _zoneBadgeColor(BuildContext context) {
    switch (visit.zoneType) {
      case 'pro':
        return AppTheme.info;
      case 'vip':
        return const Color(0xFFF59E0B);
      default:
        return context.text3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM · HH:mm', 'ru');
    final zoneColor = _zoneBadgeColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.15),
                  AppTheme.neonPurple.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sports_esports,
                color: AppTheme.primaryLight, size: 22),
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
                        style: TextStyle(
                          color: context.text1,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: zoneColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        visit.zoneLabel,
                        style: TextStyle(
                          color: zoneColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${dateFmt.format(visit.createdAt)}  ·  ${visit.timeSlotLabel}',
                  style: TextStyle(
                      color: context.text3, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${visit.hoursDeducted} ч',
              style: const TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
