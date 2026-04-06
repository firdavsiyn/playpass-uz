import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../services/supabase_service.dart';

final notifPrefsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return SupabaseService().getNotificationPrefs();
});

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  final _svc = SupabaseService();
  Map<String, bool> _prefs = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final data = await _svc.getNotificationPrefs();
      setState(() {
        _prefs = {
          'push_enabled': data['push_enabled'] as bool? ?? true,
          'promo_enabled': data['promo_enabled'] as bool? ?? true,
          'tournament_enabled': data['tournament_enabled'] as bool? ?? true,
          'subscription_enabled': data['subscription_enabled'] as bool? ?? true,
          'club_news_enabled': data['club_news_enabled'] as bool? ?? true,
        };
        _loaded = true;
      });
    } catch (_) {
      setState(() => _loaded = true);
    }
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _prefs[key] = value);
    await _svc.updateNotificationPrefs({key: value});
  }

  @override
  Widget build(BuildContext context) {
    final t = tr(ref.watch(localeProvider));

    return Scaffold(
      appBar: AppBar(title: Text(t['notif_title'] ?? 'Уведомления')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Master toggle
                _ToggleCard(
                  icon: Icons.notifications_active,
                  title: t['notif_push'] ?? 'Push-уведомления',
                  subtitle: t['notif_push_desc'] ?? 'Получать уведомления на устройство',
                  value: _prefs['push_enabled'] ?? true,
                  onChanged: (v) => _toggle('push_enabled', v),
                  isPrimary: true,
                ),
                const SizedBox(height: 8),

                if (_prefs['push_enabled'] == true) ...[
                  const SizedBox(height: 8),
                  Text(t['notif_categories'] ?? 'Категории',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                  const SizedBox(height: 12),

                  _ToggleCard(
                    icon: Icons.local_offer,
                    title: t['notif_promo'] ?? 'Акции и скидки',
                    subtitle: t['notif_promo_desc'] ?? 'Новые промокоды и спецпредложения',
                    value: _prefs['promo_enabled'] ?? true,
                    onChanged: (v) => _toggle('promo_enabled', v),
                  ),
                  _ToggleCard(
                    icon: Icons.emoji_events,
                    title: t['notif_tournaments'] ?? 'Турниры',
                    subtitle: t['notif_tournaments_desc'] ?? 'Новые турниры и результаты',
                    value: _prefs['tournament_enabled'] ?? true,
                    onChanged: (v) => _toggle('tournament_enabled', v),
                  ),
                  _ToggleCard(
                    icon: Icons.card_membership,
                    title: t['notif_subscription'] ?? 'Подписка',
                    subtitle: t['notif_subscription_desc'] ?? 'Истечение, заморозка, продление',
                    value: _prefs['subscription_enabled'] ?? true,
                    onChanged: (v) => _toggle('subscription_enabled', v),
                  ),
                  _ToggleCard(
                    icon: Icons.newspaper,
                    title: t['notif_news'] ?? 'Новости клубов',
                    subtitle: t['notif_news_desc'] ?? 'Новые публикации от клубов',
                    value: _prefs['club_news_enabled'] ?? true,
                    onChanged: (v) => _toggle('club_news_enabled', v),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isPrimary;

  const _ToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary && value ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (value ? AppTheme.primary : AppTheme.textMuted).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: value ? AppTheme.primary : AppTheme.textMuted, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
