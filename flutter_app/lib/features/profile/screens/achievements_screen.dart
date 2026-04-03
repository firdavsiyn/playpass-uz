import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('Достижения')),
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
                  color: AppTheme.bgCard,
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
                    const Text('достижений разблокировано',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: achievements.isEmpty ? 0 : unlockedCount / achievements.length,
                        backgroundColor: AppTheme.bgSurface,
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
                return _AchievementCard(achievement: a, isUnlocked: isUnlocked);
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Map<String, dynamic> achievement;
  final bool isUnlocked;
  const _AchievementCard({required this.achievement, required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    final icon = achievement['icon'] as String? ?? '?';
    final name = achievement['name_ru'] as String? ?? '';
    final desc = achievement['desc_ru'] as String? ?? '';
    final category = achievement['category'] as String? ?? '';

    final categoryColor = switch (category) {
      'visits' => AppTheme.primary,
      'explorer' => AppTheme.neonCyan,
      'time' => AppTheme.neonPurple,
      'social' => AppTheme.neonPink,
      _ => AppTheme.textMuted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnlocked ? AppTheme.bgCard : AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked ? categoryColor.withValues(alpha: 0.25) : AppTheme.bgSurface,
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
                  : AppTheme.textMuted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              icon,
              style: TextStyle(
                fontSize: 24,
                color: isUnlocked ? null : AppTheme.textMuted,
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
                    color: isUnlocked ? AppTheme.textPrimary : AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: isUnlocked ? AppTheme.textSecondary : AppTheme.textMuted,
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
            Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted.withValues(alpha: 0.3), size: 20),
        ],
      ),
    );
  }
}
