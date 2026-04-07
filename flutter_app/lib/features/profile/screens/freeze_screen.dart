import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/subscription.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class FreezeScreen extends StatefulWidget {
  final Subscription subscription;

  const FreezeScreen({super.key, required this.subscription});

  @override
  State<FreezeScreen> createState() => _FreezeScreenState();
}

class _FreezeScreenState extends State<FreezeScreen> {
  final _svc = SupabaseService();
  Set<DateTime> _frozenDates = {};
  bool _loading = true;
  late DateTime _viewMonth;

  Subscription get sub => widget.subscription;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
    _loadFreezeDates();
  }

  Future<void> _loadFreezeDates() async {
    setState(() => _loading = true);
    try {
      final dates = await _svc.getFreezeDates(
        sub.id,
        year: _viewMonth.year,
        month: _viewMonth.month,
      );
      if (mounted) {
        setState(() {
          _frozenDates = dates.map((d) => DateTime(d.year, d.month, d.day)).toSet();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    // Can't freeze past dates
    if (normalized.isBefore(todayNorm)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя заморозить прошедший день')),
      );
      return;
    }

    final isRemoving = _frozenDates.contains(normalized);

    // Can't add if already at limit and not removing
    if (!isRemoving &&
        _frozenDates.length >= AppConstants.freezeMaxDaysPerMonth) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Лимит ${AppConstants.freezeMaxDaysPerMonth} дней в месяц исчерпан'),
        ),
      );
      return;
    }

    // Optimistic UI — update immediately, DB call in background
    setState(() {
      if (isRemoving) {
        _frozenDates.remove(normalized);
      } else {
        _frozenDates.add(normalized);
      }
    });

    // Fire-and-forget DB call, revert on error
    try {
      await _svc.toggleFreezeDate(sub.id, normalized);
    } catch (e) {
      // Revert optimistic update
      if (mounted) {
        setState(() {
          if (isRemoving) {
            _frozenDates.add(normalized);
          } else {
            _frozenDates.remove(normalized);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta);
    });
    _loadFreezeDates();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = AppConstants.freezeMaxDaysPerMonth - _frozenDates.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заморозка подписки'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 16),

                // Info card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.info.withValues(alpha: 0.1)),
                    boxShadow: AppTheme.cardGlow(color: AppTheme.info),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppTheme.info.withValues(alpha: 0.2),
                            AppTheme.neonCyan.withValues(alpha: 0.15),
                          ]),
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.neonGlow(color: AppTheme.info, radius: 14),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: AppTheme.info,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Выберите дни заморозки',
                        style: TextStyle(
                          color: context.text1,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Нажмите на дни в календаре, чтобы заморозить или разморозить. '
                        'Дата окончания подписки сдвигается на каждый замороженный день.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.text2, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Remaining quota
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        remaining > 0 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: remaining > 0 ? AppTheme.success : AppTheme.error,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Осталось: $remaining из ${AppConstants.freezeMaxDaysPerMonth} дней',
                              style: TextStyle(
                                color: context.text1,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Выбрано: ${_frozenDates.length} ${_daysWord(_frozenDates.length)}',
                              style: TextStyle(color: context.text3, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _frozenDates.length / AppConstants.freezeMaxDaysPerMonth,
                    backgroundColor: context.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      remaining > 1 ? AppTheme.primary : AppTheme.warning,
                    ),
                    minHeight: 5,
                  ),
                ),

                const SizedBox(height: 20),

                // Calendar
                _buildCalendar(context),

                const SizedBox(height: 20),

                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendDot(AppTheme.info, 'Заморожен'),
                    const SizedBox(width: 20),
                    _legendDot(context.text3.withValues(alpha: 0.3), 'Прошедший'),
                    const SizedBox(width: 20),
                    _legendDot(AppTheme.primary, 'Сегодня'),
                  ],
                ),

                if (_frozenDates.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  // Frozen dates list
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Замороженные дни',
                          style: TextStyle(
                            color: context.text1,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (_frozenDates.toList()..sort())
                              .map((d) => Chip(
                                    label: Text(
                                      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 12, color: Colors.white),
                                    ),
                                    backgroundColor: AppTheme.info,
                                    deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                                    onDeleted: () => _toggleDate(d),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    final firstOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final startWeekday = (firstOfMonth.weekday - 1) % 7; // Mon=0

    final monthName = _monthName(_viewMonth.month);
    final isCurrentMonth = _viewMonth.year == now.year && _viewMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: isCurrentMonth ? null : () => _changeMonth(-1),
                icon: Icon(Icons.chevron_left_rounded,
                    color: isCurrentMonth ? context.text3.withValues(alpha: 0.3) : context.text1),
              ),
              Text(
                '$monthName ${_viewMonth.year}',
                style: TextStyle(
                  color: context.text1,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: Icon(Icons.chevron_right_rounded, color: context.text1),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Day headers
          Row(
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                              color: context.text3,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 8),

          // Day grid
          ...List.generate(6, (week) {
            return Row(
              children: List.generate(7, (weekday) {
                final dayNum = week * 7 + weekday - startWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 42));
                }

                final date = DateTime(_viewMonth.year, _viewMonth.month, dayNum);
                final isPast = date.isBefore(todayNorm);
                final isToday = date == todayNorm;
                final isFrozen = _frozenDates.contains(date);
                final isWeekend = weekday >= 5;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _toggleDate(date),
                    child: Container(
                      height: 42,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isFrozen
                            ? AppTheme.info
                            : isToday
                                ? AppTheme.primary.withValues(alpha: 0.15)
                                : isPast
                                    ? context.surface.withValues(alpha: 0.5)
                                    : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isToday && !isFrozen
                            ? Border.all(color: AppTheme.primary, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            color: isFrozen
                                ? Colors.white
                                : isPast
                                    ? context.text3.withValues(alpha: 0.4)
                                    : isToday
                                        ? AppTheme.primary
                                        : isWeekend
                                            ? AppTheme.error.withValues(alpha: 0.7)
                                            : context.text1,
                            fontSize: 14,
                            fontWeight: isFrozen || isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }

  String _monthName(int month) => const [
    '', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ][month];

  String _daysWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'дня';
    return 'дней';
  }
}
