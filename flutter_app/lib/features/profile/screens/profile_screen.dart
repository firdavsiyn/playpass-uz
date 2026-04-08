import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/neon_shimmer.dart';
import '../../../models/subscription.dart';

final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  return SupabaseService().getUserProfile(userId);
});

// Re-use activeSubscriptionProvider from home_screen to avoid duplicate queries
final subscriptionProvider = FutureProvider<Subscription?>((ref) async {
  return SupabaseService().getActiveSubscription();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final subAsync = ref.watch(subscriptionProvider);

    // Show loading spinner only on initial load (no previous data)
    // During refresh after name/avatar change, keep showing old profile
    final Widget body;
    if (profileAsync.isLoading && !profileAsync.hasValue) {
      body = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const NeonSkeletonCard(height: 200, borderRadius: 20),
          const SizedBox(height: 16),
          ...List.generate(6, (_) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: NeonSkeletonCard(height: 56, borderRadius: 14),
          )),
        ]),
      );
    } else if (profileAsync.hasError && !profileAsync.hasValue) {
      body = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 100,
          child: Center(child: Text('${ref.lang('common.error')}: ${profileAsync.error}')),
        ),
      );
    } else {
      body = _ProfileContent(
        profile: profileAsync.valueOrNull,
        subscription: subAsync.valueOrNull,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(ref.lang('profile.title'))),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(profileProvider);
          ref.invalidate(subscriptionProvider);
          await Future.wait([
            ref.read(profileProvider.future),
            ref.read(subscriptionProvider.future),
          ]).catchError((_) {});
        },
        child: body,
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  final Map<String, dynamic>? profile;
  final Subscription? subscription;
  const _ProfileContent({this.profile, this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile?['name'] as String? ?? ref.lang('level.gamer');
    final avatarUrl = profile?['avatar_url'] as String?;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final referralCode = profile?['referral_code'] as String? ?? '';
    final level = profile?['level'] as String? ?? 'novice';
    final totalVisits = profile?['total_visits'] as int? ?? 0;
    final xp = profile?['xp'] as int? ?? 0;
    final totalHours = profile?['total_hours'] as int? ?? 0;
    final streakDays = profile?['streak_days'] as int? ?? 0;

    // XP progress to next level
    final xpThresholds = {'novice': 100, 'regular': 500, 'pro': 1500, 'veteran': 5000, 'legend': 99999};
    final currentThreshold = xpThresholds[level] ?? 100;
    final xpProgress = (xp / currentThreshold).clamp(0.0, 1.0);
    final xpPercent = (xpProgress * 100).round();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),

        // ── Player Card (gaming style) ────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withValues(alpha: 0.5),
                AppTheme.neonCyan.withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(1.5),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Column(
              children: [
                // Avatar + Name row
                Row(
                  children: [
                    // Avatar with gradient ring
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.neonCyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: AppAvatar.large(imageUrl: avatarUrl, name: name),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _pickAndUploadAvatar(context, ref),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.primary, AppTheme.neonCyan],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: context.card, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Name + Level
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(
                            color: context.text1,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          )),
                          const SizedBox(height: 2),
                          Text(email,
                              style: TextStyle(color: context.text3, fontSize: 12)),
                          const SizedBox(height: 6),
                          // Level badge — compact with gradient bg, no border
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primary.withValues(alpha: 0.15),
                                  AppTheme.neonCyan.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(AppConstants.levelIcon(level), style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 4),
                                Text(
                                  AppConstants.localizedLevelLabel(level, ref),
                                  style: const TextStyle(
                                    color: AppTheme.primaryLight,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // XP Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$xp XP ($xpPercent%)', style: TextStyle(
                          color: AppTheme.neonCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                        Text('$currentThreshold XP', style: TextStyle(
                          color: context.text3,
                          fontSize: 11,
                        )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(3.5),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: xpProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.neonCyan],
                            ),
                            borderRadius: BorderRadius.circular(3.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.neonCyan.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: -1,
                              ),
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 4,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Stats row — glass containers with gaps
                Row(
                  children: [
                    _StatItem(value: '$totalVisits', label: ref.lang('profile.visits_total'),
                        color: AppTheme.neonCyan),
                    const SizedBox(width: 8),
                    _StatItem(value: '${totalHours}h', label: ref.lang('profile.hours_label'),
                        color: AppTheme.neonPurple),
                    const SizedBox(width: 8),
                    _StatItem(value: '$streakDays', label: ref.lang('profile.streak_label'),
                        color: AppTheme.warning),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Subscription card
        if (subscription != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              boxShadow: AppTheme.cardGlow(),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${ref.lang('profile.sub_label')}: ${subscription!.localizedPlanName(ref)}',
                        style: TextStyle(
                            color: context.text1,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '${ref.lang('profile.until')} ${subscription!.endDate.day}.${subscription!.endDate.month.toString().padLeft(2, '0')}.${subscription!.endDate.year}',
                      style: TextStyle(color: context.text3, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/plans'),
                  child: Text(ref.lang('profile.renew')),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Menu items
        _MenuItem(
          icon: Icons.favorite_rounded,
          title: ref.lang('profile.favorites'),
          onTap: () => context.push('/profile/favorites'),
        ),
        _MenuItem(
          icon: Icons.emoji_events_rounded,
          title: ref.lang('profile.achievements'),
          onTap: () => context.push('/profile/achievements'),
        ),
        _MenuItem(
          icon: Icons.history_rounded,
          title: ref.lang('profile.visit_history'),
          onTap: () => context.push('/profile/history'),
        ),
        _MenuItem(
          icon: Icons.computer_rounded,
          title: ref.lang('profile.booking'),
          subtitle: ref.lang('profile.booking_sub'),
          onTap: () => context.push('/booking'),
        ),
        _MenuItem(
          icon: Icons.emoji_events_rounded,
          title: ref.lang('profile.tournaments'),
          subtitle: ref.lang('profile.tournaments_sub'),
          onTap: () => context.push('/tournaments'),
        ),
        _MenuItem(
          icon: Icons.star_rounded,
          title: ref.lang('profile.loyalty'),
          subtitle: ref.lang('profile.loyalty_sub'),
          onTap: () => context.push('/loyalty'),
        ),
        _MenuItem(
          icon: Icons.sports_esports_rounded,
          title: ref.lang('profile.player_stats'),
          subtitle: ref.lang('profile.player_stats_sub'),
          onTap: () => context.push('/player-stats'),
        ),
        _MenuItem(
          icon: Icons.people_rounded,
          title: ref.lang('profile.lfg'),
          subtitle: ref.lang('profile.lfg_sub'),
          onTap: () => context.push('/lfg'),
        ),
        _MenuItem(
          icon: Icons.leaderboard_rounded,
          title: ref.lang('profile.leaderboard'),
          subtitle: ref.lang('profile.leaderboard_sub'),
          onTap: () => context.push('/leaderboard'),
        ),
        _MenuItem(
          icon: Icons.notifications_rounded,
          title: ref.lang('profile.notifications'),
          subtitle: ref.lang('profile.notif_sub'),
          onTap: () => context.push('/notifications-settings'),
        ),
        _MenuItem(
          icon: Icons.card_membership_rounded,
          title: ref.lang('profile.buy_sub'),
          onTap: () => context.push('/plans'),
        ),
        _MenuItem(
          icon: Icons.card_giftcard_rounded,
          title: ref.lang('profile.gifts'),
          subtitle: ref.lang('profile.gifts_sub'),
          onTap: () => context.push('/gift/purchase'),
        ),
        _MenuItem(
          icon: Icons.people_outline_rounded,
          title: ref.lang('profile.referral'),
          subtitle: ref.lang('profile.referral_sub'),
          onTap: () => context.push('/profile/referral'),
        ),
        if (subscription != null && subscription!.canFreeze)
          _MenuItem(
            icon: Icons.ac_unit_rounded,
            title: ref.lang('profile.freeze'),
            subtitle: '${subscription!.freezeDaysLeft} ${ref.lang('profile.freeze_days')}',
            onTap: () => context.push('/profile/freeze', extra: subscription),
          ),
        if (subscription != null && subscription!.isFrozen)
          _MenuItem(
            icon: Icons.ac_unit_rounded,
            title: ref.lang('profile.frozen'),
            subtitle: ref.lang('profile.frozen_sub'),
            onTap: () => context.push('/profile/freeze', extra: subscription),
          ),
        _LanguageToggle(),
        _ThemeToggle(),
        _MenuItem(
          icon: Icons.edit_outlined,
          title: ref.lang('profile.change_name'),
          onTap: () => _showChangeNameDialog(context, ref, name),
        ),
        _MenuItem(
          icon: Icons.help_outline_rounded,
          title: ref.lang('profile.support'),
          onTap: () => _showSupportSheet(context, ref),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.logout_rounded,
          title: ref.lang('profile.logout'),
          color: AppTheme.error,
          onTap: () async {
            await SupabaseService().signOut();
            if (context.mounted) context.go('/auth/login');
          },
        ),

        const SizedBox(height: 24),
        Center(
          child: Text(
            'PlayPass v1.0',
            style: TextStyle(
              color: context.text3.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Future<void> _pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
    // Cache stable references before async gap
    final messenger = ScaffoldMessenger.of(context);
    final uploadText = ref.lang('profile.upload_photo');
    final doneText = ref.lang('profile.photo_updated');
    final errorText = ref.lang('common.error');

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image == null) return;

      messenger.showSnackBar(SnackBar(content: Text(uploadText)));

      final bytes = await image.readAsBytes();
      await SupabaseService().uploadAvatar(bytes.toList(), image.name);
      ref.invalidate(profileProvider);

      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text(doneText)));
    } catch (e) {
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text('$errorText: $e')));
    }
  }

  void _showChangeNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    // Cache translated strings before async gap
    final changeName = ref.lang('profile.change_name');
    final nameHint = ref.lang('profile.name_hint');
    final cancelText = ref.lang('common.cancel');
    final saveText = ref.lang('common.save');
    final tooShortText = ref.lang('profile.name_too_short');
    final nameChangedText = ref.lang('profile.name_changed');
    final errorText = ref.lang('common.error');
    // Get scaffold messenger before dialog opens (stable reference)
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.15)),
        ),
        title: Text(changeName,
            style: TextStyle(color: context.text1)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: context.text1, fontSize: 16),
          decoration: InputDecoration(
            hintText: nameHint,
            prefixIcon: Icon(Icons.person_outline, size: 20),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(cancelText),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.length < 2) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(tooShortText)),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                try {
                  await SupabaseService().updateUserProfile(name: newName);
                  ref.invalidate(profileProvider);
                  messenger.showSnackBar(
                    SnackBar(content: Text('$nameChangedText: $newName')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('$errorText: $e')),
                  );
                }
              },
              child: Text(saveText),
            ),
          ),
        ],
      ),
    );
  }

  void _showSupportSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.text3.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
              child: const Icon(Icons.headset_mic_rounded,
                  color: AppTheme.primaryLight, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              ref.lang('support.title'),
              style: TextStyle(
                color: context.text1,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ref.lang('support.hours'),
              style: TextStyle(color: context.text2, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _SupportOption(
              icon: Icons.send_rounded,
              title: 'Telegram',
              subtitle: '@playpass_support',
              color: const Color(0xFF2AABEE),
              onTap: () async {
                Navigator.pop(context);
                final url = Uri.parse('https://t.me/playpass_support');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 12),
            _SupportOption(
              icon: Icons.phone_rounded,
              title: ref.lang('support.phone'),
              subtitle: '+998 90 123 45 67',
              color: AppTheme.success,
              onTap: () async {
                Navigator.pop(context);
                final url = Uri.parse('tel:+998901234567');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
            ),
            const SizedBox(height: 12),
            _SupportOption(
              icon: Icons.email_rounded,
              title: 'Email',
              subtitle: 'support@playpass.uz',
              color: AppTheme.primary,
              onTap: () async {
                Navigator.pop(context);
                final url = Uri.parse('mailto:support@playpass.uz');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SupportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SupportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: context.text1,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  Text(subtitle,
                      style: TextStyle(
                          color: context.text3, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isRu = locale == 'ru';

    return GestureDetector(
      onTap: () {
        final next = isRu ? 'uz' : 'ru';
        ref.read(localeProvider.notifier).state = next;
        SupabaseService().updateLanguage(next);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.language_rounded, color: context.text1, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(ref.lang('profile.language'), style: TextStyle(color: context.text1, fontSize: 15)),
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LangChip(label: 'RU', selected: isRu),
                  _LangChip(label: 'UZ', selected: !isRu),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    final IconData icon;
    final String label;
    if (themeMode == 'dark') {
      icon = Icons.dark_mode_rounded;
      label = ref.lang('profile.dark_theme');
    } else if (themeMode == 'light') {
      icon = Icons.light_mode_rounded;
      label = ref.lang('profile.light_theme');
    } else {
      icon = Icons.auto_awesome_rounded;
      label = 'Auto';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: Theme.of(context).textTheme.bodyLarge?.color, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ThemeChip(label: '\u2600\uFE0F', value: 'light', current: themeMode),
                _ThemeChip(label: '\uD83C\uDF19', value: 'dark', current: themeMode),
                _ThemeChip(label: '\u23F0', value: 'auto', current: themeMode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends ConsumerWidget {
  final String label;
  final String value;
  final String current;
  const _ThemeChip({required this.label, required this.value, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).setMode(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected ? const LinearGradient(colors: [AppTheme.primary, Color(0xFF6366F1)]) : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatItem({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: context.glass,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              color: context.text3,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _LangChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(colors: [AppTheme.primary, Color(0xFF6366F1)])
            : null,
        color: selected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : context.text3,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.text1;
    final iconColor = color ?? AppTheme.primaryLight;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (color ?? AppTheme.primary).withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            color: context.text3, fontSize: 12)),
                ],
              ),
            ),
            if (color == null)
              Icon(Icons.chevron_right_rounded,
                  color: context.text3, size: 20),
          ],
        ),
      ),
    );
  }
}
