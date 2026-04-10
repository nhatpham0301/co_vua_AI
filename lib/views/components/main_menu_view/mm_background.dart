import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mm_palette.dart';

// ─── Subtle chess-square checker overlay ─────────────────────────────────────
class BoardBackground extends StatelessWidget {
  const BoardBackground({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BoardPatternPainter());
}

class _BoardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.012)
      ..style = PaintingStyle.fill;
    const cell = 40.0;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if ((r + c).isEven) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPatternPainter _) => false;
}

// ─── Decorative corner knots ──────────────────────────────────────────────────
class CornerKnots extends StatelessWidget {
  const CornerKnots({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _KnotPainter());
}

class _KnotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primary.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _drawKnot(canvas, paint, Offset.zero, 52);
    _drawKnot(canvas, paint, Offset(size.width, 0), 52, flipX: true);
  }

  void _drawKnot(Canvas canvas, Paint paint, Offset origin, double r,
      {bool flipX = false}) {
    final dx = flipX ? -1.0 : 1.0;
    final cx = origin.dx + dx * r;
    final cy = origin.dy + r;
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(Offset(cx, cy), r * i * 0.3, paint);
    }
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 1.6, height: r * 1.6),
      -math.pi / 4,
      math.pi / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_KnotPainter _) => false;
}
