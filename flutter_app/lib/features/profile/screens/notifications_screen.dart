import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/neon_shimmer.dart';

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return SupabaseService().getNotifications();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          TextButton(
            onPressed: () async {
              await SupabaseService().markAllNotificationsRead();
              ref.invalidate(notificationsProvider);
            },
            child: Text('Прочитать все', style: TextStyle(color: AppTheme.neonCyan, fontSize: 13)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(notificationsProvider.future);
        },
        child: notifsAsync.when(
          data: (notifs) {
            if (notifs.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_off_rounded, size: 64, color: context.text3.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('Нет уведомлений', style: TextStyle(color: context.text3, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: notifs.length,
              itemBuilder: (_, i) => _NotificationTile(
                notif: notifs[i],
                onTap: () async {
                  final id = notifs[i]['id'] as String?;
                  if (id != null && notifs[i]['is_read'] != true) {
                    await SupabaseService().markNotificationRead(id);
                    ref.invalidate(notificationsProvider);
                  }
                },
              ),
            );
          },
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(5, (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeonSkeletonCard(height: 72, borderRadius: 14),
              )),
            ),
          ),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  final VoidCallback onTap;
  const _NotificationTile({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = notif['title'] as String? ?? '';
    final body = notif['body'] as String? ?? '';
    final isRead = notif['is_read'] as bool? ?? false;
    final createdAt = DateTime.tryParse(notif['created_at'] as String? ?? '')?.toLocal();
    final timeAgo = createdAt != null ? _formatTimeAgo(createdAt) : '';
    final event = notif['event'] as String? ?? '';

    IconData icon;
    Color iconColor;
    switch (event) {
      case 'admin_broadcast':
        icon = Icons.campaign_rounded;
        iconColor = AppTheme.primary;
        break;
      case 'subscription_expiry':
        icon = Icons.timer_rounded;
        iconColor = AppTheme.warning;
        break;
      case 'achievement':
        icon = Icons.emoji_events_rounded;
        iconColor = AppTheme.tierVip;
        break;
      case 'promo':
        icon = Icons.local_offer_rounded;
        iconColor = AppTheme.neonCyan;
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = AppTheme.primaryLight;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? context.card : context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? context.border.withValues(alpha: 0.2)
                : AppTheme.primary.withValues(alpha: 0.2),
          ),
          boxShadow: isRead ? [] : AppTheme.cardGlow(),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: context.text1,
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 6)],
                          ),
                        ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.text2, fontSize: 13)),
                  ],
                  const SizedBox(height: 4),
                  Text(timeAgo, style: TextStyle(color: context.text3, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
  }
}
