import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';

/// Compact streak widget showing consecutive days of club visits.
/// Targets the "habit-formation" psychology — once a user is on a 3+ day
/// streak, they tend to extend it to avoid losing progress.
///
/// Milestones: 3 → 7 → 14 → 30 days. Each unlocks +3 bonus hours.
class StreakWidget extends ConsumerWidget {
  final int streakDays;
  final DateTime? lastVisitDate;
  const StreakWidget({super.key, required this.streakDays, this.lastVisitDate});

  /// Next milestone (>3 days = next is 7, etc.)
  int get _nextMilestone {
    if (streakDays < 3) return 3;
    if (streakDays < 7) return 7;
    if (streakDays < 14) return 14;
    if (streakDays < 30) return 30;
    return streakDays + 7;
  }

  /// Has the streak been updated today? If not, it's at risk of resetting.
  bool get _atRisk {
    if (lastVisitDate == null) return false;
    final daysSinceLast = DateTime.now().difference(lastVisitDate!).inDays;
    return daysSinceLast >= 1 && streakDays > 0;
  }

  String _pluralizeDays(int n, WidgetRef ref) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return ref.lang('streak.day_singular');
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return ref.lang('streak.day_few');
    }
    return ref.lang('streak.day_many');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (streakDays < 1) return const SizedBox.shrink();

    final daysToNext = _nextMilestone - streakDays;
    final progress = streakDays / _nextMilestone;
    final atRisk = _atRisk;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: atRisk
              ? [
                  AppTheme.warning.withValues(alpha: 0.12),
                  AppTheme.warning.withValues(alpha: 0.04),
                ]
              : [
                  const Color(0xFFFF6B35).withValues(alpha: 0.12),
                  AppTheme.warning.withValues(alpha: 0.06),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (atRisk ? AppTheme.warning : const Color(0xFFFF6B35))
              .withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          // Flame icon with glow
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: atRisk
                    ? [Colors.grey.shade600, Colors.grey.shade700]
                    : const [Color(0xFFFF6B35), Color(0xFFFFB627)],
              ),
              boxShadow: atRisk
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),

          // Days + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$streakDays',
                      style: TextStyle(
                        color: atRisk ? AppTheme.warning : const Color(0xFFFF6B35),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _pluralizeDays(streakDays, ref),
                      style: TextStyle(
                        color: context.text2,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Progress to next milestone
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: context.surface,
                    valueColor: AlwaysStoppedAnimation(
                      atRisk ? AppTheme.warning : const Color(0xFFFF6B35),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  daysToNext > 0
                      ? ref
                          .lang('streak.next_reward')
                          .replaceAll('{n}', '$daysToNext') +
                          ' → ${ref.lang('streak.bonus_3h')}'
                      : ref.lang('streak.reward_unlocked'),
                  style: TextStyle(
                    color: context.text3,
                    fontSize: 11,
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
