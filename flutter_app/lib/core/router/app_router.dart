import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';

import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/profile_setup_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/scanner/screens/qr_scanner_screen.dart';
import '../../features/clubs/screens/clubs_list_screen.dart';
import '../../features/clubs/screens/club_detail_screen.dart';
import '../../features/subscription/screens/my_subscription_screen.dart';
import '../../features/subscription/screens/plans_screen.dart';
import '../../features/subscription/screens/payment_screen.dart';
import '../../features/subscription/screens/upsell_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/visit_history_screen.dart';
import '../../features/profile/screens/referral_screen.dart';
import '../../features/profile/screens/freeze_screen.dart';
import '../../features/profile/screens/favorites_screen.dart';
import '../../features/profile/screens/achievements_screen.dart';
import '../../features/subscription/screens/gift_purchase_screen.dart';
import '../../features/subscription/screens/gift_redeem_screen.dart';
import '../../features/booking/screens/booking_screen.dart';
import '../../features/tournaments/screens/tournaments_screen.dart';
import '../../features/tournaments/screens/tournament_detail_screen.dart';
import '../../features/stories/screens/stories_screen.dart';
import '../../features/loyalty/screens/loyalty_screen.dart';
import '../../features/clubs/screens/clubs_map_screen.dart';
import '../../features/profile/screens/notification_settings_screen.dart';
import '../../features/gaming/screens/player_stats_screen.dart';
import '../../features/gaming/screens/lfg_screen.dart';
import '../../features/gaming/screens/leaderboard_screen.dart';
import '../../features/gaming/screens/happy_hours_screen.dart';
import '../../models/subscription.dart';

/// Notifier that triggers GoRouter to re-evaluate redirects when auth changes.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

final _authNotifier = _AuthChangeNotifier();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isAuth = user != null;
      final isAuthRoute = state.fullPath?.startsWith('/auth') ?? false;

      if (!isAuth && !isAuthRoute) return '/auth/login';
      final isResetPassword = state.fullPath == '/auth/reset-password';
      if (isAuth && !isResetPassword && (state.fullPath == '/' || isAuthRoute)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/home'),

      // Auth flow — Email + Пароль
      GoRoute(path: '/auth/login', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/auth/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/auth/reset-password', builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(path: '/auth/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/auth/profile-setup', builder: (_, __) => const ProfileSetupScreen()),

      // Main shell with bottom nav
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/clubs',
              builder: (_, __) => const ClubsListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => ClubDetailScreen(
                    clubId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/scanner', builder: (_, __) => const QrScannerScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/subscription', builder: (_, __) => const MySubscriptionScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
              routes: [
                GoRoute(path: 'history', builder: (_, __) => const VisitHistoryScreen()),
                GoRoute(path: 'referral', builder: (_, __) => const ReferralScreen()),
                GoRoute(path: 'favorites', builder: (_, __) => const FavoritesScreen()),
                GoRoute(path: 'achievements', builder: (_, __) => const AchievementsScreen()),
                GoRoute(
                  path: 'freeze',
                  redirect: (_, state) => state.extra is Subscription ? null : '/profile',
                  builder: (_, state) => FreezeScreen(
                    subscription: state.extra as Subscription,
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),

      // Subscription
      GoRoute(path: '/plans', builder: (_, __) => const PlansScreen()),
      GoRoute(
        path: '/payment',
        redirect: (_, state) => state.extra is String ? null : '/plans',
        builder: (_, state) => PaymentScreen(plan: state.extra as String),
      ),
      GoRoute(
        path: '/upsell',
        redirect: (_, state) => state.extra is Map<String, String> ? null : '/plans',
        builder: (_, state) => UpsellScreen(
          extra: state.extra as Map<String, String>,
        ),
      ),

      // Gift certificates
      GoRoute(path: '/gift/purchase', builder: (_, __) => const GiftPurchaseScreen()),
      GoRoute(path: '/gift/redeem', builder: (_, __) => const GiftRedeemScreen()),

      // Booking
      GoRoute(path: '/booking', builder: (_, __) => const BookingScreen()),

      // Tournaments
      GoRoute(path: '/tournaments', builder: (_, __) => const TournamentsScreen()),
      GoRoute(path: '/tournaments/:id', builder: (_, state) => TournamentDetailScreen(tournamentId: state.pathParameters['id']!)),

      // Stories / News
      GoRoute(path: '/stories', builder: (_, __) => const StoriesScreen()),

      // Loyalty
      GoRoute(path: '/loyalty', builder: (_, __) => const LoyaltyScreen()),

      // Club Map
      GoRoute(path: '/clubs-map', builder: (_, __) => const ClubsMapScreen()),

      // Notification Settings
      GoRoute(path: '/notifications-settings', builder: (_, __) => const NotificationSettingsScreen()),

      // Gaming
      GoRoute(path: '/player-stats', builder: (_, __) => const PlayerStatsScreen()),
      GoRoute(path: '/lfg', builder: (_, __) => const LfgScreen()),
      GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
      GoRoute(path: '/happy-hours', builder: (_, __) => const HappyHoursScreen()),
    ],
  );
});

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const MainShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(localeProvider);
    final s = tr(t);

    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          border: Border(
            top: BorderSide(
              color: AppTheme.primary.withValues(alpha: 0.1),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: shell.currentIndex,
          onTap: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: _NeonIcon(icon: Icons.home),
                label: s['nav.home']!),
            BottomNavigationBarItem(
                icon: const Icon(Icons.map_outlined),
                activeIcon: _NeonIcon(icon: Icons.map),
                label: s['nav.clubs']!),
            BottomNavigationBarItem(
                icon: const Icon(Icons.qr_code_scanner),
                activeIcon: _NeonIcon(icon: Icons.qr_code_scanner),
                label: s['nav.scan']!),
            BottomNavigationBarItem(
                icon: const Icon(Icons.card_membership_outlined),
                activeIcon: _NeonIcon(icon: Icons.card_membership),
                label: s['nav.subscription']!),
            BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: _NeonIcon(icon: Icons.person),
                label: s['nav.profile']!),
          ],
        ),
      ),
    );
  }
}

class _NeonIcon extends StatelessWidget {
  final IconData icon;
  const _NeonIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(icon, color: AppTheme.primary),
    );
  }
}
