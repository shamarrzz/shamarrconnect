import 'dart:math';

import 'package:flutter/material.dart';

/// Shared ShamarrConnect S-mark (same geometry as the website loader).
///
/// Used animated on splash, static on the auth gate and desktop home.
/// No wordmark — the sidebar and mobile chrome are too tight for one.
///
/// The curve matches `website/site/logo-animated.svg` (viewBox 100).
Path shamarrSCurve() {
  final p = Path()..moveTo(50, 78);
  p.cubicTo(72, 74, 70, 54, 50, 50);
  p.cubicTo(30, 46, 28, 26, 50, 22);
  return p;
}

/// True when [text] is the Connecting... loading label, raw or already translated.
///
/// [translated] is `translate('Connecting...')`. An empty translation does not
/// match every string.
bool isConnectingLabel(String text, String translated) {
  if (text == 'Connecting...') return true;
  return translated.isNotEmpty && text == translated;
}

/// Visible slice of a unit-length path while the loader dash slides on, then off.
///
/// `t` is 0..1 after the ease. This is stroke-dashoffset 100 → -100 on a
/// pathLength of 100: empty, drawn from the start, full, erased from the start.
class ConnectingDashWindow {
  const ConnectingDashWindow(this.start, this.end);

  final double start;
  final double end;

  bool get isEmpty => end <= start;
}

ConnectingDashWindow connectingDashWindow(double t) {
  final u = t.clamp(0.0, 1.0);
  final start = (2 * u - 1).clamp(0.0, 1.0);
  final end = (2 * u).clamp(0.0, 1.0);
  return ConnectingDashWindow(start, end);
}

/// Looping connect wait. Same motion as `logo-animated.svg`: navy tile,
/// S-curve draws on then off over 2.8s, endpoints pulse opposite over 1.5s.
///
/// `showLoading` uses this for "Connecting...", including a session reconnect.
/// Login and Waiting keep the stock spinner.
class ConnectingMark extends StatefulWidget {
  const ConnectingMark({Key? key, this.size = 76}) : super(key: key);

  final double size;

  @override
  State<ConnectingMark> createState() => _ConnectingMarkState();
}

class _ConnectingMarkState extends State<ConnectingMark>
    with TickerProviderStateMixin {
  static const _drawDuration = Duration(milliseconds: 2800);
  static const _pulseDuration = Duration(milliseconds: 1500);
  static const _ease = Cubic(0.45, 0, 0.55, 1);

  late final AnimationController _draw;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(vsync: this, duration: _drawDuration)
      ..repeat();
    _pulse = AnimationController(vsync: this, duration: _pulseDuration)
      ..repeat();
  }

  @override
  void dispose() {
    _draw.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: reduce
            ? CustomPaint(
                painter: ConnectingMarkPainter(draw: 0.5, pulse: 0.25),
              )
            : AnimatedBuilder(
                animation: Listenable.merge([_draw, _pulse]),
                builder: (context, _) => CustomPaint(
                  painter: ConnectingMarkPainter(
                    draw: _ease.transform(_draw.value),
                    pulse: _pulse.value,
                  ),
                ),
              ),
      ),
    );
  }
}

class ConnectingMarkPainter extends CustomPainter {
  ConnectingMarkPainter({required this.draw, required this.pulse});

  final double draw;
  final double pulse;

  static const _top = Offset(50, 22);
  static const _bottom = Offset(50, 78);

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF00BFE1), Color(0xFF0071FF)],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(22),
      ),
      Paint()..color = const Color(0xFF0A1737),
    );

    final shader = _gradient.createShader(const Rect.fromLTWH(20, 10, 60, 80));
    final window = connectingDashWindow(draw);
    if (!window.isEmpty) {
      final metric = shamarrSCurve().computeMetrics().first;
      final revealed = metric.extractPath(
        metric.length * window.start,
        metric.length * window.end,
      );
      canvas.drawPath(
        revealed,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
    }

    final dotPaint = Paint()..shader = shader;
    final angle = pulse * pi * 2;
    canvas.drawCircle(_top, 6.25 - 1.25 * cos(angle), dotPaint);
    canvas.drawCircle(_bottom, 6.25 + 1.25 * cos(angle), dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(ConnectingMarkPainter oldDelegate) =>
      oldDelegate.draw != draw || oldDelegate.pulse != pulse;
}

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

    final path = shamarrSCurve();
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
