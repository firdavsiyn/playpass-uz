import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/subscription.dart';
import '../../../models/visit.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/utils/savings_calculator.dart';

/// All visits of the user (no month filter) for savings computation
final _allVisitsProvider = FutureProvider.autoDispose<List<Visit>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  final data = await Supabase.instance.client
      .from('visits')
      .select('id, user_id, club_id, hours_spent, created_at, clubs(name)')
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(500);
  return (data as List)
      .map((e) => Visit.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Active subscription (reuse from home)
final _savingsSubProvider =
    FutureProvider.autoDispose<Subscription?>((ref) async {
  return SupabaseService().getActiveSubscription();
});

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(_allVisitsProvider);
    final subAsync = ref.watch(_savingsSubProvider);

    return Scaffold(
      appBar: AppBar(title: Text(ref.lang('savings.title'))),
      body: visitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('${ref.lang('common.error_prefix')}: $e')),
        data: (visits) {
          final sub = subAsync.valueOrNull;
          final plan = sub?.plan ?? 'standard';
          final rate = SavingsCalculator.rateForPlan(plan);

          // Group visits by month → sum hours spent
          final monthlyHours = <String, int>{};
          for (final v in visits) {
            final key =
                '${v.createdAt.year}-${v.createdAt.month.toString().padLeft(2, '0')}';
            monthlyHours[key] = (monthlyHours[key] ?? 0) + v.hoursSpent;
          }

          // Total hours + total saved (all-time, approximate)
          final totalHours = visits.fold<int>(0, (s, v) => s + v.hoursSpent);
          final totalRegularCost = totalHours * rate;

          // Get last 6 months for chart
          final now = DateTime.now();
          final months = <_MonthData>[];
          for (int i = 5; i >= 0; i--) {
            final d = DateTime(now.year, now.month - i);
            final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
            final hours = monthlyHours[key] ?? 0;
            months.add(_MonthData(
              date: d,
              hours: hours,
              saved: hours * rate,
            ));
          }

          final maxSaved =
              months.fold<int>(0, (m, x) => x.saved > m ? x.saved : m);

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              ref.invalidate(_allVisitsProvider);
              await ref.read(_allVisitsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Hero total card ────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.success.withValues(alpha: 0.2),
                        AppTheme.neonCyan.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.savings_rounded,
                                color: AppTheme.success, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Text(ref.lang('savings.all_time'),
                              style: TextStyle(
                                  color: context.text2, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${SavingsCalculator.formatAmount(totalRegularCost)} ${ref.lang('home.currency')}',
                        style: const TextStyle(
                          color: AppTheme.success,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ref
                            .lang('savings.hint')
                            .replaceAll('{hours}', '$totalHours')
                            .replaceAll(
                                '{rate}', SavingsCalculator.formatAmount(rate)),
                        style: TextStyle(color: context.text3, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Monthly chart header ────────────────────
                Text(ref.lang('savings.by_months'),
                    style: TextStyle(
                      color: context.text1,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 16),

                // ── Bar chart ──────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: context.border.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: months.map((m) {
                            final heightFactor =
                                maxSaved > 0 ? m.saved / maxSaved : 0.0;
                            return Expanded(
                              child: _MonthBar(
                                month: m,
                                heightFactor: heightFactor,
                                currency: ref.lang('home.currency'),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Month labels
                      Row(
                        children: months.map((m) {
                          return Expanded(
                            child: Center(
                              child: Text(
                                _monthShort(m.date.month, ref),
                                style: TextStyle(
                                  color: context.text3,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Plan rate info ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: context.border.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppTheme.neonCyan, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ref
                              .lang('savings.calc_info')
                              .replaceAll(
                                  '{plan}', sub?.localizedPlanName(ref) ?? plan)
                              .replaceAll('{rate}',
                                  SavingsCalculator.formatAmount(rate)),
                          style: TextStyle(
                              color: context.text2, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  String _monthShort(int month, WidgetRef ref) {
    // Use locale-aware short month labels
    final keys = [
      'month.jan',
      'month.feb',
      'month.mar',
      'month.apr',
      'month.may',
      'month.jun',
      'month.jul',
      'month.aug',
      'month.sep',
      'month.oct',
      'month.nov',
      'month.dec',
    ];
    return ref.lang(keys[month - 1]);
  }
}

class _MonthData {
  final DateTime date;
  final int hours;
  final int saved;
  _MonthData({required this.date, required this.hours, required this.saved});
}

class _MonthBar extends StatelessWidget {
  final _MonthData month;
  final double heightFactor;
  final String currency;

  const _MonthBar({
    required this.month,
    required this.heightFactor,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (month.saved > 0)
            Text(
              _formatCompact(month.saved),
              style: TextStyle(
                color: context.text2,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              height: (160 * heightFactor)
                  .clamp(month.saved > 0 ? 4.0 : 0.0, 160.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.success,
                    AppTheme.neonCyan,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: month.saved > 0
                    ? [
                        BoxShadow(
                          color: AppTheme.success.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, -2),
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact number: 301500 → "301K", 1500000 → "1.5M"
  String _formatCompact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n ~/ 1000)}K';
    return '$n';
  }
}
