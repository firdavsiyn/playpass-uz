import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // The name was already captured on AuthScreen during registration
    // (sent via signUp data → DB trigger handle_new_user copies it to
    // public.users.name). If it's already set, skip this screen entirely.
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final metaName = (meta?['name'] as String?)?.trim() ?? '';
    if (metaName.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
      return;
    }
    _nameController.text = metaName;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Guard: user might land here right after signUp, before email is
    // confirmed. In that case there's no session and updateUserProfile
    // would throw "Not authenticated".
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Подтвердите email из письма, чтобы сохранить профиль'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService()
          .updateUserProfile(name: _nameController.text.trim());
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Text('Как вас зовут?',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Это имя будет отображаться в клубах при чекине',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: context.text1, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Введите имя',
                    prefixIcon:
                        Icon(Icons.person_outline, color: context.text3),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Введите имя';
                    if (v.trim().length < 2) return 'Слишком короткое имя';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Готово'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
