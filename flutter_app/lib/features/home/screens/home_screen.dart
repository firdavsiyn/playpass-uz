import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/subscription.dart';
import '../../../models/club.dart';
import '../../../models/visit.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/widgets/neon_shimmer.dart';
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
                    IconButton(
                      icon: Icon(Icons.notifications_outlined, color: context.text2, size: 22),
                      onPressed: () => context.push('/notifications-settings'),
                    ),
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

                      const SizedBox(height: 20),

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
                      const StoryBubbles(),
                      const SizedBox(height: 20),

                      // ── Quick Actions ──────────────────────────
                      const _QuickActions(),
                      const SizedBox(height: 20),

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
    return Column(
      children: [
        SizedBox(
          height: 80,
          child: Row(
            children: [
              _QuickAction(icon: Icons.emoji_events_rounded, label: t['home_tournaments'] ?? 'Турниры',
                  color: AppTheme.warning, onTap: () => context.push('/tournaments')),
              const SizedBox(width: 8),
              _QuickAction(icon: Icons.people_rounded, label: t['home_lfg'] ?? 'Тиммейты',
                  color: AppTheme.neonBlue, onTap: () => context.push('/lfg')),
              const SizedBox(width: 8),
              _QuickAction(icon: Icons.leaderboard_rounded, label: t['home_leaderboard'] ?? 'Рейтинг',
                  color: AppTheme.neonPurple, onTap: () => context.push('/leaderboard')),
              const SizedBox(width: 8),
              _QuickAction(icon: Icons.newspaper_rounded, label: t['home_news'] ?? 'Новости',
                  color: AppTheme.success, onTap: () => context.push('/stories')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: Row(
            children: [
              _QuickAction(icon: Icons.map_rounded, label: t['home_map'] ?? 'Карта',
                  color: AppTheme.neonCyan, onTap: () => context.push('/clubs-map')),
              const SizedBox(width: 8),
              _QuickAction(icon: Icons.star_rounded, label: t['home_loyalty'] ?? 'XP',
                  color: AppTheme.tierVip, onTap: () => context.push('/loyalty')),
              const SizedBox(width: 8),
              _QuickAction(icon: Icons.sports_esports_rounded, label: t['home_stats'] ?? 'Профили',
                  color: AppTheme.neonPink, onTap: () => context.push('/player-stats')),
              const SizedBox(width: 8),
              _QuickAction(icon: Icons.local_offer_rounded, label: t['home_happy'] ?? 'Скидки',
                  color: AppTheme.neonPurple, onTap: () => context.push('/happy-hours')),
            ],
          ),
        ),
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
        onTap: onTap,
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
