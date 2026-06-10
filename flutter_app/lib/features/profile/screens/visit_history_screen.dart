import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/visit.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/widgets/empty_state.dart';

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// ── Paginated visit history ───────────────────────────────
class VisitHistoryState {
  final List<Visit> visits;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const VisitHistoryState({
    this.visits = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  VisitHistoryState copyWith({
    List<Visit>? visits,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) =>
      VisitHistoryState(
        visits: visits ?? this.visits,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        error: error,
      );
}

class VisitHistoryNotifier extends StateNotifier<VisitHistoryState> {
  VisitHistoryNotifier() : super(const VisitHistoryState());

  static const _pageSize = 20;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void setMonth(DateTime month) {
    _month = month;
    refresh();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final newVisits = await SupabaseService().getVisitHistory(
        month: _month.month,
        year: _month.year,
        limit: _pageSize,
        offset: state.visits.length,
      );
      state = state.copyWith(
        visits: [...state.visits, ...newVisits],
        isLoading: false,
        hasMore: newVisits.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = const VisitHistoryState();
    await loadMore();
  }
}

final visitHistoryProvider =
    StateNotifierProvider<VisitHistoryNotifier, VisitHistoryState>(
  (ref) {
    final notifier = VisitHistoryNotifier();
    notifier.loadMore();
    return notifier;
  },
);

final allTimeStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    return await SupabaseService().getAllTimeVisitStats();
  } catch (_) {
    return {'total_visits': 0, 'total_hours': 0, 'favorite_club': null};
  }
});

class VisitHistoryScreen extends ConsumerStatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  ConsumerState<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends ConsumerState<VisitHistoryScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(visitHistoryProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final historyState = ref.watch(visitHistoryProvider);
    final statsAsync = ref.watch(allTimeStatsProvider);
    final monthFmt = DateFormat('MMMM yyyy', 'ru');

    // Sync notifier month when the selected month changes.
    ref.listen<DateTime>(selectedMonthProvider, (prev, next) {
      ref.read(visitHistoryProvider.notifier).setMonth(next);
    });

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        title: Text(ref.lang('visits.title')),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(visitHistoryProvider.notifier).refresh();
          ref.invalidate(allTimeStatsProvider);
        },
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
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
                  icon: Icon(Icons.chevron_left_rounded, color: context.text1),
                  onPressed: () {
                    final prev =
                        DateTime(selectedMonth.year, selectedMonth.month - 1);
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
                  icon: Icon(Icons.chevron_right_rounded, color: context.text1),
                  onPressed: selectedMonth.month < DateTime.now().month ||
                          selectedMonth.year < DateTime.now().year
                      ? () {
                          final next = DateTime(
                              selectedMonth.year, selectedMonth.month + 1);
                          ref.read(selectedMonthProvider.notifier).state = next;
                        }
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Monthly summary + list ──
            if (historyState.visits.isEmpty &&
                historyState.isLoading &&
                historyState.error == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (historyState.error != null && historyState.visits.isEmpty)
              Center(
                child: Text(
                    '${ref.lang('common.error_prefix')}: ${historyState.error}',
                    style: const TextStyle(color: AppTheme.error)),
              )
            else ...[
              _MonthlySummary(visits: historyState.visits),
              const SizedBox(height: 12),
              if (historyState.visits.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: ref.lang('visits.empty_month'),
                    subtitle: 'Отсканируй QR в любом клубе из 276 — визит появится здесь',
                    accentColor: AppTheme.neonCyan,
                  ),
                )
              else
                ...historyState.visits.map((v) => Padding(
                      key: ValueKey(v.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _VisitRow(visit: v),
                    )),

              // ── Pagination footer ──
              if (historyState.isLoading && historyState.visits.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!historyState.hasMore && historyState.visits.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      ref.lang('visits.all_loaded'),
                      style: TextStyle(color: context.text3, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── All-time stats ─────────────────────────────────────────

class _AllTimeStats extends ConsumerWidget {
  final Map<String, dynamic> stats;
  const _AllTimeStats({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                label: ref.lang('visits.total_visits'),
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.timer_rounded,
                value: '$totalHours ч',
                label: ref.lang('visits.total_hours'),
                color: AppTheme.neonPurple,
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
                  color: AppTheme.warning.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.warning.withValues(alpha: 0.1),
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
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: AppTheme.warning, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.lang('visits.fav_club'),
                        style: const TextStyle(
                            color: AppTheme.warning,
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
                        style: TextStyle(color: context.text3, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${favoriteClub['count']}',
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      ref.lang('visits.visits_word'),
                      style: TextStyle(color: context.text3, fontSize: 11),
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
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.08)
                ],
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
              Text(label, style: TextStyle(color: context.text3, fontSize: 11)),
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
    final totalHours = visits.fold(0, (sum, v) => sum + v.hoursSpent);
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
          Container(width: 1, height: 32, color: context.border),
          _StatItem(label: 'Часов', value: '$totalHours'),
          Container(width: 1, height: 32, color: context.border),
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
        Text(label, style: TextStyle(color: context.text3, fontSize: 12)),
      ],
    );
  }
}

// ── Visit row ──────────────────────────────────────────────

class _VisitRow extends StatelessWidget {
  final Visit visit;
  const _VisitRow({required this.visit});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM · HH:mm', 'ru');

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
                  dateFmt.format(visit.createdAt),
                  style: TextStyle(color: context.text3, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${visit.hoursSpent} ч',
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
