import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/subscription.dart';
import '../../../models/club.dart';
import '../../../models/visit.dart';
import '../../../services/supabase_service.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/utils/savings_calculator.dart';
import '../../../core/widgets/neon_shimmer.dart';
import '../widgets/subscription_widget.dart';
import '../widgets/nearby_clubs_row.dart';
import '../widgets/recent_visits_widget.dart';
import '../widgets/active_session_widget.dart';
import '../widgets/banners_carousel.dart';
import '../widgets/streak_widget.dart';
import '../widgets/smart_hint_card.dart';
import '../widgets/friends_online_widget.dart';
import '../../stories/screens/stories_screen.dart';

// Providers — keep alive for 5 min after the last listener detaches.
// This avoids re-fetching when user rapidly navigates home → other tab → home.
const _kHomeCacheDuration = Duration(minutes: 5);

void _keepAliveFor(Ref ref, Duration duration) {
  final link = ref.keepAlive();
  Timer(duration, link.close);
}

final activeSubscriptionProvider = FutureProvider.autoDispose<Subscription?>((ref) async {
  _keepAliveFor(ref, _kHomeCacheDuration);
  return SupabaseService().getActiveSubscription();
});

// Home screen only shows 4 nearby club cards — no need to fetch all 276.
final nearbyClubsProvider = FutureProvider.autoDispose<List<Club>>((ref) async {
  _keepAliveFor(ref, _kHomeCacheDuration);
  return SupabaseService().getActiveClubs(limit: 15);
});

final recentVisitsProvider = FutureProvider.autoDispose<List<Visit>>((ref) async {
  _keepAliveFor(ref, _kHomeCacheDuration);
  return SupabaseService().getVisitHistory(limit: 3);
});

final activeSessionProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return SupabaseService().getActiveSession();
});

final unreadNotifCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return SupabaseService().getUnreadNotificationCount();
});

/// Personalized home feed cards (favorite club, comeback, time-suggest, expiring)
final homeRecommendationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  _keepAliveFor(ref, _kHomeCacheDuration);
  return SupabaseService().getHomeRecommendations();
});

/// Streak data: { streak_days: int, last_visit_date: DateTime? }
final streakProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  _keepAliveFor(ref, _kHomeCacheDuration);
  final userId = SupabaseService().currentUser?.id;
  if (userId == null) return {'streak_days': 0, 'last_visit_date': null};
  final profile = await SupabaseService().getUserProfile(userId);
  if (profile == null) return {'streak_days': 0, 'last_visit_date': null};
  final lastVisit = profile['last_visit_date'] as String?;
  return {
    'streak_days': profile['streak_days'] as int? ?? 0,
    'last_visit_date': lastVisit != null ? DateTime.tryParse(lastVisit) : null,
  };
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(activeSubscriptionProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ── Floating Gradient Orbs (atmospheric background) ──
          Positioned(
            top: -60,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.10),
                    AppTheme.primary.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.neonCyan.withValues(alpha: 0.08),
                    AppTheme.neonCyan.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 340,
            left: 60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // ── Main Content ────────────────────────────────────
          RefreshIndicator(
            color: AppTheme.primary,
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
                // ── App Bar ─────────────────────────────────────
                SliverAppBar(
                  floating: true,
                  pinned: false,
                  backgroundColor: context.bg,
                  title: Row(
                    children: [
                      // Logo with neon glow
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.neonCyan],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.sports_esports_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'PlayPass',
                        style: TextStyle(
                          color: context.text1,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    Consumer(builder: (context, ref, _) {
                      final count = ref.watch(unreadNotifCountProvider).valueOrNull ?? 0;
                      return IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(Icons.notifications_outlined, color: context.text1),
                            if (count > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: AppTheme.error.withValues(alpha: 0.4), blurRadius: 6)],
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () => context.push('/notifications'),
                      );
                    }),
                    const SizedBox(width: 4),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),

                      // ── Active session widget ─────────────────
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
                                  activeSessionLabel: ref.lang('home.active_session'),
                                  endSessionLabel: ref.lang('home.end_session'),
                                  clubDefault: ref.lang('common.club_default'),
                                  errorPrefix: ref.lang('common.error_prefix'),
                                  timeH: ref.lang('common.time_h'),
                                  timeM: ref.lang('common.time_m'),
                                  timeS: ref.lang('common.time_s'),
                                ),
                              )
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      // ── Subscription widget ────────────────────
                      subscriptionAsync.when(
                        data: (sub) => SubscriptionWidget(subscription: sub),
                        loading: () => const _SubscriptionSkeleton(),
                        error: (_, __) => const _SubscriptionError(),
                      ),

                      const SizedBox(height: 12),

                      // ── Streak widget ──────────────────────────
                      Consumer(
                        builder: (context, ref, _) {
                          final streakAsync = ref.watch(streakProvider);
                          return streakAsync.when(
                            data: (data) {
                              final days = data['streak_days'] as int? ?? 0;
                              if (days < 1) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: StreakWidget(
                                  streakDays: days,
                                  lastVisitDate: data['last_visit_date'] as DateTime?,
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          );
                        },
                      ),

                      // ── Smart Home Feed (personalized hints) ──
                      if (FeatureFlags.smartHomeFeed)
                        Consumer(
                          builder: (context, ref, _) {
                            final hintsAsync = ref.watch(homeRecommendationsProvider);
                            return hintsAsync.when(
                              data: (hints) {
                                if (hints.isEmpty) return const SizedBox.shrink();
                                return Column(
                                  children: hints.take(2).map((h) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: SmartHintCard(hint: h),
                                  )).toList(),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            );
                          },
                        ),

                      // ── Friends online widget ────────────────
                      if (FeatureFlags.friends) ...[
                        const FriendsOnlineWidget(),
                        const SizedBox(height: 12),
                      ],

                      // ── Savings indicator ──────────────────────
                      subscriptionAsync.when(
                        data: (sub) {
                          if (sub == null || !sub.isActive) return const SizedBox.shrink();
                          final hoursUsed = (sub.hoursTotal ?? 0) - (sub.hoursBalance ?? 0);
                          final saved = SavingsCalculator.calculate(
                            hoursUsed: hoursUsed,
                            plan: sub.plan,
                            subscriptionCost: sub.priceUzs,
                          );
                          if (saved <= 0) return const SizedBox.shrink();
                          return _SavingsWidget(saved: saved);
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),

                      // ── Scan Button ────────────────────────────
                      subscriptionAsync.when(
                        data: (sub) => _ScanButton(
                          hasActiveSubscription: sub?.isActive == true,
                          isFrozen: sub?.isFrozen == true,
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 20),

                      // ── Stories bubbles ────────────────────────
                      if (FeatureFlags.stories) ...[
                        const StoryBubbles(),
                        const SizedBox(height: 20),
                      ],

                      // ── Quick Actions (hidden until features enabled) ──
                      const _QuickActions(),
                      const SizedBox(height: 4),

                      // ── Banners ────────────────────────────────
                      const BannersCarousel(),
                      const SizedBox(height: 24),

                      // ── Nearby Clubs Section ───────────────────
                      _SectionHeader(
                        title: ref.lang('home.nearby'),
                        action: ref.lang('home.all'),
                        onAction: () => context.go('/clubs'),
                      ),
                      const SizedBox(height: 12),
                      NearbyClubsRow(clubsAsync: ref.watch(nearbyClubsProvider)),

                      const SizedBox(height: 28),

                      // ── Recent Visits Section ──────────────────
                      _SectionHeader(
                        title: ref.lang('home.recent'),
                        action: ref.lang('home.history'),
                        onAction: () => context.push('/profile/history'),
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
        ],
      ),
    );
  }
}

// ── Section Header ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;
  const _SectionHeader({required this.title, required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(
          color: context.text1,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        )),
        GestureDetector(
          onTap: onAction,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action, style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.primary, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Scan Button (CTA) ───────────────────────────────────────

class _ScanButton extends ConsumerStatefulWidget {
  final bool hasActiveSubscription;
  final bool isFrozen;
  const _ScanButton({required this.hasActiveSubscription, this.isFrozen = false});

  @override
  ConsumerState<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends ConsumerState<_ScanButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.hasActiveSubscription && !widget.isFrozen) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _ScanButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasActiveSubscription && !widget.isFrozen) {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canScan = widget.hasActiveSubscription && !widget.isFrozen;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (widget.isFrozen) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.lang('home.frozen'))),
          );
        } else if (widget.hasActiveSubscription) {
          context.go('/scanner');
        } else {
          context.push('/plans');
        }
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (_, __) {
          final pulse = canScan ? _pulseController.value : 0.0;
          return Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: canScan
                  ? const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF6366F1), Color(0xFF06B6D4)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: canScan ? null : context.card,
              borderRadius: BorderRadius.circular(16),
              border: canScan ? null : Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
              boxShadow: canScan
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35 + pulse * 0.25),
                        blurRadius: 20 + pulse * 16,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: AppTheme.neonCyan.withValues(alpha: 0.15 + pulse * 0.15),
                        blurRadius: 30 + pulse * 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : AppTheme.cardGlow(),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Inner shine highlight when active
                  if (canScan)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 28,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x1AFFFFFF),
                              Color(0x00FFFFFF),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Button content
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isFrozen
                              ? Icons.ac_unit_rounded
                              : widget.hasActiveSubscription
                                  ? Icons.qr_code_scanner_rounded
                                  : Icons.shopping_cart_outlined,
                          color: canScan ? Colors.white : context.text3,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.isFrozen
                              ? ref.lang('home.frozen')
                              : widget.hasActiveSubscription
                                  ? ref.lang('home.scan_qr')
                                  : ref.lang('home.buy_sub'),
                          style: TextStyle(
                            color: canScan ? Colors.white : context.text3,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (canScan) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Quick Actions Grid ──────────────────────────────────────

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tr(ref.watch(localeProvider));

    // Build the visible quick actions list based on FeatureFlags.
    // When a feature isn't ready for prod, its tile is just omitted.
    final all = <_QuickAction>[
      if (FeatureFlags.tournaments)
        _QuickAction(icon: Icons.emoji_events_rounded, label: t['home_tournaments'] ?? 'home_tournaments',
            color: AppTheme.warning, onTap: () => context.push('/tournaments')),
      if (FeatureFlags.lfg)
        _QuickAction(icon: Icons.people_rounded, label: t['home_lfg'] ?? 'home_lfg',
            color: AppTheme.neonBlue, onTap: () => context.push('/lfg')),
      if (FeatureFlags.leaderboard)
        _QuickAction(icon: Icons.leaderboard_rounded, label: t['home_leaderboard'] ?? 'home_leaderboard',
            color: AppTheme.neonPurple, onTap: () => context.push('/leaderboard')),
      if (FeatureFlags.stories)
        _QuickAction(icon: Icons.newspaper_rounded, label: t['home_news'] ?? 'home_news',
            color: AppTheme.success, onTap: () => context.push('/stories')),
      if (FeatureFlags.fullscreenMapShortcut)
        _QuickAction(icon: Icons.map_rounded, label: t['home_map'] ?? 'home_map',
            color: AppTheme.neonCyan, onTap: () => context.push('/clubs-map')),
      if (FeatureFlags.loyalty)
        _QuickAction(icon: Icons.star_rounded, label: t['home_loyalty'] ?? 'home_loyalty',
            color: AppTheme.tierVip, onTap: () => context.push('/loyalty')),
      if (FeatureFlags.playerStats)
        _QuickAction(icon: Icons.sports_esports_rounded, label: t['home_stats'] ?? 'home_stats',
            color: AppTheme.neonPink, onTap: () => context.push('/player-stats')),
      if (FeatureFlags.happyHours)
        _QuickAction(icon: Icons.local_offer_rounded, label: t['home_happy'] ?? 'home_happy',
            color: AppTheme.neonPurple, onTap: () => context.push('/happy-hours')),
    ];

    if (all.isEmpty) return const SizedBox.shrink();

    // Lay out in 2 rows of up to 4. If only one row, show one.
    final rows = <List<_QuickAction>>[];
    for (var i = 0; i < all.length; i += 4) {
      rows.add(all.sublist(i, i + 4 > all.length ? all.length : i + 4));
    }

    Widget rowFor(List<_QuickAction> items) {
      // Pad with empty slots so cards stay same size as a full row of 4
      final children = <Widget>[];
      for (var i = 0; i < items.length; i++) {
        if (i > 0) children.add(const SizedBox(width: 8));
        children.add(items[i]);
      }
      // Spacer slots for partial rows
      for (var i = items.length; i < 4; i++) {
        children.add(const SizedBox(width: 8));
        children.add(const Expanded(child: SizedBox.shrink()));
      }
      return SizedBox(height: 80, child: Row(children: children));
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          rowFor(rows[i]),
          if (i < rows.length - 1) const SizedBox(height: 8),
        ],
      ],
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
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            color: context.glass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.text2),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Savings Widget ─────────────────────────────────────────

class _SavingsWidget extends ConsumerWidget {
  final int saved;
  const _SavingsWidget({required this.saved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formattedSaved = SavingsCalculator.formatAmount(saved);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/savings');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.success.withValues(alpha: 0.08),
              AppTheme.neonCyan.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.savings_rounded, color: AppTheme.success, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.lang('home.you_saved'), style: TextStyle(color: context.text2, fontSize: 12)),
                  Text('$formattedSaved ${ref.lang('home.currency')}', style: const TextStyle(color: AppTheme.success, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.success.withValues(alpha: 0.6), size: 24),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton / Error States ─────────────────────────────────

class _SubscriptionSkeleton extends StatelessWidget {
  const _SubscriptionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const NeonSkeletonCard(height: 140, borderRadius: 20);
  }
}

class _SubscriptionError extends ConsumerWidget {
  const _SubscriptionError();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.gamingCard(glowColor: AppTheme.error),
      child: Text(ref.lang('common.error'), style: const TextStyle(color: AppTheme.error)),
    );
  }
}
