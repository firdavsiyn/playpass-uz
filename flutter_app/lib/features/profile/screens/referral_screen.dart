import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

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
        title: Text(ref.lang('ref.title')),
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
                  ref.lang('ref.invite_desc'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.text1,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ref.lang('ref.share_desc'),
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
            data: (code) => _ReferralCodeCard(
              code: code,
              codeNotAssigned: ref.lang('ref.code_not_assigned'),
              yourCode: ref.lang('ref.your_code'),
              copyLabel: ref.lang('ref.copy'),
              codeCopied: ref.lang('ref.code_copied'),
              shareLabel: ref.lang('ref.share'),
              shareText: ref.lang('ref.share_text'),
              shareCopied: ref.lang('ref.share_copied'),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text('${ref.lang('common.error_prefix')}$e',
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
                          label: ref.lang('ref.friends_invited'),
                          value: '$friendsCount',
                          icon: Icons.people_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: ref.lang('ref.hours_earned'),
                          value: '$totalHours',
                          icon: Icons.access_time_rounded,
                        ),
                      ),
                    ],
                  ),

                  if (transactions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      ref.lang('ref.recent_invites'),
                      style: TextStyle(
                        color: context.text1,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...transactions.map<Widget>((tx) {
                      final inviteeName =
                          (tx['users']?['name'] as String?) ?? ref.lang('ref.friend_default');
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
                              '+$bonusHours ${ref.lang('ref.hours_suffix')}',
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
              child: Text('${ref.lang('common.error_prefix')}$e',
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
  final String codeNotAssigned;
  final String yourCode;
  final String copyLabel;
  final String codeCopied;
  final String shareLabel;
  final String shareText;
  final String shareCopied;

  const _ReferralCodeCard({
    required this.code,
    required this.codeNotAssigned,
    required this.yourCode,
    required this.copyLabel,
    required this.codeCopied,
    required this.shareLabel,
    required this.shareText,
    required this.shareCopied,
  });

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
          codeNotAssigned,
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
            yourCode,
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
                      SnackBar(content: Text(codeCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(copyLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: shareText.replaceFirst('{code}', code),
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(shareCopied)),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(shareLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
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
