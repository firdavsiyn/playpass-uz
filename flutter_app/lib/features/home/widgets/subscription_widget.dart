import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/subscription.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/utils/plural.dart';

class SubscriptionWidget extends ConsumerWidget {
  final Subscription? subscription;
  const SubscriptionWidget({super.key, this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subscription == null ||
        (!subscription!.isActive && !subscription!.isFrozen)) {
      return _buildNoSubscription(context, ref);
    }
    return _ActiveSubscription(subscription: subscription!);
  }

  Widget _buildNoSubscription(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/plans');
      },
      // Gradient border wrapper
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.neonCyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(1.5), // border width
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.25),
                      AppTheme.neonCyan.withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: AppTheme.primaryLight, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ref.lang('sub_widget.no_active'),
                        style: TextStyle(
                            color: context.text1,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(ref.lang('sub_widget.buy_cta'),
                        style: TextStyle(color: context.text2, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.neonCyan],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_ios,
                    color: Colors.white, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _planGlowColor(String plan) {
  switch (plan) {
    case 'basic':
      return AppTheme.neonBlue;
    case 'standard':
      return AppTheme.primary;
    case 'pro':
      return AppTheme.neonPurple;
    case 'vip':
      return AppTheme.tierVip;
    default:
      return AppTheme.primary;
  }
}

/// Compact subscription STATUS strip (utility-first).
/// One row: plan badge + state label + remaining (days / hours / ∞).
/// Tappable → opens the full subscription screen.
class _ActiveSubscription extends ConsumerWidget {
  final Subscription subscription;
  const _ActiveSubscription({required this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFrozen = subscription.isFrozen;
    final color = isFrozen ? context.frozen : _planGlowColor(subscription.plan);

    // State label
    final String stateLabel = isFrozen
        ? ref.lang('sub_widget.frozen')
        : subscription.isActive
            ? ref.lang('home.state_active')
            : ref.lang('home.state_expired');

    // Remaining: hours (or ∞) + days
    final bool expiring = !isFrozen && subscription.daysRemaining <= 3;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/subscription');
      },
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isFrozen ? context.frozenBg : context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: isFrozen ? 0.3 : 0.25),
          ),
          boxShadow: isFrozen ? null : AppTheme.cardGlow(color: color),
        ),
        child: Row(
          children: [
            // Plan badge (tier color chip)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                subscription.localizedPlanName(ref),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // State label
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isFrozen) ...[
                  Icon(Icons.ac_unit_rounded, color: color, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  stateLabel,
                  style: TextStyle(
                    color: isFrozen ? color : context.text2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Remaining — hours/∞ on top, days below
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subscription.isUnlimited
                      ? ref.lang('home.unlimited_short')
                      : pluralVisits(subscription.hoursBalance ?? 0),
                  style: TextStyle(
                    color: context.text1,
                    fontSize: subscription.isUnlimited ? 18 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${subscription.daysRemaining} ${ref.lang('sub_widget.days_short')} ${ref.lang('sub_widget.remaining')}',
                  style: TextStyle(
                    color: expiring ? AppTheme.warning : context.text3,
                    fontSize: 11,
                    fontWeight:
                        expiring ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
