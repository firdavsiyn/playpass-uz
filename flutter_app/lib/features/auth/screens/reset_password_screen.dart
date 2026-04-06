import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _done = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      setState(() => _error = 'Минимум 8 символов');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      setState(() => _done = true);
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
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
          onPressed: () => context.go('/auth/login'),
        ),
        title: const Text('Новый пароль'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _done ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.lock_rounded, size: 56, color: AppTheme.primary),
        const SizedBox(height: 24),
        Text(
          'Введите новый пароль',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.text1,
              ),
        ),
        const SizedBox(height: 32),

        const Text('Новый пароль'),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _obscure1,
          style: TextStyle(color: context.text1, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Минимум 8 символов',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => _obscure1 = !_obscure1),
            ),
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 16),

        const Text('Подтвердите пароль'),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmController,
          obscureText: _obscure2,
          style: TextStyle(color: context.text1, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Повторите пароль',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => _obscure2 = !_obscure2),
            ),
          ),
          onSubmitted: (_) => _updatePassword(),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
        ],

        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _updatePassword,
          child: _loading
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Сохранить пароль'),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_rounded, size: 72, color: AppTheme.success),
        const SizedBox(height: 24),
        Text(
          'Пароль обновлён!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.text1,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Теперь вы можете войти с новым паролем.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.text2, fontSize: 14),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => context.go('/auth/login'),
          child: const Text('Войти'),
        ),
      ],
    );
  }
}
