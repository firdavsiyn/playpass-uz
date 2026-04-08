import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

final _referralStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return SupabaseService().getReferralStats();
});

final _referralCodeProvider = FutureProvider<String>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return '';
  final profile = await SupabaseService().getUserProfile(userId);
  return profile?['referral_code'] as String? ?? '';
});

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_referralStatsProvider);
    final codeAsync = ref.watch(_referralCodeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Реферальная программа'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 16),

          // Explanation card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
              boxShadow: AppTheme.cardGlow(),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.2),
                        AppTheme.neonPurple.withValues(alpha: 0.15),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.neonGlow(radius: 16),
                  ),
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    color: AppTheme.primaryLight,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Пригласи друга — вы оба получите +3 часа к подписке',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.text1,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Поделитесь кодом с другом. После его первой подписки вы оба получите бонусные часы.',
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

          // Referral code
          codeAsync.when(
            data: (code) => _ReferralCodeCard(code: code),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Ошибка: $e',
                  style: const TextStyle(color: AppTheme.error)),
            ),
          ),

          const SizedBox(height: 20),

          // Stats
          statsAsync.when(
            data: (stats) {
              final friendsCount = stats['friends_count'] as int? ?? 0;
              final totalHours = stats['total_hours'] as int? ?? 0;
              final transactions = stats['transactions'] as List? ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Приглашено друзей',
                          value: '$friendsCount',
                          icon: Icons.people_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Заработано часов',
                          value: '$totalHours',
                          icon: Icons.access_time_rounded,
                        ),
                      ),
                    ],
                  ),

                  if (transactions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Последние приглашения',
                      style: TextStyle(
                        color: context.text1,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...transactions.map<Widget>((tx) {
                      final inviteeName =
                          (tx['users']?['name'] as String?) ?? 'Друг';
                      final bonusHours = tx['bonus_hours'] as int? ?? 3;
                      final createdAt = tx['created_at'] as String? ?? '';
                      final date = createdAt.length >= 10
                          ? createdAt.substring(0, 10)
                          : createdAt;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.success.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_add_rounded,
                                color: AppTheme.success,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inviteeName,
                                    style: TextStyle(
                                      color: context.text1,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    date,
                                    style: TextStyle(
                                      color: context.text3,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '+$bonusHours ч',
                              style: const TextStyle(
                                color: AppTheme.success,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Ошибка: $e',
                  style: const TextStyle(color: AppTheme.error)),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  final String code;
  const _ReferralCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    if (code.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Реферальный код пока не назначен',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.text3, fontSize: 14),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        boxShadow: AppTheme.neonGlow(radius: 20),
      ),
      child: Column(
        children: [
          Text(
            'Ваш реферальный код',
            style: TextStyle(color: context.text2, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            code,
            style: const TextStyle(
              color: AppTheme.primaryLight,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Код скопирован')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Копировать', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text:
                          'Привет! Попробуй PlayPass - подписку на компьютерные клубы. Используй мой код: $code и получи +3 часа бонусом!',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Текст для отправки скопирован')),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Поделиться', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
        boxShadow: AppTheme.cardGlow(),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryLight, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: context.text1,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.text3,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
