import 'package:flutter/material.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(ref.lang('profile.title'))),
      body: profileAsync.when(
        data: (profile) => _ProfileContent(
          profile: profile,
          subscription: subAsync.valueOrNull,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
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
    final name = profile?['name'] as String? ?? 'Геймер';
    final avatarUrl = profile?['avatar_url'] as String?;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final referralCode = profile?['referral_code'] as String? ?? '';
    final level = profile?['level'] as String? ?? 'novice';
    final totalVisits = profile?['total_visits'] as int? ?? 0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),

        // Avatar + Name + Email
        Row(
          children: [
            Stack(
              children: [
                AppAvatar.large(imageUrl: avatarUrl, name: name),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _pickAndUploadAvatar(context, ref),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.bgDark, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(email,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Level card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
            boxShadow: AppTheme.cardGlow(),
          ),
          child: Row(
            children: [
              Text(AppConstants.levelIcon(level), style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.levelLabel(level),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$totalVisits ${ref.lang('profile.visits_total')}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (referralCode.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    referralCode,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Subscription card
        if (subscription != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              boxShadow: AppTheme.neonGlow(radius: 16),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Подписка: ${subscription!.planName}',
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'До ${subscription!.endDate.day}.${subscription!.endDate.month.toString().padLeft(2, '0')}.${subscription!.endDate.year}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/plans'),
                  child: const Text('Продлить'),
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
          title: 'Турниры',
          subtitle: 'Соревнуйтесь с другими игроками',
          onTap: () => context.push('/tournaments'),
        ),
        _MenuItem(
          icon: Icons.star_rounded,
          title: 'Программа лояльности',
          subtitle: 'XP, уровни и привилегии',
          onTap: () => context.push('/loyalty'),
        ),
        _MenuItem(
          icon: Icons.notifications_rounded,
          title: 'Уведомления',
          subtitle: 'Настройки push-уведомлений',
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
            subtitle: '${subscription!.freezeDaysLeft} дн. доступно',
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
          onTap: () => _showSupportSheet(context),
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
              color: AppTheme.textMuted.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Future<void> _pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image == null) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Загрузка фото...')),
        );
      }

      final bytes = await image.readAsBytes();
      await SupabaseService().uploadAvatar(bytes.toList(), image.name);
      ref.invalidate(profileProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото обновлено!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  void _showChangeNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.15)),
        ),
        title: const Text('Изменить имя',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Ваше имя',
            prefixIcon: Icon(Icons.person_outline, size: 20),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Имя должно быть не менее 2 символов')),
                  );
                  return;
                }
                Navigator.pop(context);
                try {
                  await SupabaseService().updateUserProfile(name: newName);
                  ref.invalidate(profileProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Имя изменено на "$newName"')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e')),
                    );
                  }
                }
              },
              child: const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
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
                color: AppTheme.textMuted.withValues(alpha: 0.3),
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
            const Text(
              'Служба поддержки',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Мы на связи ежедневно с 10:00 до 22:00',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
              title: 'Телефон',
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
          color: AppTheme.bgSurface,
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
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 13)),
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
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            const Icon(Icons.language_rounded, color: AppTheme.textPrimary, size: 22),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Язык / Til', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
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
    final isDark = ref.watch(themeModeProvider) == 'dark';

    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).toggle(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: Theme.of(context).textTheme.bodyLarge?.color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(isDark ? 'Тёмная тема' : 'Светлая тема',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 15)),
            ),
            Switch(
              value: isDark,
              activeColor: AppTheme.primary,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            ),
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
        color: selected ? AppTheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppTheme.textMuted,
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
    final c = color ?? AppTheme.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: c, fontSize: 15)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (color == null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
