import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common.dart';
import '../../common/widgets/s_mark.dart';
import '../../desktop/pages/desktop_tab_page.dart';
import '../../models/platform_model.dart';
import 'auth_gate_page.dart';
import 'get_help_page.dart';
import 'home_page.dart';

/// Branded launch screen. Plays the ShamarrConnect mark animation
/// (S-curve draw + pulsing endpoints, same motion as the website loader),
/// then routes:
///   desktop          -> DesktopTabPage
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
  static const _kMinDisplay = Duration(milliseconds: 850);
  static const _kAnimDuration = Duration(milliseconds: 900);

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
    if (isDesktop) {
      dest = const DesktopTabPage();
    } else if (gFFI.userModel.isLogin) {
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
                // Animation only — no wordmark under the mark.
                return SMark(size: 120, progress: t, pulse: t);
              },
            ),
          ),
        ),
      ),
    );
  }
}
