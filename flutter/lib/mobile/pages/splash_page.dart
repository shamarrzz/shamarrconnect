import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common.dart';
import '../../models/platform_model.dart';
import 'auth_gate_page.dart';
import 'get_help_page.dart';
import 'home_page.dart';

/// Branded launch screen. Plays the ShamarrConnect mark animation
/// (S-curve draw + pulsing endpoints, same motion as the website loader),
/// then routes by session state:
///   signed in        -> HomePage
///   "Get Help" mode  -> GetHelpPage (incoming-only)
///   otherwise        -> AuthGatePage
class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const _kMinDisplay = Duration(milliseconds: 1300);
  static const _kAnimDuration = Duration(milliseconds: 1400);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _kAnimDuration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _route();
        });
  late final DateTime _start = DateTime.now();
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  Future<void> _route() async {
    if (_routed) return;
    _routed = true;
    final elapsed = DateTime.now().difference(_start);
    if (elapsed < _kMinDisplay) {
      await Future.delayed(_kMinDisplay - elapsed);
    }
    if (!mounted) return;

    final Widget dest;
    if (gFFI.userModel.isLogin) {
      dest = HomePage();
    } else if (bind.mainGetLocalOption(key: 'get_help_mode') == 'Y') {
      dest = const GetHelpPage();
    } else {
      dest = const AuthGatePage();
    }
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => dest,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0A1737),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1737),
        body: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CustomPaint(
                        painter: _MarkPainter(progress: t, pulse: t),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Opacity(
                      opacity: Curves.easeOut
                          .transform(((t - 0.35) / 0.65).clamp(0.0, 1.0)),
                      child: Image.asset(
                        'assets/wordmark.png',
                        width: MediaQuery.of(context).size.width * 0.58,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the brand S-curve between two nodes, revealed over [progress],
/// with the endpoints pulsing in opposition (mirrors logo-animated.svg).
class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.progress, required this.pulse});

  /// 0..1 — how much of the curve is revealed.
  final double progress;

  /// 0..1 — drives the endpoint pulse.
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
    final revealed =
        metric.extractPath(0, metric.length * Curves.easeInOut.transform(progress));
    canvas.drawPath(revealed, stroke);

    // Endpoints pulse in opposition, easing in with the reveal.
    final dotPaint = Paint()..shader = gradient;
    final breathe = sin(pulse * pi * 4); // two full cycles over the animation
    final fade = Curves.easeOut.transform((progress * 3).clamp(0.0, 1.0));
    canvas.drawCircle(_top, (6 + 1.5 * breathe) * fade, dotPaint);
    canvas.drawCircle(_bottom, (6 - 1.5 * breathe) * fade, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.progress != progress || old.pulse != pulse;
}
