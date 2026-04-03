import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/subscription.dart';
import '../../../models/club.dart';
import '../../../models/visit.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/subscription_widget.dart';
import '../widgets/nearby_clubs_row.dart';
import '../widgets/recent_visits_widget.dart';
import '../widgets/active_session_widget.dart';

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
          ref.invalidate(activeSubscriptionProvider);
          ref.invalidate(nearbyClubsProvider);
          ref.invalidate(recentVisitsProvider);
          ref.invalidate(activeSessionProvider);
        },
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              pinned: false,
              backgroundColor: AppTheme.bgDark,
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
                  onPressed: () {},
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

                  const SizedBox(height: 28),

                  // Nearby clubs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ближайшие клубы',
                          style: Theme.of(context).textTheme.titleMedium),
                      TextButton(
                        onPressed: () => context.go('/clubs'),
                        child: const Text('Все', style: TextStyle(color: AppTheme.primary)),
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
                      Text('Последние визиты',
                          style: Theme.of(context).textTheme.titleMedium),
                      TextButton(
                        onPressed: () => context.push('/profile/history'),
                        child: const Text('История', style: TextStyle(color: AppTheme.primary)),
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

class _ScanButton extends StatelessWidget {
  final bool hasActiveSubscription;
  final bool isFrozen;
  const _ScanButton({required this.hasActiveSubscription, this.isFrozen = false});

  @override
  Widget build(BuildContext context) {
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
                  ? 'Подписка заморожена'
                  : hasActiveSubscription
                      ? 'Сканировать QR'
                      : 'Купить подписку',
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
