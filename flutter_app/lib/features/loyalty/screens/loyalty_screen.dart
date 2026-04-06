import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../services/supabase_service.dart';

final loyaltyProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return SupabaseService().getLoyaltyInfo();
});

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tr(ref.watch(localeProvider));
    final data = ref.watch(loyaltyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t['loyalty_title'] ?? 'Программа лояльности')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (info) {
          final xp = info['xp'] as int? ?? 0;
          final level = info['level'] as String? ?? 'bronze';
          final streak = info['streak_days'] as int? ?? 0;
          final history = (info['history'] as List?) ?? [];

          return RefreshIndicator(
            onRefresh: () => ref.refresh(loyaltyProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Level card
                _LevelCard(level: level, xp: xp),
                const SizedBox(height: 16),

                // Streak
                _StreakWidget(days: streak),
                const SizedBox(height: 16),

                // XP Progress to next level
                _XpProgressCard(xp: xp, level: level),
                const SizedBox(height: 20),

                // Level perks
                _PerksSection(level: level),
                const SizedBox(height: 20),

                // XP History
                Text(t['loyalty_history'] ?? 'История XP',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  const Center(child: Text('Пока нет XP', style: TextStyle(color: AppTheme.textMuted)))
                else
                  ...history.map((h) => _XpHistoryItem(
                    amount: h['amount'] as int,
                    reason: h['reason'] as String,
                    date: DateTime.parse(h['created_at'] as String),
                  )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String level;
  final int xp;
  const _LevelCard({required this.level, required this.xp});

  static const _levels = {
    'bronze': (icon: '🥉', name: 'Bronze', color: Color(0xFFCD7F32), gradient: [Color(0xFF8B4513), Color(0xFFCD7F32)]),
    'silver': (icon: '🥈', name: 'Silver', color: Color(0xFFC0C0C0), gradient: [Color(0xFF808080), Color(0xFFC0C0C0)]),
    'gold': (icon: '🥇', name: 'Gold', color: Color(0xFFFFD700), gradient: [Color(0xFFB8860B), Color(0xFFFFD700)]),
    'diamond': (icon: '💎', name: 'Diamond', color: Color(0xFF00CED1), gradient: [Color(0xFF0066CC), Color(0xFF00CED1)]),
  };

  @override
  Widget build(BuildContext context) {
    final l = _levels[level] ?? _levels['bronze']!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: l.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: l.color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text(l.icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(l.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('$xp XP', style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.9))),
        ],
      ),
    );
  }
}

class _StreakWidget extends StatelessWidget {
  final int days;
  const _StreakWidget({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: days > 0 ? AppTheme.warning.withValues(alpha: 0.3) : AppTheme.border),
      ),
      child: Row(
        children: [
          Text(days > 0 ? '🔥' : '❄️', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$days ${days == 1 ? 'день' : 'дней'} подряд',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Text(days > 0 ? 'Продолжайте в том же духе!' : 'Посетите клуб чтобы начать серию',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (days >= 7) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('x${(days ~/ 7) + 1}', style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.warning)),
          ),
        ],
      ),
    );
  }
}

class _XpProgressCard extends StatelessWidget {
  final int xp;
  final String level;
  const _XpProgressCard({required this.xp, required this.level});

  @override
  Widget build(BuildContext context) {
    final (nextLevel, nextXp) = switch (level) {
      'bronze' => ('Silver 🥈', 500),
      'silver' => ('Gold 🥇', 2000),
      'gold' => ('Diamond 💎', 5000),
      _ => ('Max ✨', xp),
    };

    final prevXp = switch (level) {
      'bronze' => 0,
      'silver' => 500,
      'gold' => 2000,
      _ => 5000,
    };

    final progress = nextXp > prevXp ? (xp - prevXp) / (nextXp - prevXp) : 1.0;
    final remaining = nextXp - xp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('До $nextLevel', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              if (remaining > 0) Text('$remaining XP', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppTheme.border,
              color: AppTheme.primary,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _PerksSection extends StatelessWidget {
  final String level;
  const _PerksSection({required this.level});

  @override
  Widget build(BuildContext context) {
    final levels = ['bronze', 'silver', 'gold', 'diamond'];
    final currentIdx = levels.indexOf(level);

    final allPerks = [
      (level: 'bronze', icon: '🎮', title: 'Базовый доступ', desc: 'Доступ ко всем клубам'),
      (level: 'silver', icon: '⏰', title: '+1 час бесплатно', desc: 'Бонусный час каждый месяц'),
      (level: 'silver', icon: '🏷', title: 'Скидка 5%', desc: 'На продление подписки'),
      (level: 'gold', icon: '👑', title: 'VIP зоны', desc: 'Приоритетный доступ к VIP'),
      (level: 'gold', icon: '🎁', title: 'Подарок на ДР', desc: '5 бесплатных часов'),
      (level: 'diamond', icon: '💎', title: 'Скидка 15%', desc: 'На все подписки'),
      (level: 'diamond', icon: '🏆', title: 'Бесплатные турниры', desc: 'Участие без взноса'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Привилегии', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        ...allPerks.map((p) {
          final unlocked = levels.indexOf(p.level) <= currentIdx;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: unlocked ? AppTheme.cardDark : AppTheme.bgDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: unlocked ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border),
            ),
            child: Row(
              children: [
                Text(p.icon, style: TextStyle(fontSize: 24, color: unlocked ? null : Colors.grey)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title, style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: unlocked ? AppTheme.textPrimary : AppTheme.textMuted)),
                      Text(p.desc, style: TextStyle(
                        fontSize: 12, color: unlocked ? AppTheme.textSecondary : AppTheme.textMuted)),
                    ],
                  ),
                ),
                unlocked
                    ? const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                    : const Icon(Icons.lock_outlined, color: AppTheme.textMuted, size: 20),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _XpHistoryItem extends StatelessWidget {
  final int amount;
  final String reason;
  final DateTime date;
  const _XpHistoryItem({required this.amount, required this.reason, required this.date});

  String get _reasonLabel => switch (reason) {
    'visit' => '🎮 Визит в клуб',
    'review' => '⭐ Написал отзыв',
    'tournament_register' => '🏆 Запись на турнир',
    'referral' => '👥 Пригласил друга',
    'streak_bonus' => '🔥 Бонус за серию',
    'achievement' => '🎯 Достижение',
    _ => '✨ $reason',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_reasonLabel, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
          Text('+$amount XP', style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.success)),
        ],
      ),
    );
  }
}
