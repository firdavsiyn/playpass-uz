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
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.card_membership_rounded,
                    color: AppTheme.primaryLight, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Нет активной подписки',
                        style: TextStyle(
                            color: context.text1,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Купите тариф и начните играть',
                        style:
                            TextStyle(color: context.text2, fontSize: 13)),
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

    // Gradient border wrapper for active subscription
    return Container(
      decoration: BoxDecoration(
        gradient: isFrozen
            ? null
            : LinearGradient(
                colors: [color.withValues(alpha: 0.6), color.withValues(alpha: 0.15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isFrozen ? Colors.blueGrey.withValues(alpha: 0.2) : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isFrozen
            ? []
            : [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(19),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
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
                    style: TextStyle(color: context.text3, fontSize: 13),
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
                            bgColor: context.surface,
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
                                color: isFrozen ? Colors.blueGrey : context.text1,
                                fontSize: subscription.isUnlimited ? 28 : 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (!subscription.isUnlimited)
                              Text(
                                'ч',
                                style: TextStyle(
                                  color: isFrozen ? Colors.blueGrey.withValues(alpha: 0.6) : context.text3,
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
                                : context.text2,
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
                                  : context.text3,
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
                                color: context.surface,
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
