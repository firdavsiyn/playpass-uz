import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/widgets/neon_shimmer.dart';
import '../../../models/subscription.dart';
import '../../../services/supabase_service.dart';

// ── Provider ────────────────────────────────────────────────
final _mySubProvider = FutureProvider<Subscription?>((ref) async {
  return SupabaseService().getActiveSubscription();
});

// ── Screen ──────────────────────────────────────────────────
class MySubscriptionScreen extends ConsumerWidget {
  const MySubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(_mySubProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(_mySubProvider);
          await ref.read(_mySubProvider.future).catchError((_) {});
        },
        child: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  ref.lang('sub.my'),
                  style: TextStyle(
                    color: context.text1,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),

          // ── Subscription card ───────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: subAsync.when(
                data: (sub) => _SubscriptionCard(subscription: sub),
                loading: () => _SubscriptionCardSkeleton(),
                error: (_, __) => _SubscriptionCard(subscription: null),
              ),
            ),
          ),

          // ── Actions section ─────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Text(
                ref.lang('sub.actions'),
                style: TextStyle(
                  color: context.text3,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
                  boxShadow: AppTheme.cardGlow(),
                ),
                child: Column(
                  children: [
                    _ActionTile(
                      icon: Icons.card_membership_rounded,
                      iconColor: AppTheme.primary,
                      title: ref.lang('sub.buy'),
                      onTap: () => context.push('/plans'),
                    ),
                    const _Divider(),
                    _ActionTile(
                      icon: Icons.confirmation_number_outlined,
                      iconColor: const Color(0xFF22C55E),
                      title: ref.lang('sub.promo'),
                      onTap: () => _showPromoDialog(context, ref),
                    ),
                    const _Divider(),
                    _ActionTile(
                      icon: Icons.card_giftcard_rounded,
                      iconColor: const Color(0xFFEF4444),
                      title: ref.lang('sub.gift_buy'),
                      onTap: () => _showGiftInfo(context),
                    ),
                    const _Divider(),
                    _ActionTile(
                      icon: Icons.redeem_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      title: ref.lang('sub.gift_redeem'),
                      onTap: () => context.push('/gift/redeem'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── FAQ section ─────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _ActionTile(
                  icon: Icons.help_outline_rounded,
                  iconColor: context.text3,
                  title: ref.lang('sub.faq'),
                  onTap: () => _showFAQ(context, ref: ref),
                ),
              ),
            ),
          ),

          // ── Plan comparison ─────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Text(
                ref.lang('sub.compare'),
                style: TextStyle(
                  color: context.text3,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: AppConstants.plans.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final plan = AppConstants.plans.values.toList()[index];
                  return _MiniPlanCard(
                    plan: plan,
                    onTap: () => context.push('/payment', extra: plan.id),
                  );
                },
              ),
            ),
          ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      ),
    );
  }

  void _showPromoDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _PromoDialog(
        controller: controller,
        onApplied: () => ref.invalidate(_mySubProvider),
      ),
    );
  }

  void _showGiftInfo(BuildContext context) {
    context.push('/gift/purchase');
  }

  void _showFAQ(BuildContext context, {required WidgetRef ref}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: context.text3.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(ref.lang('faq.title'),
                style: TextStyle(
                    color: context.text1,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _faqItem(ref.lang('faq.q1'), ref.lang('faq.a1')),
            _faqItem(ref.lang('faq.q2'), ref.lang('faq.a2').replaceAll('{n}', '${AppConstants.freezeMaxDaysPerMonth}')),
            _faqItem(ref.lang('faq.q3'), ref.lang('faq.a3')),
            _faqItem(ref.lang('faq.q4'), ref.lang('faq.a4')),
            _faqItem(ref.lang('faq.q5'), ref.lang('faq.a5')),
            _faqItem(ref.lang('faq.q6'), ref.lang('faq.a6').replaceAll('{n}', '${AppConstants.referralBonusHours}')),
          ],
        ),
      ),
    );
  }

  Widget _faqItem(String q, String a) {
    // Note: This method doesn't have BuildContext, but it's called inside
    // a builder that provides context. We need to convert to a widget.
    return Builder(builder: (context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q,
              style: TextStyle(
                  color: context.text1,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
          const SizedBox(height: 6),
          Text(a,
              style: TextStyle(
                  color: context.text2, fontSize: 14, height: 1.4)),
        ],
      ),
    ));
  }
}

// ── Subscription Card ───────────────────────────────────────

class _SubscriptionCard extends ConsumerWidget {
  final Subscription? subscription;
  const _SubscriptionCard({this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = subscription;
    final hasActive = sub != null && (sub.isActive || sub.isFrozen);

    final glowColor = hasActive ? _glowForPlan(sub!.plan) : context.text3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: hasActive
            ? LinearGradient(
                colors: sub!.isFrozen
                    ? [const Color(0xFF37474F), const Color(0xFF455A64)]
                    : _gradientForPlan(sub.plan),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF374151), Color(0xFF4B5563)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(color: glowColor.withValues(alpha: 0.2)),
        boxShadow: hasActive && !sub!.isFrozen
            ? AppTheme.neonGlow(color: glowColor, radius: 20)
            : [],
      ),
      child: hasActive ? _activeContent(context, ref, sub!) : _expiredContent(context, ref),
    );
  }

  List<Color> _gradientForPlan(String plan) => switch (plan) {
    'vip' => [const Color(0xFF92400E), const Color(0xFFB45309)],
    'pro' => [const Color(0xFF581C87), const Color(0xFF7C3AED)],
    'standard' => [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
    _ => [const Color(0xFF1E3A5F), const Color(0xFF1E40AF)],
  };

  Color _glowForPlan(String plan) => switch (plan) {
    'vip' => const Color(0xFFD4A017),
    'pro' => AppTheme.neonPurple,
    'standard' => AppTheme.primary,
    _ => AppTheme.neonBlue,
  };

  Widget _activeContent(BuildContext context, WidgetRef ref, Subscription sub) {
    final config = sub.planConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plan name + status
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                sub.localizedPlanName(ref),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (sub.isFrozen) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.ac_unit_rounded, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(ref.lang('sub.frozen_label'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.5), size: 18),
          ],
        ),
        const SizedBox(height: 24),

        // Hours or unlimited
        if (sub.isUnlimited) ...[
          const Text('∞',
              style: TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800)),
          Text(sub.localizedHoursSubtext(ref),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15)),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(sub.hoursText,
                  style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(sub.localizedHoursSubtext(ref),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: sub.hoursProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Days remaining
        Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color: Colors.white.withValues(alpha: 0.6), size: 16),
            const SizedBox(width: 6),
            Text(
              '${sub.daysRemaining} ${ref.lang('sub.days_remaining')}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
            if (!sub.isFrozen && sub.daysRemaining <= 3) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(ref.lang('sub.expires'),
                    style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),

        // Allowed zones
        if (config != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: config.allowedZones.map((z) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppConstants.localizedZoneLabel(z, ref),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _expiredContent(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white54, size: 20),
            const SizedBox(width: 8),
            Text(ref.lang('sub.no_active_label'),
                style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.4), size: 16),
          ],
        ),
        const SizedBox(height: 16),
        Text(ref.lang('sub.expired_label'),
            style: const TextStyle(color: Colors.white38, fontSize: 14)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.push('/plans'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(ref.lang('sub.buy'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

class _SubscriptionCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const NeonSkeletonCard(height: 180, borderRadius: 20),
      const SizedBox(height: 16),
      const NeonSkeletonCard(height: 80, borderRadius: 16),
      const SizedBox(height: 8),
      const NeonSkeletonCard(height: 80, borderRadius: 16),
    ]);
  }
}

// ── Action tile ─────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.text1,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.text3.withValues(alpha: 0.5), size: 24),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: context.text3.withValues(alpha: 0.15),
      ),
    );
  }
}

// ── Mini plan card ──────────────────────────────────────────

// ── Promo dialog ───────────────────────────────────────────

class _PromoDialog extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final VoidCallback onApplied;
  const _PromoDialog({required this.controller, required this.onApplied});

  @override
  ConsumerState<_PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends ConsumerState<_PromoDialog> {
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _apply() async {
    final code = widget.controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = ref.lang('sub.promo_enter'));
      return;
    }
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      final result = await SupabaseService().applyPromoCode(code);
      final type = result['type'] as String;
      final value = result['value'] as int;
      final bonus = type == 'hours'
          ? '+$value ${ref.lang('sub.promo_hours')}'
          : type == 'days'
              ? '+$value ${ref.lang('sub.promo_days')}'
              : '${value}% ${ref.lang('sub.promo_discount')}';
      setState(() => _success = '${ref.lang('sub.promo_activated')} $bonus');
      widget.onApplied();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.card,
      title: Text(ref.lang('sub.promo_title'),
          style: TextStyle(color: context.text1)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: context.text1, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: ref.lang('sub.promo_hint'),
              errorText: _error,
            ),
          ),
          if (_success != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_success!,
                        style: const TextStyle(
                            color: Color(0xFF22C55E), fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_success != null ? ref.lang('sub.promo_close') : ref.lang('sub.promo_cancel')),
        ),
        if (_success == null)
          ElevatedButton(
            onPressed: _loading ? null : _apply,
            child: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(ref.lang('sub.promo_activate')),
          ),
      ],
    );
  }
}

// ── Mini plan card ──────────────────────────────────────────

class _MiniPlanCard extends ConsumerWidget {
  final PlanConfig plan;
  final VoidCallback onTap;

  const _MiniPlanCard({required this.plan, required this.onTap});

  Color get _color => switch (plan.id) {
    'vip' => const Color(0xFFFBBF24),
    'pro' => const Color(0xFF8B5CF6),
    'standard' => AppTheme.primary,
    _ => const Color(0xFF6B7280),
  };

  String _formatPrice(int priceUzs) {
    final str = priceUzs.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(str[i]);
    }
    return '${buffer.toString()} UZS';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: _color.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan name
            Text(
              ref.lang('plan.${plan.id}'),
              style: TextStyle(
                color: _color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            // Hours
            Text(
              plan.isUnlimited ? ref.lang('sub.visit_per_day') : '${plan.hours} ${ref.lang('sub.hours_per_month')}',
              style: TextStyle(color: context.text2, fontSize: 13),
            ),
            const Spacer(),
            // Price
            Text(
              _formatPrice(plan.priceUzs),
              style: TextStyle(
                color: context.text1,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(ref.lang('sub.per_month_label'),
                style: TextStyle(color: context.text3, fontSize: 12)),
            const SizedBox(height: 10),
            // Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ref.lang('sub.order_btn'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
