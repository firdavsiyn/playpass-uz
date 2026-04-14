import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

final _allAchievementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return SupabaseService().getAllAchievements();
});

final _userAchievementsProvider = FutureProvider<Set<String>>((ref) async {
  final list = await SupabaseService().getUserAchievements();
  return list.map((e) => e['achievement_id'] as String).toSet();
});

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(_allAchievementsProvider);
    final unlockedAsync = ref.watch(_userAchievementsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(ref.lang('ach.title'))),
      body: allAsync.when(
        data: (achievements) {
          final unlocked = unlockedAsync.valueOrNull ?? {};
          final unlockedCount = achievements.where((a) => unlocked.contains(a['id'])).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              // Progress header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                  boxShadow: AppTheme.neonGlow(radius: 16),
                ),
                child: Column(
                  children: [
                    Text(
                      '$unlockedCount / ${achievements.length}',
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(ref.lang('ach.unlocked'),
                        style: TextStyle(color: context.text2, fontSize: 14)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: achievements.isEmpty ? 0 : unlockedCount / achievements.length,
                        backgroundColor: context.surface,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Achievement grid
              ...achievements.map((a) {
                final isUnlocked = unlocked.contains(a['id']);
                return _AchievementCard(achievement: a, isUnlocked: isUnlocked, locale: ref.watch(localeProvider));
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.lang('common.error_prefix')}: $e')),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Map<String, dynamic> achievement;
  final bool isUnlocked;
  final String locale;
  const _AchievementCard({required this.achievement, required this.isUnlocked, required this.locale});

  @override
  Widget build(BuildContext context) {
    final icon = achievement['icon'] as String? ?? '?';
    final name = achievement['name_$locale'] as String? ?? achievement['name_ru'] as String? ?? '';
    final desc = achievement['desc_$locale'] as String? ?? achievement['desc_ru'] as String? ?? '';
    final category = achievement['category'] as String? ?? '';

    final categoryColor = switch (category) {
      'visits' => AppTheme.primary,
      'explorer' => AppTheme.neonCyan,
      'time' => AppTheme.neonPurple,
      'social' => AppTheme.neonPink,
      _ => context.text3,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnlocked ? context.card : context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked ? categoryColor.withValues(alpha: 0.25) : context.surface,
        ),
        boxShadow: isUnlocked
            ? [BoxShadow(color: categoryColor.withValues(alpha: 0.1), blurRadius: 12)]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? categoryColor.withValues(alpha: 0.15)
                  : context.text3.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              icon,
              style: TextStyle(
                fontSize: 24,
                color: isUnlocked ? null : context.text3,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isUnlocked ? context.text1 : context.text3,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: isUnlocked ? context.text2 : context.text3,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isUnlocked)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: categoryColor, size: 16),
            )
          else
            Icon(Icons.lock_outline_rounded, color: context.text3.withValues(alpha: 0.3), size: 20),
        ],
      ),
    );
  }
}
