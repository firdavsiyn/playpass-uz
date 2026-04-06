import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/subscription.dart';
import '../../../models/club.dart';
import '../../../models/visit.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../widgets/subscription_widget.dart';
import '../widgets/nearby_clubs_row.dart';
import '../widgets/recent_visits_widget.dart';
import '../widgets/active_session_widget.dart';
import '../widgets/banners_carousel.dart';
import '../../stories/screens/stories_screen.dart';

// Providers
final activeSubscriptionProvider = FutureProvider<Subscription?>((ref) async {
  return SupabaseService().getActiveSubscription();
});

final nearbyClubsProvider = FutureProvider<List<Club>>((ref) async {
  return SupabaseService().getActiveClubs();
});

final recentVisitsProvider = FutureProvider<List<Visit>>((ref) async {
  final visits = await SupabaseService().getVisitHistory();
  return visits.take(3).toList();
});

final activeSessionProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return SupabaseService().getActiveSession();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(activeSubscriptionProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(activeSubscriptionProvider.future),
            ref.refresh(nearbyClubsProvider.future),
            ref.refresh(recentVisitsProvider.future),
            ref.refresh(activeSessionProvider.future),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              pinned: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.neonPurple, AppTheme.primary],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.sports_esports, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text('PlayPass'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push('/notifications-settings'),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),

                  // Active session widget
                  ref.watch(activeSessionProvider).when(
                    data: (session) => session != null
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ActiveSessionWidget(
                              session: session,
                              onEnded: () {
                                ref.invalidate(activeSessionProvider);
                                ref.invalidate(activeSubscriptionProvider);
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // Subscription widget
                  subscriptionAsync.when(
                    data: (sub) => SubscriptionWidget(subscription: sub),
                    loading: () => const _SubscriptionSkeleton(),
                    error: (_, __) => const _SubscriptionError(),
                  ),

                  const SizedBox(height: 24),

                  // Scan button
                  subscriptionAsync.when(
                    data: (sub) => _ScanButton(
                      hasActiveSubscription: sub?.isActive == true,
                      isFrozen: sub?.isFrozen == true,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),

                  // Stories bubbles
                  const StoryBubbles(),
                  const SizedBox(height: 12),

                  // Quick actions
                  const _QuickActions(),
                  const SizedBox(height: 16),

                  // Banners carousel
                  const BannersCarousel(),
                  const SizedBox(height: 20),

                  // Nearby clubs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ref.lang('home.nearby'),
                          style: Theme.of(context).textTheme.titleMedium),
                      TextButton(
                        onPressed: () => context.go('/clubs'),
                        child: Text(ref.lang('home.all'), style: const TextStyle(color: AppTheme.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  NearbyClubsRow(clubsAsync: ref.watch(nearbyClubsProvider)),

                  const SizedBox(height: 28),

                  // Recent visits
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ref.lang('home.recent'),
                          style: Theme.of(context).textTheme.titleMedium),
                      TextButton(
                        onPressed: () => context.push('/profile/history'),
                        child: Text(ref.lang('home.history'), style: const TextStyle(color: AppTheme.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RecentVisitsWidget(visitsAsync: ref.watch(recentVisitsProvider)),

                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends ConsumerWidget {
  final bool hasActiveSubscription;
  final bool isFrozen;
  const _ScanButton({required this.hasActiveSubscription, this.isFrozen = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canScan = hasActiveSubscription && !isFrozen;

    return GestureDetector(
      onTap: () {
        if (isFrozen) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Подписка заморожена. Разморозьте в профиле.')),
          );
        } else if (hasActiveSubscription) {
          context.go('/scanner');
        } else {
          context.push('/plans');
        }
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: canScan
              ? const LinearGradient(
                  colors: [AppTheme.neonPurple, AppTheme.primary, AppTheme.neonBlue],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: canScan ? null : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: canScan
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppTheme.neonPurple.withValues(alpha: 0.2),
                    blurRadius: 40,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFrozen
                  ? Icons.ac_unit_rounded
                  : hasActiveSubscription
                      ? Icons.qr_code_scanner_rounded
                      : Icons.shopping_cart_outlined,
              color: canScan ? Colors.white : AppTheme.textMuted,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              isFrozen
                  ? ref.lang('home.frozen')
                  : hasActiveSubscription
                      ? ref.lang('home.scan_qr')
                      : ref.lang('home.buy_sub'),
              style: TextStyle(
                color: canScan ? Colors.white : AppTheme.textMuted,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tr(ref.watch(localeProvider));
    return SizedBox(
      height: 80,
      child: Row(
        children: [
          _QuickAction(icon: Icons.emoji_events, label: t['home_tournaments'] ?? 'Турниры',
              color: AppTheme.warning, onTap: () => context.push('/tournaments')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.map, label: t['home_map'] ?? 'Карта',
              color: AppTheme.neonBlue, onTap: () => context.push('/clubs-map')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.star, label: t['home_loyalty'] ?? 'XP',
              color: AppTheme.neonPurple, onTap: () => context.push('/loyalty')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.newspaper, label: t['home_news'] ?? 'Новости',
              color: AppTheme.success, onTap: () => context.push('/stories')),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionSkeleton extends StatelessWidget {
  const _SubscriptionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _SubscriptionError extends StatelessWidget {
  const _SubscriptionError();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text('Ошибка загрузки подписки', style: TextStyle(color: AppTheme.error)),
    );
  }
}
