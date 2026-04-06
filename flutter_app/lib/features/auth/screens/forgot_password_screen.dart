import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';

/// Экран восстановления пароля через email
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Введите корректный email');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://playpass-app.vercel.app/#/auth/reset-password',
      );
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = 'Не удалось отправить письмо. Проверьте email.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        title: const Text('Восстановление пароля'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _sent ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.lock_reset_rounded, size: 56, color: AppTheme.primary),
        const SizedBox(height: 24),
        Text(
          'Забыли пароль?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.text1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Введите email, указанный при регистрации. '
          'Мы отправим ссылку для сброса пароля.',
          style: TextStyle(color: context.text2, fontSize: 14),
        ),
        const SizedBox(height: 32),

        Text('Email', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: context.text1, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'your@email.com',
            prefixIcon: Icon(Icons.email_outlined, size: 20),
          ),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _sendResetEmail(),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13)),
        ],

        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _sendResetEmail,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Отправить ссылку'),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mark_email_read_rounded,
            size: 72, color: AppTheme.success),
        const SizedBox(height: 24),
        Text(
          'Письмо отправлено!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.text1,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Проверьте почту ${_emailController.text.trim()} '
          'и перейдите по ссылке для сброса пароля.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.text2, fontSize: 14),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('Вернуться ко входу'),
        ),
      ],
    );
  }
}
