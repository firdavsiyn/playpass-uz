import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/theme/app_theme.dart';

class UpsellScreen extends ConsumerWidget {
  final Map<String, String> extra;

  const UpsellScreen({super.key, required this.extra});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPlan = extra['currentPlan'] ?? 'basic';
    final requiredZone = extra['requiredZone'] ?? 'pro';
    final zoneName = extra['zoneName'] ?? AppConstants.zoneLabel(requiredZone);
    final clubName = extra['clubName'] ?? '';

    // Determine the minimum plan needed for the required zone
    final requiredPlan = _requiredPlanForZone(requiredZone);
    final requiredPlanName =
        AppConstants.plans[requiredPlan]?.name ?? requiredPlan;
    final currentPlanName =
        AppConstants.plans[currentPlan]?.name ?? currentPlan;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(ref.lang('upsell.title')),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: AppTheme.warning,
                size: 40,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              ref.lang('upsell.zone_requires'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 12),

            if (clubName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  clubName,
                  style: TextStyle(
                    color: context.text2,
                    fontSize: 14,
                  ),
                ),
              ),

            // Plan comparison card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _PlanRow(
                    label: ref.lang('upsell.your_plan'),
                    planName: currentPlanName,
                    color: context.text3,
                    icon: Icons.close_rounded,
                    iconColor: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: context.surface,
                  ),
                  const SizedBox(height: 16),
                  _PlanRow(
                    label: ref
                        .lang('upsell.required_for_zone')
                        .replaceFirst('{zone}', zoneName),
                    planName: requiredPlanName,
                    color: context.text1,
                    icon: Icons.check_circle_rounded,
                    iconColor: AppTheme.success,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/plans'),
                child: Text(ref
                    .lang('upsell.upgrade_to')
                    .replaceFirst('{plan}', requiredPlanName)),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/clubs'),
                child: Text(ref.lang('upsell.find_basic_club')),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  ref.lang('upsell.back'),
                  style: TextStyle(color: context.text2),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Returns the minimum plan that grants access to the given zone.
  String _requiredPlanForZone(String zoneType) {
    for (final entry in AppConstants.plans.entries) {
      if (entry.value.allowedZones.contains(zoneType)) {
        return entry.key;
      }
    }
    return 'vip';
  }
}

class _PlanRow extends StatelessWidget {
  final String label;
  final String planName;
  final Color color;
  final IconData icon;
  final Color iconColor;

  const _PlanRow({
    required this.label,
    required this.planName,
    required this.color,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.text3,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                planName,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
