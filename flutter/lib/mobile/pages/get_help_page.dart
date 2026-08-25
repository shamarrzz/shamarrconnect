import 'package:flutter/material.dart';

import '../../common.dart';
import '../../common/widgets/desk/desk_page.dart';
import '../../models/platform_model.dart';
import 'auth_gate_page.dart';
import 'onboarding_page.dart';

/// Incoming-only home for people receiving support. One-card desk: Share.
class GetHelpPage extends StatefulWidget {
  const GetHelpPage({Key? key}) : super(key: key);

  @override
  State<GetHelpPage> createState() => _GetHelpPageState();
}

class _GetHelpPageState extends State<GetHelpPage> {
  static const _navy = Color(0xFF0A1737);
  static const _blue = Color(0xFF0071FF);

  @override
  void initState() {
    super.initState();
    gFFI.serverModel.startService();
  }

  Future<void> _signInInstead() async {
    await bind.mainSetLocalOption(key: 'get_help_mode', value: '');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const AuthGatePage(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  Future<void> _setPermanentPassword() async {
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanent password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'At least 8 characters. Anyone with this password and your ID '
              'can connect. Keep it private.',
              style: TextStyle(color: Colors.black54, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pw,
              obscureText: true,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _blue),
            onPressed: () {
              if (pw.text.trim().length >= 8) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final done = await bind.mainSetPermanentPasswordWithResult(
          password: pw.text.trim());
      showToast(translate(done ? 'Successful' : 'Failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: _navy,
        title: const Text('Get help'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: DeskPage(
                helpMode: true,
                showSettings: false,
                onContinueSetup: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => OnboardingPage(
                      popOnDone: true,
                      destination: (_) => const GetHelpPage(),
                    ),
                  ));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _setPermanentPassword,
                  child: const Text('Set permanent password'),
                ),
              ),
            ),
            TextButton(
              onPressed: _signInInstead,
              child: const Text(
                'Sign in for full features',
                style: TextStyle(color: _blue, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
