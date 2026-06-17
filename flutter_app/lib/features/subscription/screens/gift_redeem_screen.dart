import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_backdrop.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../services/supabase_service.dart';

class GiftRedeemScreen extends ConsumerStatefulWidget {
  const GiftRedeemScreen({super.key});

  @override
  ConsumerState<GiftRedeemScreen> createState() => _GiftRedeemScreenState();
}

class _GiftRedeemScreenState extends ConsumerState<GiftRedeemScreen> {
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
      setState(() => _error = ref.lang('gift.enter_prompt'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gift = await SupabaseService().getGiftByCode(code);
      if (gift == null) {
        setState(() => _error = ref.lang('gift.not_found'));
      } else if (gift['status'] != 'paid') {
        setState(() => _error = ref.lang('gift.invalid_used'));
      } else {
        setState(() => _giftInfo = gift);
      }
    } catch (e) {
      setState(() => _error = '${ref.lang('gift.error_prefix')}$e');
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
      appBar: AppBar(title: Text(ref.lang('gift.redeem_title'))),
      body: GlassBackdrop(
        child: _success ? _buildSuccess() : _buildForm(),
      ),
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
            ref.lang('gift.enter_code'),
            style: TextStyle(
              color: context.text1,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            ref.lang('gift.redeem_subtitle'),
            style: TextStyle(color: context.text2, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: 'ABCD1234',
              hintStyle: TextStyle(
                color: context.text3,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
              filled: true,
              fillColor: context.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 14)),
          ],
          if (_giftInfo != null) ...[
            const SizedBox(height: 16),
            GlassSurface(
              strong: true,
              radius: 16,
              padding: const EdgeInsets.all(16),
              borderColor: AppTheme.success.withValues(alpha: 0.2),
              child: Column(
                children: [
                  Text(
                    '${ref.lang('gift.plan_label')}${_giftInfo!['plan'] ?? ''}',
                    style: TextStyle(
                        color: context.text1, fontWeight: FontWeight.w600),
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
                borderRadius: BorderRadius.circular(14),
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_giftInfo != null
                        ? ref.lang('gift.activate')
                        : ref.lang('gift.check')),
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
                boxShadow:
                    AppTheme.neonGlow(color: AppTheme.success, radius: 20),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              ref.lang('gift.activated'),
              style: TextStyle(
                color: context.text1,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ref.lang('gift.sub_added'),
              style: TextStyle(color: context.text2),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: Text(ref.lang('gift.home')),
            ),
          ],
        ),
      ),
    );
  }
}
