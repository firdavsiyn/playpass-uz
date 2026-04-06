import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class GiftRedeemScreen extends StatefulWidget {
  const GiftRedeemScreen({super.key});

  @override
  State<GiftRedeemScreen> createState() => _GiftRedeemScreenState();
}

class _GiftRedeemScreenState extends State<GiftRedeemScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _success = false;
  String? _error;
  Map<String, dynamic>? _giftInfo;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 6) {
      setState(() => _error = 'Введите код сертификата');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gift = await SupabaseService().getGiftByCode(code);
      if (gift == null) {
        setState(() => _error = 'Сертификат не найден');
      } else if (gift['status'] != 'paid') {
        setState(() => _error = 'Сертификат уже использован или недействителен');
      } else {
        setState(() => _giftInfo = gift);
      }
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeem() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SupabaseService().redeemGiftCertificate(_codeCtrl.text.trim());
      setState(() => _success = true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Активировать сертификат')),
      body: _success ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.primary.withValues(alpha: 0.2),
                AppTheme.neonPurple.withValues(alpha: 0.15),
              ]),
              shape: BoxShape.circle,
              boxShadow: AppTheme.neonGlow(radius: 20),
            ),
            child: const Icon(Icons.card_giftcard_rounded,
                color: AppTheme.primaryLight, size: 36),
          ),
          const SizedBox(height: 24),
          Text(
            'Введите код подарочного сертификата',
            style: TextStyle(
              color: context.text1,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Код можно получить от друга или приобрести в разделе "Подарить подписку"',
            style: TextStyle(color: context.text2, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.primaryLight,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: 'ABCD1234',
              hintStyle: TextStyle(
                color: context.text3.withValues(alpha: 0.3),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
              filled: true,
              fillColor: context.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 14)),
          ],
          if (_giftInfo != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'Тариф: ${_giftInfo!['plan'] ?? ''}',
                    style: TextStyle(color: context.text1, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_giftInfo!['amount_uzs'] ?? 0} UZS',
                    style: TextStyle(color: context.text2, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : _giftInfo != null
                        ? _redeem
                        : _checkCode,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_giftInfo != null ? 'Активировать' : 'Проверить код'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.success.withValues(alpha: 0.2),
                  AppTheme.neonCyan.withValues(alpha: 0.15),
                ]),
                shape: BoxShape.circle,
                boxShadow: AppTheme.neonGlow(color: AppTheme.success, radius: 20),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'Сертификат активирован!',
              style: TextStyle(
                color: context.text1,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Подписка добавлена к вашему аккаунту',
              style: TextStyle(color: context.text2),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('На главную'),
            ),
          ],
        ),
      ),
    );
  }
}
