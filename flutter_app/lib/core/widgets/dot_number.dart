import 'package:flutter/material.dart';

/// Dot-matrix (LED) numerals — renders digits as a 5×7 grid of dots, like the
/// glucose-monitor reference ("84", "100", "83"). Pure CustomPainter, no font
/// dependency. Supports digits 0-9, '.', ',', '%', '-', ' ' and '∞'.
class DotMatrixNumber extends StatelessWidget {
  final String text;
  final double dotSize;
  final double dotGap;
  final Color color;

  /// Faint "unlit" dots behind the lit ones (the characteristic LED look).
  final bool showGrid;

  /// Soft neon bloom behind each lit dot (canvas MaskFilter, not a
  /// BackdropFilter). Gate to hero numerals only — never in-scroll tiles.
  final bool glow;

  const DotMatrixNumber(
    this.text, {
    super.key,
    this.dotSize = 5,
    this.dotGap = 2.2,
    this.color = Colors.white,
    this.showGrid = true,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    const cols = 5, rows = 7;
    final cell = dotSize + dotGap;
    final charW = cols * cell;
    final charGap = cell * 0.9;
    final glyphs = text.split('');
    final width = glyphs.fold<double>(
        0, (w, g) => w + (_isNarrow(g) ? cell * 2 : charW) + charGap);
    return SizedBox(
      width: width,
      height: rows * cell,
      child: CustomPaint(
        painter: _DotPainter(
          text: text,
          dotSize: dotSize,
          cell: cell,
          charGap: charGap,
          color: color,
          showGrid: showGrid,
          glow: glow,
        ),
      ),
    );
  }

  static bool _isNarrow(String g) => g == '.' || g == ',' || g == ' ';
}

class _DotPainter extends CustomPainter {
  final String text;
  final double dotSize;
  final double cell;
  final double charGap;
  final Color color;
  final bool showGrid;
  final bool glow;

  _DotPainter({
    required this.text,
    required this.dotSize,
    required this.cell,
    required this.charGap,
    required this.color,
    required this.showGrid,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lit = Paint()..color = color;
    final dim = Paint()..color = color.withValues(alpha: 0.10);
    final bloom = glow
        ? (Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8))
        : null;
    final r = dotSize / 2;
    double x = 0;

    for (final ch in text.split('')) {
      final pattern = _font[ch];
      if (pattern == null) {
        x += DotMatrixNumber._isNarrow(ch)
            ? cell * 2 + charGap
            : 5 * cell + charGap;
        continue;
      }
      final isNarrow = DotMatrixNumber._isNarrow(ch);
      final cols = isNarrow ? 2 : 5;
      for (int row = 0; row < 7; row++) {
        final bits = pattern[row];
        for (int col = 0; col < cols; col++) {
          final on = (bits >> (cols - 1 - col)) & 1 == 1;
          final cx = x + col * cell + r;
          final cy = row * cell + r;
          if (on) {
            if (bloom != null) canvas.drawCircle(Offset(cx, cy), r, bloom);
            canvas.drawCircle(Offset(cx, cy), r, lit);
          } else if (showGrid) {
            canvas.drawCircle(Offset(cx, cy), r * 0.55, dim);
          }
        }
      }
      x += cols * cell + charGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) =>
      old.text != text ||
      old.color != color ||
      old.dotSize != dotSize ||
      old.glow != glow;

  // 5×7 bitmaps (top→bottom rows, 5 bits each). Narrow glyphs use 2 bits.
  static const Map<String, List<int>> _font = {
    '0': [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
    '1': [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
    '2': [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F],
    '3': [0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E],
    '4': [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
    '5': [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
    '6': [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E],
    '7': [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
    '8': [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
    '9': [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
    '%': [0x19, 0x1A, 0x02, 0x04, 0x08, 0x0B, 0x13],
    '-': [0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00],
    // narrow (2-bit) glyphs
    '.': [0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x03],
    ',': [0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x02],
    '∞': [0x00, 0x00, 0x1B, 0x1B, 0x00, 0x00, 0x00], // ∞ (wide-ish)
  };
}
