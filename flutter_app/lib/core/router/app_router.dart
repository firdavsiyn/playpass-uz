import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../monitoring/sentry_setup.dart';
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
import '../../features/profile/screens/notifications_screen.dart';
import '../../features/profile/screens/savings_screen.dart';
import '../../features/gaming/screens/player_stats_screen.dart';
import '../../features/gaming/screens/lfg_screen.dart';
import '../../features/gaming/screens/leaderboard_screen.dart';
import '../../features/gaming/screens/happy_hours_screen.dart';
import '../../models/subscription.dart';

/// Tracks the currently active bottom-nav tab index.
/// Scanner screen watches this to stop/start the camera.
final activeTabIndexProvider = StateProvider<int>((ref) => 0);

/// Notifier that triggers GoRouter to re-evaluate redirects when auth changes.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      final user = authState.session?.user;
      if (user != null) {
        AppMonitoring.setUser(id: user.id, email: user.email);
        AppMonitoring.addBreadcrumb('Auth: ${authState.event.name}', category: 'auth');
      } else {
        AppMonitoring.clearUser();
      }
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

      // Notifications
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/savings', builder: (_, __) => const SavingsScreen()),

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

    void onTap(int index) {
      HapticFeedback.lightImpact();
      ref.read(activeTabIndexProvider.notifier).state = index;
      shell.goBranch(
        index,
        initialLocation: index == shell.currentIndex,
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // --- Glassmorphism bottom nav ---
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: context.navBg.withValues(alpha: 0.85),
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  currentIndex: shell.currentIndex,
                  onTap: onTap,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: AppTheme.primary,
                  unselectedItemColor: context.text3,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 11),
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home_outlined, size: 24),
                      activeIcon: const _NeonIcon(icon: Icons.home_rounded),
                      label: s['nav.home']!,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.map_outlined, size: 24),
                      activeIcon: const _NeonIcon(icon: Icons.map_rounded),
                      label: s['nav.clubs']!,
                    ),
                    // Invisible placeholder — the real button is the floating overlay
                    BottomNavigationBarItem(
                      icon: const SizedBox(height: 24, width: 24),
                      activeIcon: const SizedBox(height: 24, width: 24),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.card_membership_outlined, size: 24),
                      activeIcon:
                          const _NeonIcon(icon: Icons.card_membership_rounded),
                      label: s['nav.subscription']!,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.person_outline_rounded, size: 24),
                      activeIcon: const _NeonIcon(icon: Icons.person_rounded),
                      label: s['nav.profile']!,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Floating Scanner Button ---
          Positioned(
            top: -16,
            child: _ScannerButton(
              active: shell.currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Active tab icon — primary-colored icon with a small dot indicator below.
class _NeonIcon extends StatelessWidget {
  final IconData icon;
  const _NeonIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.primary, size: 24),
        const SizedBox(height: 4),
        Container(
          width: 4,
          height: 3,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.6),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Floating elevated scanner button with gradient and glow.
class _ScannerButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _ScannerButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7C3AED),
              Color(0xFF6366F1),
              Color(0xFF06B6D4),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: active ? 0.6 : 0.35),
              blurRadius: active ? 20 : 14,
              spreadRadius: active ? 2 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.qr_code_scanner_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
