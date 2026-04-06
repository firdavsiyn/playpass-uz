import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
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

  PlanConfig get _plan => AppConstants.plans[widget.plan]!;

  @override
  void dispose() {
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Введите номер телефона для связи');
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
      setState(() => _error = 'Ошибка отправки. Попробуйте снова.');
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        title: Text(_step == 2 ? 'Заявка отправлена' : 'Оплата'),
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
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Тариф: ${_plan.name}',
                        style: const TextStyle(
                          color: context.text1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _plan.isUnlimited
                            ? 'Безлимит · 1 визит/день / 30 дней'
                            : '${_plan.hours} часов / 30 дней',
                        style: const TextStyle(
                            color: context.text2, fontSize: 13),
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

          // Payment instructions
          const Text(
            'Как оплатить',
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
            title: 'Через Payme',
            subtitle: 'Переведите $priceFormatted UZS на номер:',
            value: AppConstants.paymentPaymePhone,
            onCopy: () => _copyToClipboard(AppConstants.paymentPaymePhone),
          ),
          const SizedBox(height: 12),

          // Option 2: Card
          _PaymentOption(
            icon: Icons.credit_card,
            title: 'На карту HUMO/UZCARD',
            subtitle: 'Переведите $priceFormatted UZS на карту:',
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
                  'Получатель: ${AppConstants.paymentCardHolder}',
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
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'После перевода нажмите «Я оплатил» и заполните короткую форму. '
                    'Мы активируем подписку в течение 30 минут.',
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
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Я оплатил',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
          const Text(
            'Подтверждение оплаты',
            style: TextStyle(
              color: context.text1,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Заполните форму, чтобы мы могли проверить платёж '
            'и активировать подписку.',
            style: TextStyle(color: context.text2, fontSize: 14),
          ),
          const SizedBox(height: 24),

          Text('Номер телефона для связи *',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: context.text1, fontSize: 16),
            decoration: const InputDecoration(
              hintText: '+998 90 123 45 67',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 16),

          Text('Комментарий (необязательно)',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 3,
            style: TextStyle(color: context.text1, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Сумма перевода, время, с какого банка...',
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
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Отправить заявку',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),

          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('Назад к инструкции'),
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
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.success, size: 80),
            const SizedBox(height: 24),
            Text(
              'Заявка отправлена!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: context.text1,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Мы проверим платёж и активируем вашу подписку '
              'в течение 30 минут (в рабочие часы 09:00–22:00).\n\n'
              'Вы получите уведомление, когда подписка будет активна.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.text2, fontSize: 14),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('На главную'),
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
      const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 1)),
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
                  style: const TextStyle(
                      color: context.text1, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  color: context.text2, fontSize: 13)),
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
                    style: const TextStyle(
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
