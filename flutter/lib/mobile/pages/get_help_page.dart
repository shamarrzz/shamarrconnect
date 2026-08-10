import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common.dart';
import '../../models/platform_model.dart';
import 'auth_gate_page.dart';

/// Incoming-only home for people receiving support — no account needed.
/// Shows this phone's ID and one-time password large, keeps the service
/// running, and offers a path into the full app via sign-in.
class GetHelpPage extends StatefulWidget {
  const GetHelpPage({Key? key}) : super(key: key);

  @override
  State<GetHelpPage> createState() => _GetHelpPageState();
}

class _GetHelpPageState extends State<GetHelpPage> {
  static const _navy = Color(0xFF0A1737);
  static const _blue = Color(0xFF0071FF);

  String _id = '';
  String _password = '';

  @override
  void initState() {
    super.initState();
    gFFI.serverModel.startService();
    _load();
  }

  Future<void> _load() async {
    final id = await bind.mainGetMyId();
    final pw = await bind.mainGetTemporaryPassword();
    if (mounted) {
      setState(() {
        _id = id.trim();
        _password = pw.trim();
      });
    }
  }

  String get _idSpaced {
    final digits = _id.replaceAll(' ', '');
    if (digits.length <= 3) return digits;
    final parts = <String>[];
    for (var i = 0; i < digits.length; i += 3) {
      final end = i + 3 > digits.length ? digits.length : i + 3;
      parts.add(digits.substring(i, end));
    }
    return parts.join(' ');
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
              'can connect — keep it private.',
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
      final done =
          await bind.mainSetPermanentPasswordWithResult(password: pw.text.trim());
      showToast(translate(done ? 'Successful' : 'Failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: _navy,
        title: Image.asset('assets/wordmark.png', height: 22),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            const Text(
              'Your supporter will ask for these',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _card(
              label: 'Your ID',
              value: _id.isEmpty ? 'Generating…' : _idSpaced,
              trailing: IconButton(
                icon: const Icon(Icons.copy, color: _blue),
                onPressed: _id.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: _id));
                        showToast('ID copied');
                      },
              ),
            ),
            const SizedBox(height: 14),
            _card(
              label: 'One-time password',
              value: _password.isEmpty ? '…' : _password,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, color: _blue),
                onPressed: () async {
                  await bind.mainUpdateTemporaryPassword();
                  _load();
                },
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: _blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only share these with someone you trust. A session '
                      'starts only after you accept it, and you can end it '
                      'at any time.',
                      style: TextStyle(height: 1.4, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 3))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.devices_other, color: _blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Is this your own device?',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For a shop tablet or a second phone you own, set a '
                    'permanent password and you can connect anytime — no '
                    'need for anyone to tap accept.',
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                        side: const BorderSide(color: _blue),
                      ),
                      onPressed: _setPermanentPassword,
                      child: const Text('Set permanent password'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: _signInInstead,
              child: const Text(
                'Sign in for full features',
                style: TextStyle(color: _blue, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
      {required String label, required String value, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
