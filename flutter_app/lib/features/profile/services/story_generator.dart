import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';

/// Generates a 1080×1920 Instagram Story image with the user's stats and
/// referral code, then offers to share it via system share sheet.
///
/// Designed to drive viral growth: the user posts to their followers, who
/// see "PlayPass Level 5 — 10 clubs visited, 50 hours played" with a QR
/// code that opens the registration flow with the referrer's bonus pre-applied.
class StoryGenerator {
  /// Generate the PNG bytes for a 1080×1920 story.
  ///
  /// [name] — user's display name
  /// [level] — loyalty level label ("Bronze", "Silver", "Gold", "VIP")
  /// [visits] — total visits
  /// [hours] — total hours played
  /// [referralCode] — short code (e.g. "FIRDAVS-X7K")
  /// [referralUrl] — full invite URL (rendered into QR-like dot pattern)
  static Future<Uint8List> generate({
    required String name,
    required String level,
    required int visits,
    required int hours,
    required String referralCode,
    required String referralUrl,
  }) async {
    const width = 1080.0;
    const height = 1920.0;

    final recorder = ui.PictureRecorder();
    final canvas =
        ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, width, height));

    // ── Background gradient ──────────────────────────────────
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(width, height),
        [
          const Color(0xFF050510),
          AppTheme.primary.withValues(alpha: 0.4),
          const Color(0xFF050510),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

    // ── Decorative orbs ──────────────────────────────────────
    _drawOrb(canvas, const Offset(900, 300), 200, AppTheme.primary, 0.5);
    _drawOrb(canvas, const Offset(180, 1500), 250, AppTheme.neonCyan, 0.4);
    _drawOrb(canvas, const Offset(800, 1700), 150, AppTheme.neonPink, 0.3);

    // ── Title "PlayPass" with gradient ───────────────────────
    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'PlayPass',
        style: TextStyle(
          fontSize: 110,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          foreground: Paint()
            ..shader = ui.Gradient.linear(
              const Offset(0, 0),
              const Offset(500, 0),
              [AppTheme.primaryLight, AppTheme.neonCyan],
            ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titlePainter.paint(canvas, Offset((width - titlePainter.width) / 2, 240));

    // ── Subtitle ─────────────────────────────────────────────
    final subtitle = TextPainter(
      text: const TextSpan(
        text: 'единая подписка для всех клубов',
        style: TextStyle(
          fontSize: 32,
          color: Color(0xFF9B8FC2),
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subtitle.paint(canvas, Offset((width - subtitle.width) / 2, 380));

    // ── Player card (glassmorphism box) ──────────────────────
    final cardRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(80, 540, 920, 700),
      const Radius.circular(40),
    );
    canvas.drawRRect(
      cardRect,
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );
    canvas.drawRRect(
      cardRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = ui.Gradient.linear(
          const Offset(80, 540),
          const Offset(1000, 1240),
          [
            AppTheme.primary.withValues(alpha: 0.5),
            AppTheme.neonCyan.withValues(alpha: 0.3),
          ],
        ),
    );

    // ── User name ────────────────────────────────────────────
    final namePainter = TextPainter(
      text: TextSpan(
        text: name.toUpperCase(),
        style: const TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: 850);
    namePainter.paint(canvas, Offset((width - namePainter.width) / 2, 620));

    // ── Level badge ──────────────────────────────────────────
    final levelText = TextPainter(
      text: TextSpan(
        text: level.toUpperCase(),
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final levelBgWidth = levelText.width + 80;
    final levelBgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: const Offset(width / 2, 740),
          width: levelBgWidth,
          height: 60),
      const Radius.circular(30),
    );
    canvas.drawRRect(
      levelBgRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(width / 2 - levelBgWidth / 2, 0),
          Offset(width / 2 + levelBgWidth / 2, 0),
          [AppTheme.primary, AppTheme.neonCyan],
        ),
    );
    levelText.paint(canvas, Offset((width - levelText.width) / 2, 726));

    // ── Stats row: visits | hours ────────────────────────────
    _drawStat(canvas, 280, 880, '$visits', 'визитов');
    _drawStat(canvas, 800, 880, '${hours}ч', 'наиграно');

    // ── Vertical divider between stats ───────────────────────
    canvas.drawRect(
      const Rect.fromLTWH(539, 870, 2, 140),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );

    // ── Referral code section ────────────────────────────────
    final inviteLabelPainter = TextPainter(
      text: const TextSpan(
        text: 'ПРИГЛАШАЮ ТЕБЯ',
        style: TextStyle(
          fontSize: 32,
          color: Color(0xFF9B8FC2),
          letterSpacing: 4,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    inviteLabelPainter.paint(
        canvas, Offset((width - inviteLabelPainter.width) / 2, 1080));

    // Referral code (large)
    final codePainter = TextPainter(
      text: TextSpan(
        text: referralCode,
        style: TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.w900,
          letterSpacing: 8,
          foreground: Paint()
            ..shader = ui.Gradient.linear(
              const Offset(0, 1130),
              const Offset(width, 1230),
              [AppTheme.primaryLight, AppTheme.neonCyan, AppTheme.neonPink],
            ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    codePainter.paint(canvas, Offset((width - codePainter.width) / 2, 1140));

    // ── Bonus text ───────────────────────────────────────────
    final bonusPainter = TextPainter(
      text: const TextSpan(
        children: [
          TextSpan(
            text: 'Получи ',
            style: TextStyle(fontSize: 38, color: Colors.white70),
          ),
          TextSpan(
            text: '10 БОНУСНЫХ ЧАСОВ',
            style: TextStyle(
                fontSize: 38,
                color: Color(0xFF22C55E),
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    bonusPainter.paint(canvas, Offset((width - bonusPainter.width) / 2, 1280));

    // ── Footer with download URL ─────────────────────────────
    final footerLine1 = TextPainter(
      text: const TextSpan(
        text: 'Скачай PlayPass',
        style: TextStyle(
          fontSize: 36,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    footerLine1.paint(canvas, Offset((width - footerLine1.width) / 2, 1660));

    final footerLine2 = TextPainter(
      text: const TextSpan(
        text: 'app.playpass.uz',
        style: TextStyle(
          fontSize: 44,
          color: AppTheme.neonCyan,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    footerLine2.paint(canvas, Offset((width - footerLine2.width) / 2, 1720));

    // ── Render to PNG ────────────────────────────────────────
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Generate the story and immediately invoke the system share sheet.
  static Future<void> shareStory({
    required String name,
    required String level,
    required int visits,
    required int hours,
    required String referralCode,
    required String referralUrl,
  }) async {
    final bytes = await generate(
      name: name,
      level: level,
      visits: visits,
      hours: hours,
      referralCode: referralCode,
      referralUrl: referralUrl,
    );

    await Share.shareXFiles(
      [
        XFile.fromData(bytes, name: 'playpass-share.png', mimeType: 'image/png')
      ],
      text:
          'Я в PlayPass! Используй мой код $referralCode и получи 10 бонусных часов $referralUrl',
    );
  }

  // ─── Internal drawing helpers ──────────────────────────────

  static void _drawOrb(ui.Canvas canvas, ui.Offset center, double radius,
      ui.Color color, double alpha) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  static void _drawStat(
      ui.Canvas canvas, double cx, double cy, String value, String label) {
    final valuePainter = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          fontSize: 84,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    valuePainter.paint(canvas, Offset(cx - valuePainter.width / 2, cy));

    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 26,
          color: Color(0xFF9B8FC2),
          letterSpacing: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(canvas, Offset(cx - labelPainter.width / 2, cy + 110));
  }
}
