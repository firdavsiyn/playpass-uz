import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class GiftPurchaseScreen extends ConsumerStatefulWidget {
  const GiftPurchaseScreen({super.key});

  @override
  ConsumerState<GiftPurchaseScreen> createState() => _GiftPurchaseScreenState();
}

class _GiftPurchaseScreenState extends ConsumerState<GiftPurchaseScreen> {
  String _selectedPlan = 'standard';
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _giftCode;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  PlanConfig get _plan => AppConstants.plans[_selectedPlan]!;

  Future<void> _createGift() async {
    setState(() => _loading = true);
    try {
      final code = await SupabaseService().createGiftCertificate(
        plan: _selectedPlan,
        amountUzs: _plan.priceUzs,
        recipientName:
            _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        recipientPhone:
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      setState(() => _giftCode = code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${ref.lang('gift.error_prefix')}$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ref.lang('gift.buy_title'))),
      body: _giftCode != null ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildForm() {
    final plans = AppConstants.plans.values.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Plan selector
        Text(ref.lang('gift.choose_plan'),
            style: TextStyle(
                color: context.text1,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: plans.map((p) {
            final selected = p.id == _selectedPlan;
            final color = _planColor(p.id);
            return GestureDetector(
              onTap: () => setState(() => _selectedPlan = p.id),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.15)
                      : context.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? color : context.border),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: color.withValues(alpha: 0.2),
                              blurRadius: 8)
                        ]
                      : [],
                ),
                child: Text(p.name,
                    style: TextStyle(
                        color: selected ? color : context.text3,
                        fontWeight: FontWeight.w600)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          '${_formatPrice(_plan.priceUzs)} UZS  ·  ${_plan.isUnlimited ? ref.lang('gift.unlimited_short') : "${_plan.hours} ${ref.lang('gift.hours_short')}"}',
          style: TextStyle(color: context.text2, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Recipient info
        Text(ref.lang('gift.for_whom'),
            style: TextStyle(
                color: context.text1,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(ref.lang('gift.optional'),
            style: TextStyle(color: context.text3, fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          style: TextStyle(color: context.text1),
          decoration: InputDecoration(
              hintText: ref.lang('gift.name'),
              prefixIcon: const Icon(Icons.person_outline, size: 20)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: context.text1),
          decoration: InputDecoration(
              hintText: ref.lang('gift.phone'),
              prefixIcon: const Icon(Icons.phone_outlined, size: 20)),
        ),
        const SizedBox(height: 32),

        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12)
            ],
          ),
          child: ElevatedButton(
            onPressed: _loading ? null : _createGift,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(ref
                    .lang('gift.create_price')
                    .replaceFirst('{price}', _formatPrice(_plan.priceUzs))),
          ),
        ),
      ],
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
              child: const Icon(Icons.card_giftcard_rounded,
                  color: AppTheme.success, size: 36),
            ),
            const SizedBox(height: 24),
            Text(ref.lang('gift.success'),
                style: TextStyle(
                    color: context.text1,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(ref.lang('gift.share'),
                style: TextStyle(color: context.text2)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                boxShadow: AppTheme.neonGlow(radius: 16),
              ),
              child: Column(
                children: [
                  Text(
                    _giftCode!,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4),
                  ),
                  const SizedBox(height: 8),
                  Text('${_plan.name} · ${_formatPrice(_plan.priceUzs)} UZS',
                      style: TextStyle(color: context.text2, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _giftCode!));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ref.lang('gift.code_copied'))));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(ref.lang('gift.copy')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: ref
                            .lang('gift.share_text')
                            .replaceFirst('{code}', _giftCode!),
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ref.lang('gift.text_copied'))));
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(ref.lang('gift.share_btn')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
                onPressed: () => context.go('/home'),
                child: Text(ref.lang('gift.home'))),
          ],
        ),
      ),
    );
  }

  Color _planColor(String id) => AppTheme.planColor(id);

  String _formatPrice(int p) {
    final s = p.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
