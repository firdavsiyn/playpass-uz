import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

final happyHoursProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return SupabaseService().getActiveHappyHours();
});

class HappyHoursScreen extends ConsumerWidget {
  const HappyHoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(happyHoursProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Скидки и акции')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_offer_outlined, size: 64, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text('Сейчас нет активных акций',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Заходите позже!',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(happyHoursProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) => _HappyHourCard(item: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _HappyHourCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HappyHourCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final club = item['clubs'] as Map<String, dynamic>?;
    final discount = item['discount_percent'] as int? ?? 0;
    final startTime = item['start_time'] as String? ?? '00:00';
    final endTime = item['end_time'] as String? ?? '00:00';
    final dayOfWeek = item['day_of_week'] as int?;
    final description = item['description'] as String?;

    final dayNames = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final dayLabel = dayOfWeek != null && dayOfWeek >= 1 && dayOfWeek <= 7
        ? dayNames[dayOfWeek]
        : 'Каждый день';

    // Check if currently active
    final now = TimeOfDay.now();
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final nowMinutes = now.hour * 60 + now.minute;
    final isNowActive = nowMinutes >= startMinutes && nowMinutes <= endMinutes &&
        (dayOfWeek == null || dayOfWeek == DateTime.now().weekday);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNowActive
              ? AppTheme.success.withValues(alpha: 0.4)
              : AppTheme.border,
        ),
        boxShadow: isNowActive
            ? [BoxShadow(color: AppTheme.success.withValues(alpha: 0.15), blurRadius: 12)]
            : [],
      ),
      child: Column(
        children: [
          // Header with discount
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.neonPurple.withValues(alpha: 0.15),
                  AppTheme.primary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Discount badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.neonPurple, AppTheme.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('-$discount%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          )),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(club?['name'] ?? 'Клуб',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              )),
                          if (isNowActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('Активно',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.success,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (description != null)
                        Text(description,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.3,
                            )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Time info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _InfoTag(Icons.access_time, '$startTime – $endTime'),
                const SizedBox(width: 8),
                _InfoTag(Icons.calendar_today, dayLabel),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    final clubId = item['club_id'] as String?;
                    if (clubId != null) context.push('/clubs/$clubId');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Перейти',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoTag(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
