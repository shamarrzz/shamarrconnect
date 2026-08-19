import 'dart:math';

import 'package:flutter/material.dart';

/// Shared ShamarrConnect S-mark (same geometry as the website loader).
///
/// Used animated on splash, static on the auth gate and desktop home.
/// No wordmark — the sidebar and mobile chrome are too tight for one.
class SMark extends StatelessWidget {
  const SMark({
    Key? key,
    this.size = 56,
    this.progress = 1,
    this.pulse = 0.5,
  }) : super(key: key);

  final double size;

  /// 0..1 — how much of the curve is revealed.
  final double progress;

  /// 0..1 — drives the endpoint pulse (0.5 = still).
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: SMarkPainter(progress: progress, pulse: pulse),
      ),
    );
  }
}

class SMarkPainter extends CustomPainter {
  SMarkPainter({required this.progress, required this.pulse});

  final double progress;
  final double pulse;

  static const _top = Offset(50, 22);
  static const _bottom = Offset(50, 78);

  Path _curve() {
    final p = Path()..moveTo(_bottom.dx, _bottom.dy);
    p.cubicTo(72, 74, 70, 54, 50, 50);
    p.cubicTo(30, 46, 28, 26, _top.dx, _top.dy);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF00BFE1), Color(0xFF0071FF)],
    ).createShader(const Rect.fromLTWH(20, 10, 60, 80));

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = gradient;

    final path = _curve();
    final metric = path.computeMetrics().first;
    final revealed = metric.extractPath(
        0, metric.length * Curves.easeInOut.transform(progress.clamp(0.0, 1.0)));
    canvas.drawPath(revealed, stroke);

    final dotPaint = Paint()..shader = gradient;
    final breathe = sin(pulse * pi * 4);
    final fade = Curves.easeOut.transform((progress * 3).clamp(0.0, 1.0));
    canvas.drawCircle(_top, (6 + 1.5 * breathe) * fade, dotPaint);
    canvas.drawCircle(_bottom, (6 - 1.5 * breathe) * fade, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(SMarkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}
