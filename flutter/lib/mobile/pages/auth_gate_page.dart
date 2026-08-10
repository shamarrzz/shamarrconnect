import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common.dart';
import '../../common/widgets/login.dart';
import '../../models/platform_model.dart';
import '../../utils/http_service.dart' as http;
import 'get_help_page.dart';
import 'home_page.dart';
import 'onboarding_page.dart';

/// First-run gate for signed-out users. Offers sign-in, account creation
/// (or waitlist capture while registration is closed pre-launch), and the
/// no-account "Get Help" path for people receiving support.
class AuthGatePage extends StatefulWidget {
  const AuthGatePage({Key? key}) : super(key: key);

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  static const _navy = Color(0xFF0A1737);
  static const _blue = Color(0xFF0071FF);

  /// null = still loading; true = open registration; false = waitlist only.
  bool? _registrationOpen;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    var open = false;
    try {
      final url = await bind.mainGetApiServer();
      final resp = await http
          .get(Uri.parse('$url/api/config'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        open = jsonDecode(resp.body)['registration'] == true;
      }
    } catch (_) {
      // Offline or unreachable: keep registration closed; sign-in still works.
    }
    if (mounted) setState(() => _registrationOpen = open);
  }

  Widget _next(Widget home) => OnboardingPage.done
      ? home
      : OnboardingPage(destination: (_) => home);

  Future<void> _signIn() async {
    final ok = await loginDialog(initialMode: 'login');
    if (ok == true && mounted) {
      _go(_next(HomePage()));
    }
  }

  Future<void> _createAccount() async {
    if (_registrationOpen == true) {
      final ok = await loginDialog(initialMode: 'register');
      if (ok == true && mounted) {
        _go(_next(HomePage()));
      }
    } else {
      _showWaitlistSheet();
    }
  }

  void _getHelp() async {
    await bind.mainSetLocalOption(key: 'get_help_mode', value: 'Y');
    if (mounted) _go(_next(const GetHelpPage()));
  }

  void _go(Widget dest) {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => dest,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  void _showWaitlistSheet() {
    final email = TextEditingController();
    var sending = false;
    var done = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: done
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: _blue, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      "You're on the list",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "We'll email you as soon as your account is ready.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create account',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "We're opening accounts in stages. Leave your email and "
                      "we'll save you a spot — you'll be first in when your "
                      'turn comes.',
                      style: TextStyle(color: Colors.black54, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: sending
                            ? null
                            : () async {
                                final e = email.text.trim().toLowerCase();
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(e)) {
                                  return;
                                }
                                setSheet(() => sending = true);
                                try {
                                  await http
                                      .post(
                                        Uri.parse(
                                            'https://shamarrconnect.com/api/waitlist'),
                                        headers: {
                                          'Content-Type': 'application/json'
                                        },
                                        body: jsonEncode(
                                            {'email': e, 'src': 'android'}),
                                      )
                                      .timeout(const Duration(seconds: 8));
                                } catch (_) {
                                  // Confirmation is shown regardless; ops
                                  // reconciles from the mail notification.
                                }
                                if (context.mounted) {
                                  setSheet(() {
                                    sending = false;
                                    done = true;
                                  });
                                }
                              },
                        child: Text(sending ? 'One moment…' : 'Save my spot'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _navy,
      ),
      child: Scaffold(
        backgroundColor: _navy,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Image.asset(
                  'assets/wordmark.png',
                  width: MediaQuery.of(context).size.width * 0.62,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Help any computer or phone,\nfrom anywhere.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _signIn,
                    child:
                        const Text('Sign in', style: TextStyle(fontSize: 17)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        _registrationOpen == null ? null : _createAccount,
                    child: Text(
                      _registrationOpen == false
                          ? 'Create account — join the list'
                          : 'Create account',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                const Divider(color: Colors.white24),
                TextButton.icon(
                  onPressed: _getHelp,
                  icon: const Icon(Icons.support_agent,
                      color: Color(0xFF00BFE1)),
                  label: const Text(
                    'Get help now — let a supporter connect to this phone',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
