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
  late double _selectedDays;
  bool _loading = false;

  Subscription get sub => widget.subscription;

  @override
  void initState() {
    super.initState();
    _selectedDays = 1;
  }

  Future<void> _freeze() async {
    setState(() => _loading = true);
    try {
      await SupabaseService()
          .freezeSubscription(sub.id, _selectedDays.round());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Подписка заморожена на ${_selectedDays.round()} дн.'),
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unfreeze() async {
    setState(() => _loading = true);
    try {
      await SupabaseService().unfreezeSubscription(sub.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Подписка разморожена')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFrozen = sub.isFrozen;
    final freezeDaysLeft = sub.freezeDaysLeft;

    return Scaffold(
      appBar: AppBar(
        title: Text('Заморозка подписки'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Explanation card
            Container(
              width: double.infinity,
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
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.info.withValues(alpha: 0.2),
                          AppTheme.neonCyan.withValues(alpha: 0.15),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.neonGlow(color: AppTheme.info, radius: 14),
                    ),
                    child: Icon(
                      isFrozen
                          ? Icons.ac_unit_rounded
                          : Icons.pause_circle_rounded,
                      color: AppTheme.info,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFrozen ? 'Подписка заморожена' : 'Заморозка подписки',
                    style: TextStyle(
                      color: context.text1,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Заморозка приостанавливает подписку. Дата окончания сдвигается на срок заморозки.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.text2,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Remaining days indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: context.text2, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Осталось доступных дней: $freezeDaysLeft из ${AppConstants.freezeMaxDays}',
                      style: TextStyle(
                        color: context.text1,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Progress bar for freeze days used
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: freezeDaysLeft / AppConstants.freezeMaxDays,
                backgroundColor: context.surface,
                valueColor:
                    AlwaysStoppedAnimation<Color>(
                  freezeDaysLeft > 3 ? AppTheme.primary : AppTheme.warning,
                ),
                minHeight: 6,
              ),
            ),

            if (isFrozen) ...[
              // Frozen state
              const SizedBox(height: 24),
              if (sub.frozenSince != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.info.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppTheme.info, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Заморожена с ${_formatDate(sub.frozenSince!)}',
                          style: TextStyle(
                            color: context.text1,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _unfreeze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Разморозить'),
                ),
              ),
            ] else ...[
              // Active state — show slider
              const SizedBox(height: 24),

              if (freezeDaysLeft <= 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: AppTheme.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Вы уже использовали все дни заморозки в этом периоде.',
                          style: TextStyle(
                            color: context.text1,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  'Выберите количество дней',
                  style: TextStyle(
                    color: context.text1,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Selected days display
                Center(
                  child: Text(
                    '${_selectedDays.round()} дн.',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primary,
                    inactiveTrackColor: context.surface,
                    thumbColor: AppTheme.primary,
                    overlayColor: AppTheme.primary.withValues(alpha: 0.2),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: _selectedDays,
                    min: 1,
                    max: freezeDaysLeft.toDouble(),
                    divisions: freezeDaysLeft > 1 ? freezeDaysLeft - 1 : 1,
                    onChanged: (v) => setState(() => _selectedDays = v),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1',
                        style: TextStyle(
                            color: context.text3, fontSize: 12)),
                    Text('$freezeDaysLeft',
                        style: TextStyle(
                            color: context.text3, fontSize: 12)),
                  ],
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _freeze,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Заморозить на ${_selectedDays.round()} дн.'),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
