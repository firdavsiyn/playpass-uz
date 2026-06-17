import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/subscription.dart';
import '../../../models/club.dart';
import '../../../models/visit.dart';
import '../../../core/cache/subscription_cache.dart';
import '../../../services/supabase_service.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/widgets/glow_card.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/glass_backdrop.dart';
import '../../../core/widgets/dot_number.dart';
import '../../../core/widgets/mini_wave.dart';
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

/// Stale-while-revalidate provider for the active subscription.
/// On cold start we first yield the disk-cached value (instant paint),
/// then fetch fresh from Supabase and yield that. The home widget
/// `.when(data: …)` sees both as `data` so the card renders immediately
/// without any visible loading state.
final activeSubscriptionProvider =
    StreamProvider.autoDispose<Subscription?>((ref) async* {
  _keepAliveFor(ref, _kHomeCacheDuration);
  // 1) Disk cache (fast path) — no network, ~5–15 ms.
  final cached = await SubscriptionCache.read();
  if (cached != null) yield cached;
  // 2) Fresh fetch — overwrites cache via SupabaseService.
  try {
    final fresh = await SupabaseService().getActiveSubscription();
    yield fresh;
  } catch (e) {
    // If we already showed a cached value, swallow the error — user sees
    // last-known plan; the next reload will retry. Only rethrow when we
    // have nothing to show.
    if (cached == null) rethrow;
  }
});

// Home screen only shows 4 nearby club cards — no need to fetch all 276.
final nearbyClubsProvider = FutureProvider.autoDispose<List<Club>>((ref) async {
  _keepAliveFor(ref, _kHomeCacheDuration);
  return SupabaseService().getActiveClubs(limit: 15);
});

final recentVisitsProvider =
    FutureProvider.autoDispose<List<Visit>>((ref) async {
  _keepAliveFor(ref, _kHomeCacheDuration);
  return SupabaseService().getVisitHistory(limit: 3);
});

final activeSessionProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return SupabaseService().getActiveSession();
});

final unreadNotifCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return SupabaseService().getUnreadNotificationCount();
});

/// Personalized home feed cards (favorite club, comeback, time-suggest, expiring)
final homeRecommendationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  _keepAliveFor(ref, _kHomeCacheDuration);
  return SupabaseService().getHomeRecommendations();
});

/// Streak data: { streak_days: int, last_visit_date: DateTime? }
final streakProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
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
      // ── Main Content ────────────────────────────────────
      // GlassBackdrop paints the static aurora field so every frosted surface
      // (and the nav blur) has navy light to lens, instead of flat grey film.
      body: GlassBackdrop(
        child: RefreshIndicator(
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
                        child: Icon(Icons.sports_esports_rounded,
                            color: Colors.white, size: 20),
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
                    final count =
                        ref.watch(unreadNotifCountProvider).valueOrNull ?? 0;
                    return IconButton(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Icons.notifications_outlined,
                              color: context.text1),
                          if (count > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppTheme.error
                                            .withValues(alpha: 0.4),
                                        blurRadius: 6)
                                  ],
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 16, minHeight: 16),
                                child: Text(
                                  count > 99 ? '99+' : '$count',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700),
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

                    // ════════════════════════════════════════════
                    // ABOVE THE FOLD — utility-first
                    // ════════════════════════════════════════════

                    // ── 1. Active session widget (genuine utility) ──
                    // Only renders when a session is live.
                    ref.watch(activeSessionProvider).when(
                          data: (session) => session != null
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: ActiveSessionWidget(
                                    session: session,
                                    onEnded: () {
                                      ref.invalidate(activeSessionProvider);
                                      ref.invalidate(
                                          activeSubscriptionProvider);
                                    },
                                    activeSessionLabel:
                                        ref.lang('home.active_session'),
                                    endSessionLabel:
                                        ref.lang('home.end_session'),
                                    clubDefault:
                                        ref.lang('common.club_default'),
                                    errorPrefix:
                                        ref.lang('common.error_prefix'),
                                    timeH: ref.lang('common.time_h'),
                                    timeM: ref.lang('common.time_m'),
                                    timeS: ref.lang('common.time_s'),
                                  ),
                                )
                              : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),

                    // ── 2. Bento dashboard (glow cards + dot-matrix) ──
                    subscriptionAsync.when(
                      data: (sub) => _BentoDashboard(subscription: sub),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const _SubscriptionError(),
                    ),

                    const SizedBox(height: 24),

                    // ════════════════════════════════════════════
                    // (Scan moved out of home — the floating scan
                    //  button in the bottom nav is the single entry.)
                    // ════════════════════════════════════════════

                    // ── 4. Nearby Clubs Section (gated) ─────────
                    // Render the whole section only when clubs exist;
                    // otherwise emit nothing (no header, no "all →").
                    ref.watch(nearbyClubsProvider).when(
                          data: (clubs) => clubs.isEmpty
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _SectionHeader(
                                      title: ref.lang('home.nearby'),
                                      action: ref.lang('home.all'),
                                      onAction: () => context.go('/clubs'),
                                    ),
                                    const SizedBox(height: 12),
                                    NearbyClubsRow(
                                        clubsAsync:
                                            ref.watch(nearbyClubsProvider)),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),

                    // ── 5. Recent Visits Section ───────────────
                    _SectionHeader(
                      title: ref.lang('home.recent'),
                      action: ref.lang('home.history'),
                      onAction: () => context.push('/profile/history'),
                    ),
                    const SizedBox(height: 12),
                    RecentVisitsWidget(
                        visitsAsync: ref.watch(recentVisitsProvider)),

                    const SizedBox(height: 24),

                    // ── 6. Streak widget (engagement — demoted) ──
                    Consumer(
                      builder: (context, ref, _) {
                        final streakAsync = ref.watch(streakProvider);
                        return streakAsync.when(
                          data: (data) {
                            final days = data['streak_days'] as int? ?? 0;
                            if (days < 1) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: StreakWidget(
                                streakDays: days,
                                lastVisitDate:
                                    data['last_visit_date'] as DateTime?,
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),

                    // ── 7. Smart Home Feed (engagement — demoted) ──
                    if (FeatureFlags.smartHomeFeed)
                      Consumer(
                        builder: (context, ref, _) {
                          final hintsAsync =
                              ref.watch(homeRecommendationsProvider);
                          return hintsAsync.when(
                            data: (hints) {
                              if (hints.isEmpty) return const SizedBox.shrink();
                              return Column(
                                children: hints
                                    .take(2)
                                    .map((h) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: SmartHintCard(hint: h),
                                        ))
                                    .toList(),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          );
                        },
                      ),

                    // (Savings indicator removed from home.)

                    // ── 9. Friends online widget (social — demoted) ──
                    if (FeatureFlags.friends) ...[
                      const FriendsOnlineWidget(),
                      const SizedBox(height: 16),
                    ],

                    // ════════════════════════════════════════════
                    // MARKETING — very bottom (each self-hides empty)
                    // ════════════════════════════════════════════

                    // ── 10. Stories bubbles ────────────────────
                    if (FeatureFlags.stories) ...[
                      const StoryBubbles(),
                      const SizedBox(height: 16),
                    ],

                    // ── 11. Quick Actions ──────────────────────
                    const _QuickActions(),
                    const SizedBox(height: 16),

                    // ── 12. Banners ────────────────────────────
                    const BannersCarousel(),

                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;
  const _SectionHeader(
      {required this.title, required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
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
              Text(action,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.primary, size: 18),
            ],
          ),
        ),
      ],
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
        _QuickAction(
            icon: Icons.emoji_events_rounded,
            label: t['home_tournaments'] ?? 'home_tournaments',
            color: AppTheme.warning,
            onTap: () => context.push('/tournaments')),
      if (FeatureFlags.lfg)
        _QuickAction(
            icon: Icons.people_rounded,
            label: t['home_lfg'] ?? 'home_lfg',
            color: AppTheme.neonBlue,
            onTap: () => context.push('/lfg')),
      if (FeatureFlags.leaderboard)
        _QuickAction(
            icon: Icons.leaderboard_rounded,
            label: t['home_leaderboard'] ?? 'home_leaderboard',
            color: AppTheme.neonPurple,
            onTap: () => context.push('/leaderboard')),
      if (FeatureFlags.stories)
        _QuickAction(
            icon: Icons.newspaper_rounded,
            label: t['home_news'] ?? 'home_news',
            color: AppTheme.success,
            onTap: () => context.push('/stories')),
      if (FeatureFlags.fullscreenMapShortcut)
        _QuickAction(
            icon: Icons.map_rounded,
            label: t['home_map'] ?? 'home_map',
            color: AppTheme.neonCyan,
            onTap: () => context.push('/clubs-map')),
      if (FeatureFlags.loyalty)
        _QuickAction(
            icon: Icons.star_rounded,
            label: t['home_loyalty'] ?? 'home_loyalty',
            color: AppTheme.tierVip,
            onTap: () => context.push('/loyalty')),
      if (FeatureFlags.playerStats)
        _QuickAction(
            icon: Icons.sports_esports_rounded,
            label: t['home_stats'] ?? 'home_stats',
            color: AppTheme.neonPink,
            onTap: () => context.push('/player-stats')),
      if (FeatureFlags.happyHours)
        _QuickAction(
            icon: Icons.local_offer_rounded,
            label: t['home_happy'] ?? 'home_happy',
            color: AppTheme.neonPurple,
            onTap: () => context.push('/happy-hours')),
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
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassSurface(
        strong: true,
        radius: 14,
        padding: EdgeInsets.zero,
        borderColor: color.withValues(alpha: 0.18),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
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
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.text2),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── Error State (skeletons removed in favour of empty space) ─

class _SubscriptionError extends ConsumerWidget {
  const _SubscriptionError();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.invalidate(activeSubscriptionProvider),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.gamingCard(glowColor: AppTheme.error),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppTheme.error, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Нет связи с сервером. Нажмите, чтобы повторить.',
                style: TextStyle(color: context.text2, fontSize: 13),
              ),
            ),
            Icon(Icons.refresh_rounded,
                color: AppTheme.error.withValues(alpha: 0.7), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Bento dashboard (glow cards + dot-matrix numerals) ──────
class _BentoDashboard extends ConsumerWidget {
  final Subscription? subscription;
  const _BentoDashboard({required this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = subscription;

    // No active subscription → lime CTA card.
    if (sub == null || !sub.isActive) {
      return GlowCard(
        glass: true,
        glowColor: AppTheme.accent,
        glowAt: const Alignment(-0.4, -0.3),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GlowCardLabel('Подписка'),
            const SizedBox(height: 10),
            Text(
              'Нет активной',
              style: TextStyle(
                color: context.text1,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/plans'),
                child: const Text('Оформить'),
              ),
            ),
          ],
        ),
      );
    }

    final isInf = sub.isUnlimited;
    final visits = sub.hoursBalance ?? 0;
    final streakDays =
        (ref.watch(streakProvider).valueOrNull?['streak_days'] as int?) ?? 0;
    final glow = isInf ? AppTheme.accent : AppTheme.primary;

    return Column(
      children: [
        // Hero — visits remaining as dot-matrix + live wave (frosted glass)
        GlowCard(
          glass: true,
          glowColor: glow,
          glowAt: const Alignment(0.7, -0.2),
          height: 188,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          onTap: () => context.go('/subscription'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PlanBadge(sub: sub),
                  const SizedBox(width: 10),
                  Text(
                    sub.isFrozen ? 'Заморожена' : 'Активна',
                    style: TextStyle(color: context.text2, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '${sub.daysRemaining} дн.',
                    style: TextStyle(
                      color: context.text2,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RepaintBoundary(
                    child: DotMatrixNumber(
                      isInf ? '∞' : '$visits',
                      dotSize: 7,
                      color: AppTheme.accent,
                      glow: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      isInf ? 'безлимит' : 'визитов',
                      style: TextStyle(color: context.text2, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const RepaintBoundary(child: MiniWave(height: 26, glow: true)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Bento stat tiles
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Стрик',
                value: '$streakDays',
                unit: 'дней',
                glow: AppTheme.accent,
                glowAt: const Alignment(-0.3, 0.4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Осталось',
                value: '${sub.daysRemaining}',
                unit: 'дней',
                glow: AppTheme.primary,
                glowAt: const Alignment(0.4, 0.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final Subscription sub;
  const _PlanBadge({required this.sub});

  @override
  Widget build(BuildContext context) {
    final c = sub.isUnlimited ? AppTheme.accent : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Text(
        sub.planName.toUpperCase(),
        style: TextStyle(
          color: c,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color glow;
  final Alignment glowAt;
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.glow,
    required this.glowAt,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glass: true,
      strong: true,
      glowColor: glow,
      glowAt: glowAt,
      height: 118,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlowCardLabel(label),
          const Spacer(),
          DotMatrixNumber(value, dotSize: 5, color: context.text1),
          const SizedBox(height: 6),
          Text(unit, style: TextStyle(color: context.text2, fontSize: 12)),
        ],
      ),
    );
  }
}
