import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class UpsellScreen extends StatelessWidget {
  final Map<String, String> extra;

  const UpsellScreen({super.key, required this.extra});

  @override
  Widget build(BuildContext context) {
    final currentPlan = extra['currentPlan'] ?? 'basic';
    final requiredZone = extra['requiredZone'] ?? 'pro';
    final zoneName = extra['zoneName'] ?? AppConstants.zoneLabel(requiredZone);
    final clubName = extra['clubName'] ?? '';

    // Determine the minimum plan needed for the required zone
    final requiredPlan = _requiredPlanForZone(requiredZone);
    final requiredPlanName = AppConstants.plans[requiredPlan]?.name ?? requiredPlan;
    final currentPlanName = AppConstants.plans[currentPlan]?.name ?? currentPlan;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Доступ ограничен'),
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
              'Эта зона требует другого тарифа',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 12),

            if (clubName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  clubName,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),

            // Plan comparison card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _PlanRow(
                    label: 'Ваш тариф',
                    planName: currentPlanName,
                    color: AppTheme.textMuted,
                    icon: Icons.close_rounded,
                    iconColor: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: AppTheme.bgSurface,
                  ),
                  const SizedBox(height: 16),
                  _PlanRow(
                    label: 'Требуется для зоны "$zoneName"',
                    planName: requiredPlanName,
                    color: AppTheme.textPrimary,
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
                child: Text('Перейти на $requiredPlanName'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/clubs'),
                child: const Text('Найти клуб с базовой зоной'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text(
                  'Назад',
                  style: TextStyle(color: AppTheme.textSecondary),
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
                style: const TextStyle(
                  color: AppTheme.textMuted,
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
