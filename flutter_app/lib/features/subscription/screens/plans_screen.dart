import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/widgets/glass_backdrop.dart';

/// Экран выбора тарифа — покупаемые планы (Day-Pass / Day / Anytime),
/// помесячно. Годовая оплата отложена (BM v1.2).
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only purchasable tariffs (daily/day/anytime). Legacy codes stay in the
    // map for rendering existing subs but are not offered for sale.
    final plans = AppConstants.purchasablePlanCodes
        .map((c) => AppConstants.plans[c]!)
        .toList();
    // Annual billing is deferred (BM v1.2) — monthly only, no toggle.

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        title: Text(ref.lang('plans.title')),
      ),
      body: GlassBackdrop(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Text(
                    ref.lang('plans.subtitle'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: context.text1,
                        ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    ref.lang('plans.desc'),
                    style: TextStyle(color: context.text2, fontSize: 14),
                  ),
                ),
              ),
              // Monthly / Annual toggle
              // Annual billing deferred — toggle hidden.
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final plan = plans[index];
                    final isPopular = plan.id == 'day';

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < plans.length - 1 ? 16 : 24,
                      ),
                      child: _PlanCard(
                        plan: plan,
                        isPopular: isPopular,
                        isAnnual: false,
                        displayPrice: plan.priceUzs,
                        monthlyEquivalent: null,
                        onSelect: () =>
                            context.push('/payment', extra: plan.id),
                      ),
                    );
                  },
                  childCount: plans.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle between Monthly and Annual (-30%) pricing
class _PlanCard extends ConsumerWidget {
  final PlanConfig plan;
  final bool isPopular;
  final VoidCallback onSelect;
  final bool isAnnual;
  final int displayPrice;
  final int? monthlyEquivalent;

  const _PlanCard({
    required this.plan,
    required this.isPopular,
    required this.onSelect,
    this.isAnnual = false,
    int? displayPrice,
    this.monthlyEquivalent,
  }) : displayPrice = displayPrice ?? -1;

  int get _effectivePrice => displayPrice == -1 ? plan.priceUzs : displayPrice;

  String _formatPrice(int priceUzs) {
    final str = priceUzs.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(str[i]);
    }
    return '${buffer.toString()} UZS';
  }

  String _hoursLabel(PlanConfig p, WidgetRef ref) {
    if (p.isUnlimited) return ref.lang('plans.visit_day');
    return '${p.hours} ${ref.lang('plans.hours_month')}';
  }

  List<_FeatureItem> _buildFeatures(PlanConfig p, WidgetRef ref) {
    final items = <_FeatureItem>[];

    // Hours / visits
    if (p.isUnlimited) {
      items.add(_FeatureItem(ref.lang('plans.unlimited_desc'), true));
    } else {
      items.add(
          _FeatureItem('${p.hours} ${ref.lang('plans.hours_monthly')}', true));
    }

    // Zones
    final hasBasic = p.allowedZones.contains('basic');
    final hasPro = p.allowedZones.contains('pro');
    final hasVip = p.allowedZones.contains('vip');

    items.add(_FeatureItem(ref.lang('plans.zone_basic'), hasBasic));
    items.add(_FeatureItem(ref.lang('plans.zone_pro'), hasPro));
    items.add(_FeatureItem(ref.lang('plans.zone_vip'), hasVip));

    // Time slots
    final hasDay = p.allowedSlots.contains('day');
    final hasEvening = p.allowedSlots.contains('evening');
    final hasNight = p.allowedSlots.contains('night');
    final allDay = hasDay && hasEvening && hasNight;

    if (allDay) {
      items.add(_FeatureItem(ref.lang('plans.all_day'), true));
    } else if (hasDay) {
      items.add(_FeatureItem(ref.lang('plans.day_only'), true));
      items.add(_FeatureItem(ref.lang('plans.no_evening'), false));
    }

    return items;
  }

  Color get _planColor => AppTheme.planColor(plan.id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceFormatted = _formatPrice(_effectivePrice);
    final usdEquiv = (_effectivePrice / 12450).toStringAsFixed(0);
    final features = _buildFeatures(plan, ref);
    final color = _planColor;
    final monthlyHint = monthlyEquivalent != null
        ? '${_formatPrice(monthlyEquivalent!)} ${ref.lang('plans.per_month_short')}'
        : null;
    final savings = isAnnual ? plan.priceUzs * 12 - _effectivePrice : 0;

    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? color : color.withValues(alpha: 0.2),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: isPopular
            ? AppTheme.neonGlow(color: color, radius: 20)
            : AppTheme.cardGlow(color: color),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + hours badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        style: TextStyle(
                          color: context.text1,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _hoursLabel(plan, ref),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Price
                Text(
                  priceFormatted,
                  style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  isAnnual
                      ? '${ref.lang('plans.per_year')} (~\$$usdEquiv)'
                      : '${ref.lang('plans.per_month')} (~\$$usdEquiv)',
                  style: TextStyle(
                    color: context.text3,
                    fontSize: 13,
                  ),
                ),
                if (isAnnual && monthlyHint != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '≈ $monthlyHint',
                    style: TextStyle(color: context.text3, fontSize: 12),
                  ),
                ],
                if (savings > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ' ${ref.lang('sub.annual_savings').replaceAll('{n}', _formatPrice(savings).replaceAll(' UZS', ''))}',
                      style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Features list
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FeatureRow(
                        text: f.label,
                        included: f.included,
                      ),
                    )),

                const SizedBox(height: 12),

                // CTA button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isPopular ? AppTheme.primary : context.surface,
                      foregroundColor: isPopular ? Colors.white : context.text1,
                      side: isPopular
                          ? null
                          : const BorderSide(color: AppTheme.primary),
                    ),
                    child: Text(
                      ref.lang('plans.select'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // "Популярный" badge
          if (isPopular)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.neonPurple, AppTheme.primary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  ref.lang('plans.popular'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Helper models and widgets ────────────────────────────────────

class _FeatureItem {
  final String label;
  final bool included;
  const _FeatureItem(this.label, this.included);
}

class _FeatureRow extends StatelessWidget {
  final String text;
  final bool included;

  const _FeatureRow({required this.text, required this.included});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          included ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 18,
          color: included ? AppTheme.success : context.text3,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: included ? context.text2 : context.text3,
              fontSize: 14,
              decoration: included ? null : TextDecoration.lineThrough,
              decorationColor: context.text3,
            ),
          ),
        ),
      ],
    );
  }
}
