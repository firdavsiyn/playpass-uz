import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

/// Экран оплаты MVP — ручной перевод + заявка
class PaymentScreen extends ConsumerStatefulWidget {
  final String plan;
  const PaymentScreen({super.key, required this.plan});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  int _step = 0; // 0 = инструкция, 1 = форма заявки, 2 = отправлено

  // Form fields
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  bool _submitting = false;
  String? _error;

  /// Which provider's button is in-flight ('click' / 'rahmat' / null).
  /// Used to show a spinner inside the right button and disable the others.
  String? _payingProvider;

  /// Nullable lookup — an unknown plan code must NOT crash the screen
  /// (grey screen). `build` guards on this before any `_plan` use.
  PlanConfig? get _planOrNull => AppConstants.plans[widget.plan];
  PlanConfig get _plan => _planOrNull!;

  @override
  void dispose() {
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = ref.lang('pay.enter_phone'));
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await SupabaseService().createSubscriptionRequest(
        plan: widget.plan,
        amountUzs: _plan.priceUzs,
        userPhone: phone,
        paymentNote: _noteController.text.trim(),
      );
      setState(() => _step = 2);
    } catch (e) {
      setState(() => _error = ref.lang('pay.send_error'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Open an online payment session in the system browser.
  /// Edge Function returns a payment URL → we launch it externally.
  /// When the user finishes paying, the provider posts to our webhook
  /// which activates the subscription; the user then returns to the app
  /// and sees the active subscription.
  Future<void> _startOnlinePayment(String provider) async {
    if (_payingProvider != null) return;
    setState(() => _payingProvider = provider);
    try {
      final session = await SupabaseService().startOnlinePayment(
        provider: provider,
        plan: widget.plan,
      );
      final uri = Uri.parse(session.paymentUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw const PaymentException('Не удалось открыть браузер');
    } on PaymentException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка платежа: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _payingProvider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Backstop: unknown plan code (e.g. a new tariff not yet in the map)
    // must show a clean message, not a grey crash from `_plan!`.
    if (_planOrNull == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => context.pop(),
          ),
          title: Text(ref.lang('pay.title')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded,
                    color: AppTheme.error, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Тариф «${widget.plan}» временно недоступен',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.text2, fontSize: 14),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Назад'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        title: Text(_step == 2
            ? ref.lang('pay.request_sent_title')
            : ref.lang('pay.title')),
      ),
      body: SafeArea(
        child: switch (_step) {
          0 => _buildPaymentInstruction(),
          1 => _buildRequestForm(),
          2 => _buildConfirmation(),
          _ => const SizedBox(),
        },
      ),
    );
  }

  // ── ШАГ 0: Инструкция по оплате ──────────────────────────
  Widget _buildPaymentInstruction() {
    final priceFormatted = '${(_plan.priceUzs ~/ 1000)} 000';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ref.lang('pay.plan_label')}${_plan.name}',
                        style: TextStyle(
                          color: context.text1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _plan.isUnlimited
                            ? ref.lang('pay.unlimited_desc')
                            : ref
                                .lang('pay.hours_desc')
                                .replaceFirst('{n}', '${_plan.hours}'),
                        style: TextStyle(color: context.text2, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$priceFormatted UZS',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Online payment buttons (Click / Rahmat) ──────────
          // These call our Edge Functions; if a provider isn't configured
          // yet (e.g. credentials still in onboarding), the button shows
          // a friendly error and the user falls through to manual transfer.
          _OnlinePayButton(
            provider: 'click',
            label: 'Оплатить через Click',
            colors: const [Color(0xFF00A4D8), Color(0xFF006EA8)],
            icon: Icons.payment_rounded,
            onPressed: _payingProvider == null
                ? () => _startOnlinePayment('click')
                : null,
            isLoading: _payingProvider == 'click',
          ),
          const SizedBox(height: 10),
          _OnlinePayButton(
            provider: 'rahmat',
            label: 'Оплатить через Rahmat',
            colors: const [Color(0xFFE6533C), Color(0xFFB7341F)],
            icon: Icons.qr_code_2_rounded,
            onPressed: _payingProvider == null
                ? () => _startOnlinePayment('rahmat')
                : null,
            isLoading: _payingProvider == 'rahmat',
          ),

          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: Divider(color: context.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'или вручную',
                style: TextStyle(color: context.text3, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: context.border)),
          ]),
          const SizedBox(height: 20),

          // Payment instructions
          Text(
            ref.lang('pay.how_to_pay'),
            style: TextStyle(
              color: context.text1,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Option 1: Payme
          _PaymentOption(
            icon: Icons.phone_android,
            title: ref.lang('pay.via_payme'),
            subtitle: ref
                .lang('pay.transfer_to_phone')
                .replaceFirst('{amount}', priceFormatted),
            value: AppConstants.paymentPaymePhone,
            onCopy: () => _copyToClipboard(AppConstants.paymentPaymePhone),
          ),
          const SizedBox(height: 12),

          // Option 2: Card
          _PaymentOption(
            icon: Icons.credit_card,
            title: ref.lang('pay.via_card'),
            subtitle: ref
                .lang('pay.transfer_to_card')
                .replaceFirst('{amount}', priceFormatted),
            value: AppConstants.paymentCardNumber,
            onCopy: () => _copyToClipboard(AppConstants.paymentCardNumber),
          ),
          const SizedBox(height: 12),

          // Receiver name
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: context.text3),
                const SizedBox(width: 10),
                Text(
                  '${ref.lang('pay.recipient')}${AppConstants.paymentCardHolder}',
                  style: TextStyle(color: context.text2, fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Important note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: AppTheme.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ref.lang('pay.after_transfer_note'),
                    style: TextStyle(color: context.text2, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 1),
              child: Text(ref.lang('pay.i_paid'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── ШАГ 1: Форма заявки ──────────────────────────────────
  Widget _buildRequestForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref.lang('pay.confirm_title'),
            style: TextStyle(
              color: context.text1,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ref.lang('pay.confirm_desc'),
            style: TextStyle(color: context.text2, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Text(ref.lang('pay.phone_label'),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: context.text1, fontSize: 16),
            decoration: InputDecoration(
              hintText: '+998 90 123 45 67',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 16),
          Text(ref.lang('pay.comment_label'),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 3,
            style: TextStyle(color: context.text1, fontSize: 16),
            decoration: InputDecoration(
              hintText: ref.lang('pay.comment_hint'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13)),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitRequest,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(ref.lang('pay.submit'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _step = 0),
              child: Text(ref.lang('pay.back_to_instruction')),
            ),
          ),
        ],
      ),
    );
  }

  // ── ШАГ 2: Заявка отправлена ─────────────────────────────
  Widget _buildConfirmation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 80),
            const SizedBox(height: 24),
            Text(
              ref.lang('pay.request_sent'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: context.text1,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              ref.lang('pay.request_sent_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.text2, fontSize: 14),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/home'),
                child: Text(ref.lang('pay.go_home')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ref.lang('pay.copied')),
          duration: const Duration(seconds: 1)),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onCopy;

  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: context.text1, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: context.text2, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: context.text1,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, size: 20, color: AppTheme.primary),
                onPressed: onCopy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Gradient call-to-action button for an online payment provider.
/// Shows a centered spinner inside the button while `isLoading` is true.
class _OnlinePayButton extends StatelessWidget {
  final String provider;
  final String label;
  final List<Color> colors;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _OnlinePayButton({
    required this.provider,
    required this.label,
    required this.colors,
    required this.icon,
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled && !isLoading ? 0.5 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
