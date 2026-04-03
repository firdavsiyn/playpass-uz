import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
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
      setState(() => _loginError = 'Введите email и пароль');
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
      setState(() => _loginError = 'Ошибка входа. Попробуйте снова.');
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
      setState(() => _regError = 'Имя должно быть не менее 2 символов');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _regError = 'Введите корректный email');
      return;
    }
    if (password.length < 8) {
      setState(() => _regError = 'Пароль должен быть не менее 8 символов');
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
        setState(() => _regError = 'Не удалось создать аккаунт');
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
      setState(() => _regError = 'Ошибка регистрации. Попробуйте снова.');
    } finally {
      if (mounted) setState(() => _regLoading = false);
    }
  }

  String _mapAuthError(String msg) {
    if (msg.contains('Invalid login credentials')) {
      return 'Неверный email или пароль';
    }
    if (msg.contains('User already registered')) {
      return 'Этот email уже зарегистрирован. Войдите.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Подтвердите email (проверьте почту)';
    }
    if (msg.contains('rate limit')) {
      return 'Слишком много попыток. Подождите.';
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
                'Добро пожаловать\nв PlayPass',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.3,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Один абонемент — 50+ клубов Ташкента',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
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
                  unselectedLabelColor: AppTheme.textSecondary,
                  dividerHeight: 0,
                  tabs: const [
                    Tab(text: 'Войти'),
                    Tab(text: 'Создать аккаунт'),
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
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'your@email.com',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            onChanged: (_) => setState(() => _loginError = null),
          ),
          const SizedBox(height: 16),

          Text('Пароль', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _loginPassword,
            obscureText: !_loginPasswordVisible,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Минимум 8 символов',
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
              child: const Text('Забыли пароль?',
                  style: TextStyle(fontSize: 13)),
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
                  : const Text('Войти'),
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
          Text('Имя', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _regName,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Ваше имя',
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
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'your@email.com',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            onChanged: (_) => setState(() => _regError = null),
          ),
          const SizedBox(height: 16),

          Text('Пароль', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _regPassword,
            obscureText: !_regPasswordVisible,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Минимум 8 символов',
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
                  : const Text('Зарегистрироваться'),
            ),
          ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              'Нажимая кнопку, вы соглашаетесь\nс Условиями использования',
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
