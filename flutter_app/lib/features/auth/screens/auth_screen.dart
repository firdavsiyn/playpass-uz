import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';

/// Dramatic gaming-style auth screen
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _glowController;
  late AnimationController _bgController;

  // Login fields
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  bool _loginLoading = false;
  String? _loginError;
  bool _loginPasswordVisible = false;

  // Register fields
  final _regName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();
  bool _regLoading = false;
  String? _regError;
  bool _regPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _glowController.dispose();
    _bgController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regName.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    super.dispose();
  }

  // ── Login ────────────────────────────────────────────────
  Future<void> _login() async {
    final email = _loginEmail.text.trim();
    final password = _loginPassword.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _loginError = ref.lang('auth.enter_email_pass'));
      return;
    }

    setState(() {
      _loginLoading = true;
      _loginError = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final seen = prefs.getBool('onboarding_seen') ?? false;
        context.go(seen ? '/home' : '/auth/onboarding');
      }
    } on AuthException catch (e) {
      setState(() => _loginError = _mapAuthError(e.message));
    } catch (e) {
      setState(() => _loginError = ref.lang('auth.login_error'));
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  // ── Register ─────────────────────────────────────────────
  Future<void> _register() async {
    final name = _regName.text.trim();
    final email = _regEmail.text.trim();
    final password = _regPassword.text;

    if (name.length < 2) {
      setState(() => _regError = ref.lang('auth.name_short'));
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _regError = ref.lang('auth.email_invalid'));
      return;
    }
    if (password.length < 8) {
      setState(() => _regError = ref.lang('auth.pass_short'));
      return;
    }

    setState(() {
      _regLoading = true;
      _regError = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (response.user == null) {
        setState(() => _regError = ref.lang('auth.create_error'));
        return;
      }

      // NOTE: don't call updateUserProfile / grantWelcomeBonus here.
      // When email confirmation is required, signUp returns a user but NOT a
      // session — so currentUser is null and any RLS-protected write throws
      // "Not authenticated". The DB trigger `handle_new_user` already copies
      // {data: {name: ...}} into public.users.name. Welcome bonus is granted
      // on first authenticated home-screen visit.

      if (mounted) {
        // If Supabase returned a session (email confirmation disabled),
        // route to onboarding/home. Otherwise show check-email guidance.
        final hasSession = response.session != null;
        if (hasSession) {
          context.go('/auth/onboarding');
        } else {
          setState(() => _regError = ref.lang('auth.confirm_email'));
          // Stay on the auth screen so user can switch to login tab once
          // they've confirmed via email.
        }
      }
    } on AuthException catch (e) {
      setState(() => _regError = _mapAuthError(e.message));
    } catch (e) {
      setState(() => _regError = ref.lang('auth.reg_error'));
    } finally {
      if (mounted) setState(() => _regLoading = false);
    }
  }

  String _mapAuthError(String msg) {
    if (msg.contains('Invalid login credentials')) {
      return ref.lang('auth.wrong_creds');
    }
    if (msg.contains('User already registered')) {
      return ref.lang('auth.already_reg');
    }
    if (msg.contains('Email not confirmed')) {
      return ref.lang('auth.confirm_email');
    }
    if (msg.contains('rate limit')) {
      return ref.lang('auth.rate_limit');
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Animated background orbs ───────────────────────
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) {
              final angle = _bgController.value * 2 * math.pi;
              return Stack(
                children: [
                  // Top-right orb — purple, larger & more dramatic
                  Positioned(
                    top: -80 + math.sin(angle) * 30,
                    right: -60 + math.cos(angle) * 20,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.primary.withValues(alpha: 0.12),
                            AppTheme.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom-left orb — cyan
                  Positioned(
                    bottom: 100 + math.cos(angle) * 25,
                    left: -40 + math.sin(angle) * 15,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.neonCyan.withValues(alpha: 0.08),
                            AppTheme.neonCyan.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Center-right orb — neonPink accent
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.4,
                    right: -20 + math.sin(angle + 1.5) * 18,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.neonPink.withValues(alpha: 0.06),
                            AppTheme.neonPink.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Main content ───────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // ── Animated Logo ──────────────────────────
                  Center(
                    child: AnimatedBuilder(
                      animation: _glowController,
                      builder: (_, child) {
                        final glow = 0.3 + _glowController.value * 0.4;
                        return Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.neonCyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: glow),
                                blurRadius: 40,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.sports_esports_rounded,
                              color: Colors.white, size: 42),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ──────────────────────────────────
                  Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          AppTheme.primaryLight,
                          AppTheme.neonLavender,
                          AppTheme.neonCyan,
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'PLAYPASS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      ref.lang('auth.tagline'),
                      style: TextStyle(
                        color: context.text2,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Tab Bar ────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.1)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.indigo],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: context.text3,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      dividerHeight: 0,
                      tabs: [
                        Tab(text: ref.lang('auth.tab_login')),
                        Tab(text: ref.lang('auth.tab_register')),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Tab Content ────────────────────────────
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLoginForm(),
                        _buildRegisterForm(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gradient Button ────────────────────────────────────────
  Widget _gradientButton({
    required String label,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: loading
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onTap();
            },
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (_, __) {
          final glow = loading ? 0.0 : 0.2 + _glowController.value * 0.3;
          return Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: loading
                  ? null
                  : const LinearGradient(
                      colors: [
                        AppTheme.primary,
                        AppTheme.indigo,
                        AppTheme.neonCyan,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              color: loading ? context.surface : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: loading
                  ? []
                  : [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: glow),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // Glossy inner highlight overlay
                  if (!loading)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 27,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppTheme.primaryLight),
                          )
                        : Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
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

  // ── LOGIN FORM ────────────────────────────────────────────
  Widget _buildLoginForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _inputLabel('Email'),
          const SizedBox(height: 8),
          TextField(
            controller: _loginEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: context.text1, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'your@email.com',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            onChanged: (_) => setState(() => _loginError = null),
          ),
          const SizedBox(height: 16),
          _inputLabel(ref.lang('auth.password')),
          const SizedBox(height: 8),
          TextField(
            controller: _loginPassword,
            obscureText: !_loginPasswordVisible,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: context.text1, fontSize: 16),
            decoration: InputDecoration(
              hintText: ref.lang('auth.password_hint'),
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _loginPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                  size: 20,
                ),
                onPressed: () => setState(
                    () => _loginPasswordVisible = !_loginPasswordVisible),
              ),
            ),
            onSubmitted: (_) => _login(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _loginError != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_loginError!,
                                style: const TextStyle(
                                    color: AppTheme.error, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/auth/forgot-password'),
              child: Text(ref.lang('auth.forgot'),
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.primaryLight)),
            ),
          ),
          const SizedBox(height: 24),
          _gradientButton(
            label: ref.lang('auth.login_btn'),
            loading: _loginLoading,
            onTap: _login,
          ),
        ],
      ),
    );
  }

  // ── REGISTER FORM ─────────────────────────────────────────
  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _inputLabel(ref.lang('auth.name')),
          const SizedBox(height: 8),
          TextField(
            controller: _regName,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: context.text1, fontSize: 16),
            decoration: InputDecoration(
              hintText: ref.lang('auth.name_hint'),
              prefixIcon: const Icon(Icons.person_outline, size: 20),
            ),
            onChanged: (_) => setState(() => _regError = null),
          ),
          const SizedBox(height: 16),
          _inputLabel('Email'),
          const SizedBox(height: 8),
          TextField(
            controller: _regEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: context.text1, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'your@email.com',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            onChanged: (_) => setState(() => _regError = null),
          ),
          const SizedBox(height: 16),
          _inputLabel(ref.lang('auth.password')),
          const SizedBox(height: 8),
          TextField(
            controller: _regPassword,
            obscureText: !_regPasswordVisible,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: context.text1, fontSize: 16),
            decoration: InputDecoration(
              hintText: ref.lang('auth.password_hint'),
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _regPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _regPasswordVisible = !_regPasswordVisible),
              ),
            ),
            onSubmitted: (_) => _register(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _regError != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_regError!,
                                style: const TextStyle(
                                    color: AppTheme.error, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _gradientButton(
            label: ref.lang('auth.register_btn'),
            loading: _regLoading,
            onTap: _register,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              ref.lang('auth.terms'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.text3, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _inputLabel(String text) {
    return Text(text,
        style: TextStyle(
          color: context.text3,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ));
  }
}
