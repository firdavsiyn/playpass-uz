import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/subscription.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';

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
      return const Color(0xFFD4A017);
    default:
      return AppTheme.primary;
  }
}

class _ActiveSubscription extends ConsumerWidget {
  final Subscription subscription;
  const _ActiveSubscription({required this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _planGlowColor(subscription.plan);
    final isFrozen = subscription.isFrozen;

    // Gradient border wrapper for active subscription
    return Container(
      decoration: BoxDecoration(
        gradient: isFrozen
            ? null
            : LinearGradient(
                colors: [
                  color.withValues(alpha: 0.7),
                  color.withValues(alpha: 0.2)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isFrozen ? Colors.blueGrey.withValues(alpha: 0.2) : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isFrozen
            ? []
            : [
                BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 40,
                    spreadRadius: -4),
              ],
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${ref.lang('sub_widget.expires_in')} ${subscription.daysRemaining} ${ref.lang('sub_widget.days_short')}',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.25),
                            color.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.15),
                            blurRadius: 8,
                            spreadRadius: -2,
                          ),
                        ],
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
                    if (isFrozen) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.blueGrey.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.ac_unit_rounded,
                                color: Colors.blueGrey, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              ref.lang('sub_widget.frozen'),
                              style: const TextStyle(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${subscription.daysRemaining} ${ref.lang('sub_widget.days_short')}',
                          style: TextStyle(
                            color: context.text1,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          ref.lang('sub_widget.remaining'),
                          style: TextStyle(
                            color: context.text3,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Circular progress + hours
                Row(
                  children: [
                    // Circular progress indicator with glow
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Progress ring
                          CustomPaint(
                            size: const Size(90, 90),
                            painter: _NeonProgressPainter(
                              progress: subscription.isUnlimited
                                  ? 1.0
                                  : subscription.hoursProgress,
                              color: isFrozen ? Colors.blueGrey : color,
                              secondaryColor: isFrozen
                                  ? Colors.blueGrey
                                  : AppTheme.neonCyan,
                              bgColor: context.surface,
                              glowEnabled: !isFrozen,
                            ),
                          ),
                          // Center text
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                subscription.isUnlimited
                                    ? '∞'
                                    : subscription.hoursText,
                                style: TextStyle(
                                  color: isFrozen
                                      ? Colors.blueGrey
                                      : context.text1,
                                  fontSize: subscription.isUnlimited ? 28 : 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (!subscription.isUnlimited)
                                Text(
                                  ref.lang('sub_widget.hours_short'),
                                  style: TextStyle(
                                    color: isFrozen
                                        ? Colors.blueGrey.withValues(alpha: 0.6)
                                        : context.text3,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 22),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscription.isUnlimited
                                ? ref.lang('sub_widget.unlimited')
                                : subscription.localizedHoursSubtext(ref),
                            style: TextStyle(
                              color: isFrozen
                                  ? Colors.blueGrey.withValues(alpha: 0.7)
                                  : context.text2,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (subscription.isUnlimited)
                            Text(
                              ref.lang('sub_widget.visit_per_day'),
                              style: TextStyle(
                                color: isFrozen
                                    ? Colors.blueGrey.withValues(alpha: 0.5)
                                    : context.text3,
                                fontSize: 12,
                              ),
                            ),
                          if (!subscription.isUnlimited) ...[
                            // Mini progress bar with glow
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                height: 7,
                                decoration: BoxDecoration(
                                  color: context.surface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final filledWidth = constraints.maxWidth *
                                        subscription.hoursProgress;
                                    return Stack(
                                      children: [
                                        // Filled portion with glow
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          bottom: 0,
                                          width: filledWidth,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isFrozen
                                                  ? Colors.blueGrey
                                                  : color,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              boxShadow: isFrozen
                                                  ? []
                                                  : [
                                                      BoxShadow(
                                                        color: color.withValues(
                                                            alpha: 0.5),
                                                        blurRadius: 6,
                                                        spreadRadius: -1,
                                                      ),
                                                    ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                          // ── Rollover bonus ─────────────────
                          if (subscription.hoursRolledOver > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  '+${subscription.hoursRolledOver} ${ref.lang('sub_widget.rolled_over')}',
                                  style: const TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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

/// Neon-style circular progress painter with multi-color gradient sweep
class _NeonProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color secondaryColor;
  final Color bgColor;
  final bool glowEnabled;

  _NeonProgressPainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
    required this.bgColor,
    this.glowEnabled = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    const strokeWidth = 6.0;
    final sweepAngle = 2 * math.pi * progress;

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Dual-color glow (subtle)
    if (glowEnabled) {
      // Primary color glow
      final glowPaint1 = Paint()
        ..color = color.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        glowPaint1,
      );

      // Secondary (cyan) glow — more subtle
      final glowPaint2 = Paint()
        ..color = secondaryColor.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        glowPaint2,
      );
    }

    // Progress arc with SweepGradient for multi-color effect
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [color, secondaryColor, color],
      stops: const [0.0, 0.5, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.bgColor != bgColor ||
      oldDelegate.glowEnabled != glowEnabled;
}
