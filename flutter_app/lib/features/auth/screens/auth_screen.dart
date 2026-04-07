import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../services/supabase_service.dart';

/// Экран авторизации MVP — Email + Пароль (Tabs: Войти / Создать аккаунт)
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regName.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    super.dispose();
  }

  // ── Вход ──────────────────────────────────────────────────
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

  // ── Регистрация ───────────────────────────────────────────
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
      // 1. Создаём пользователя в Supabase Auth
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (response.user == null) {
        setState(() => _regError = ref.lang('auth.create_error'));
        return;
      }

      // 2. Сразу логиним (signUp в Supabase автоматически логинит)
      // 3. Обновляем профиль в public.users
      try {
        await SupabaseService().updateUserProfile(name: name);
      } catch (_) {
        // Профиль может создаться через trigger — не критично
      }

      // 4. Отправляем на онбординг
      if (mounted) {
        context.go('/auth/onboarding');
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Logo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.neonPurple, AppTheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.neonGlow(radius: 20),
                ),
                child: const Icon(Icons.sports_esports, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),

              Text(
                ref.lang('auth.welcome'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: context.text1,
                      height: 1.3,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                ref.lang('auth.tagline'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.neonPurple, AppTheme.primary],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: context.text2,
                  dividerHeight: 0,
                  tabs: [
                    Tab(text: ref.lang('auth.tab_login')),
                    Tab(text: ref.lang('auth.tab_register')),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Tab content
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
    );
  }

  // ── LOGIN FORM ────────────────────────────────────────────
  Widget _buildLoginForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Email', style: Theme.of(context).textTheme.bodyMedium),
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

          Text(ref.lang('auth.password'), style: Theme.of(context).textTheme.bodyMedium),
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
                  _loginPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _loginPasswordVisible = !_loginPasswordVisible),
              ),
            ),
            onSubmitted: (_) => _login(),
          ),

          if (_loginError != null) ...[
            const SizedBox(height: 12),
            Text(_loginError!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13)),
          ],

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/auth/forgot-password'),
              child: Text(ref.lang('auth.forgot'),
                  style: const TextStyle(fontSize: 13)),
            ),
          ),

          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: !_loginLoading
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: ElevatedButton(
              onPressed: (!_loginLoading) ? _login : null,
              child: _loginLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(ref.lang('auth.login_btn')),
            ),
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
          Text(ref.lang('auth.name'), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _regName,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: context.text1, fontSize: 16),
            decoration: InputDecoration(
              hintText: ref.lang('auth.name_hint'),
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            onChanged: (_) => setState(() => _regError = null),
          ),
          const SizedBox(height: 16),

          Text('Email', style: Theme.of(context).textTheme.bodyMedium),
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

          Text(ref.lang('auth.password'), style: Theme.of(context).textTheme.bodyMedium),
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

          if (_regError != null) ...[
            const SizedBox(height: 12),
            Text(_regError!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13)),
          ],

          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: !_regLoading
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: ElevatedButton(
              onPressed: (!_regLoading) ? _register : null,
              child: _regLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(ref.lang('auth.register_btn')),
            ),
          ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              ref.lang('auth.terms'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
