import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

/// Экран выбора тарифа v2.0 — 4 плана (Базовый / Стандарт / Про / VIP)
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plans = AppConstants.plans.values.toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        title: const Text('Выберите тариф'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  'Начните играть сегодня',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text(
                  'Выберите тариф и оплатите удобным способом. '
                  'Подписка будет активирована в течение 30 минут.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final plan = plans[index];
                  final isPopular = plan.id == 'standard';

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < plans.length - 1 ? 16 : 24,
                    ),
                    child: _PlanCard(
                      plan: plan,
                      isPopular: isPopular,
                      onSelect: () => context.push('/payment', extra: plan.id),
                    ),
                  );
                },
                childCount: plans.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanConfig plan;
  final bool isPopular;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.isPopular,
    required this.onSelect,
  });

  String _formatPrice(int priceUzs) {
    final str = priceUzs.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(str[i]);
    }
    return '${buffer.toString()} UZS';
  }

  String _hoursLabel(PlanConfig p) {
    if (p.isUnlimited) return '1 визит/день';
    return '${p.hours} ч/мес';
  }

  List<_FeatureItem> _buildFeatures(PlanConfig p) {
    final items = <_FeatureItem>[];

    // Hours / visits
    if (p.isUnlimited) {
      items.add(_FeatureItem('Безлимит (1 визит в день)', true));
    } else {
      items.add(_FeatureItem('${p.hours} часов в месяц', true));
    }

    // Zones
    final hasBasic = p.allowedZones.contains('basic');
    final hasPro = p.allowedZones.contains('pro');
    final hasVip = p.allowedZones.contains('vip');

    items.add(_FeatureItem('Базовая зона', hasBasic));
    items.add(_FeatureItem('Про зона', hasPro));
    items.add(_FeatureItem('VIP зона', hasVip));

    // Time slots
    final hasDay = p.allowedSlots.contains('day');
    final hasEvening = p.allowedSlots.contains('evening');
    final hasNight = p.allowedSlots.contains('night');
    final allDay = hasDay && hasEvening && hasNight;

    if (allDay) {
      items.add(_FeatureItem('Круглосуточный доступ 24/7', true));
    } else if (hasDay) {
      items.add(_FeatureItem('Только день (08:00–20:00)', true));
      items.add(_FeatureItem('Вечерние и ночные часы', false));
    }

    return items;
  }

  Color get _planColor => switch (plan.id) {
    'vip' => const Color(0xFFFBBF24),
    'pro' => const Color(0xFF8B5CF6),
    'standard' => AppTheme.primary,
    _ => const Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final priceFormatted = _formatPrice(plan.priceUzs);
    final usdEquiv = (plan.priceUzs / 12450).toStringAsFixed(0);
    final features = _buildFeatures(plan);
    final color = _planColor;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
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
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
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
                        _hoursLabel(plan),
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
                  'в месяц (~\$$usdEquiv)',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
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
                          isPopular ? AppTheme.primary : AppTheme.bgSurface,
                      foregroundColor:
                          isPopular ? Colors.white : AppTheme.textPrimary,
                      side: isPopular
                          ? null
                          : const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Оформить',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
                child: const Text(
                  'Популярный',
                  style: TextStyle(
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
          color: included ? AppTheme.success : AppTheme.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: included ? AppTheme.textSecondary : AppTheme.textMuted,
              fontSize: 14,
              decoration: included ? null : TextDecoration.lineThrough,
              decorationColor: AppTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
