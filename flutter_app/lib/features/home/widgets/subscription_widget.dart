import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/subscription.dart';
import '../../../core/theme/app_theme.dart';

class SubscriptionWidget extends StatelessWidget {
  final Subscription? subscription;
  const SubscriptionWidget({super.key, this.subscription});

  @override
  Widget build(BuildContext context) {
    if (subscription == null || (!subscription!.isActive && !subscription!.isFrozen)) {
      return _buildNoSubscription(context);
    }
    return _ActiveSubscription(subscription: subscription!);
  }

  Widget _buildNoSubscription(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/plans'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgGlass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.3),
                        AppTheme.neonPurple.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.card_membership_rounded,
                      color: AppTheme.primaryLight, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Нет активной подписки',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Купите тариф и начните играть',
                          style:
                              TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios,
                      color: AppTheme.primary, size: 14),
                ),
              ],
            ),
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
      return const Color(0xFFD4A017);
    default:
      return AppTheme.primary;
  }
}

class _ActiveSubscription extends StatelessWidget {
  final Subscription subscription;
  const _ActiveSubscription({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final color = _planGlowColor(subscription.plan);
    final isFrozen = subscription.isFrozen;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFrozen
              ? Colors.blueGrey.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.15),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expiration warning banner
              if (!isFrozen && subscription.daysRemaining <= 3) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Подписка истекает через ${subscription.daysRemaining} дн.',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Plan badge + days remaining
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.25),
                          color.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      subscription.planName,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isFrozen) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.ac_unit_rounded,
                              color: Colors.blueGrey, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Заморожена',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${subscription.daysRemaining} дн.',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Circular progress + hours
              Row(
                children: [
                  // Circular progress indicator with glow
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Progress ring
                        CustomPaint(
                          size: const Size(80, 80),
                          painter: _NeonProgressPainter(
                            progress: subscription.isUnlimited ? 1.0 : subscription.hoursProgress,
                            color: isFrozen ? Colors.blueGrey : color,
                            bgColor: AppTheme.bgSurface,
                            glowEnabled: false,
                          ),
                        ),
                        // Center text
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              subscription.isUnlimited ? '∞' : subscription.hoursText,
                              style: TextStyle(
                                color: isFrozen ? Colors.blueGrey : AppTheme.textPrimary,
                                fontSize: subscription.isUnlimited ? 28 : 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (!subscription.isUnlimited)
                              Text(
                                'ч',
                                style: TextStyle(
                                  color: isFrozen ? Colors.blueGrey.withValues(alpha: 0.6) : AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.isUnlimited ? 'Безлимит' : subscription.hoursSubtext,
                          style: TextStyle(
                            color: isFrozen
                                ? Colors.blueGrey.withValues(alpha: 0.7)
                                : AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (subscription.isUnlimited)
                          Text(
                            '1 визит в день',
                            style: TextStyle(
                              color: isFrozen
                                  ? Colors.blueGrey.withValues(alpha: 0.5)
                                  : AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        if (!subscription.isUnlimited) ...[
                          // Mini progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppTheme.bgSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: subscription.hoursProgress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Neon-style circular progress painter
class _NeonProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;
  final bool glowEnabled;

  _NeonProgressPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    this.glowEnabled = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 5.0;

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Glow paint
    if (glowEnabled) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        glowPaint,
      );
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
