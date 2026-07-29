import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/model.dart';

/// Account sign-in MFA (TOTP) — distinct from device 2FA for remote sessions.
class AccountMfaCard extends StatefulWidget {
  const AccountMfaCard({super.key});

  @override
  State<AccountMfaCard> createState() => _AccountMfaCardState();
}

class _AccountMfaCardState extends State<AccountMfaCard> {
  bool? _enabled;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (gFFI.userModel.userName.value.isEmpty) {
      setState(() {
        _enabled = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final on = await gFFI.userModel.mfaStatus();
      if (mounted) {
        setState(() {
          _enabled = on;
          _loading = false;
        });
      }
    } on RequestException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.cause.isNotEmpty ? e.cause : 'Failed to load MFA status';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Rebuild when login state changes.
      final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
      if (!loggedIn) {
        return Padding(
          padding: const EdgeInsets.only(left: 18, top: 8),
          child: Text(
            'Log in to manage account sign-in protection (MFA).',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 13,
            ),
          ),
        );
      }
      if (_loading) {
        return const Padding(
          padding: EdgeInsets.all(18),
          child: LinearProgressIndicator(),
        );
      }
      if (_error != null) {
        return Padding(
          padding: const EdgeInsets.only(left: 18, top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              TextButton(onPressed: _refresh, child: Text(translate('Retry'))),
            ],
          ),
        );
      }
      final on = _enabled == true;
      return Padding(
        padding: const EdgeInsets.only(left: 18, top: 8, right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Protects signing into your ShamarrConnect account (password + authenticator). '
              'This is different from Security → 2FA, which protects remote connections to this PC.',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  on ? Icons.verified_user : Icons.shield_outlined,
                  color: on ? Colors.green : Theme.of(context).disabledColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    on
                        ? 'Account MFA is on — login requires an authenticator code.'
                        : 'Account MFA is off — password alone can sign in.',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (!on)
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await showAccountMfaEnableDialog(context);
                      if (ok == true) await _refresh();
                    },
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('Enable MFA'),
                  ),
                if (on)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showAccountMfaDisableDialog(context);
                      if (ok == true) await _refresh();
                    },
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Disable MFA'),
                  ),
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(translate('Refresh')),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// Mobile settings tile row for account MFA.
class AccountMfaSettingsTile extends StatefulWidget {
  const AccountMfaSettingsTile({super.key});

  @override
  State<AccountMfaSettingsTile> createState() => _AccountMfaSettingsTileState();
}

class _AccountMfaSettingsTileState extends State<AccountMfaSettingsTile> {
  bool? _enabled;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (gFFI.userModel.userName.value.isEmpty) return;
    setState(() => _loading = true);
    try {
      final on = await gFFI.userModel.mfaStatus();
      if (mounted) setState(() => _enabled = on);
    } catch (_) {
      if (mounted) setState(() => _enabled = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
      final subtitle = !loggedIn
          ? 'Log in first'
          : _loading
              ? '…'
              : _enabled == true
                  ? 'On — authenticator required at login'
                  : _enabled == false
                      ? 'Off'
                      : 'Status unknown';
      return ListTile(
        leading: Icon(_enabled == true ? Icons.verified_user : Icons.shield_outlined),
        title: const Text('Account MFA (sign-in)'),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: !loggedIn
            ? null
            : () async {
                if (_enabled == true) {
                  final ok = await showAccountMfaDisableDialog(context);
                  if (ok == true) await _load();
                } else {
                  final ok = await showAccountMfaEnableDialog(context);
                  if (ok == true) await _load();
                }
              },
      );
    });
  }
}

Future<bool?> showAccountMfaEnableDialog(BuildContext context) async {
  String? secret;
  String? otpauth;
  String? error;
  var step = 0; // 0 loading setup, 1 enter code, 2 show recovery
  List<String> recovery = [];
  final codeCtrl = TextEditingController();
  var busy = false;

  return gFFI.dialogManager.show<bool>((setState, close, ctx) {
    Future<void> startSetup() async {
      setState(() {
        busy = true;
        error = null;
      });
      try {
        final data = await gFFI.userModel.mfaSetup();
        secret = data['secret']?.toString();
        otpauth = data['otpauth_url']?.toString();
        step = 1;
      } on RequestException catch (e) {
        error = e.cause;
      } catch (e) {
        error = e.toString();
      }
      setState(() => busy = false);
    }

    Future<void> confirm() async {
      final digits = codeCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length != 6) {
        setState(() => error = translate('2FA code must be 6 digits.'));
        return;
      }
      setState(() {
        busy = true;
        error = null;
      });
      try {
        recovery = await gFFI.userModel.mfaConfirm(digits);
        step = 2;
        BotToast.showText(text: 'Account MFA enabled');
      } on RequestException catch (e) {
        error = e.cause;
      } catch (e) {
        error = e.toString();
      }
      setState(() => busy = false);
    }

    // Kick off setup once when dialog opens
    if (step == 0 && !busy && secret == null && error == null) {
      Future.microtask(startSetup);
    }

    Widget body;
    if (step == 0 || (busy && step < 2 && secret == null)) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(translate('Waiting')),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            TextButton(onPressed: startSetup, child: Text(translate('Retry'))),
          ],
        ],
      );
    } else if (step == 1) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Scan this QR code with Google Authenticator, Authy, or Microsoft Authenticator. '
            'Then enter the 6-digit code to turn on account MFA.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (otpauth != null && otpauth!.isNotEmpty)
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: otpauth!,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          if (secret != null) ...[
            const SizedBox(height: 10),
            SelectableText(
              secret!,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: secret!));
                BotToast.showText(text: 'Secret copied');
              },
              child: const Text('Copy secret'),
            ),
          ],
          const SizedBox(height: 8),
          Dialog2FaField(
            controller: codeCtrl,
            title: translate('Verification code'),
            errorText: error,
            autoSubmit: false,
            onChanged: () => setState(() => error = null),
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'MFA is on. Save these recovery codes offline — each works once if you lose your authenticator.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(ctx).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              recovery.join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.5),
            ),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: recovery.join('\n')));
              BotToast.showText(text: 'Recovery codes copied');
            },
            child: const Text('Copy recovery codes'),
          ),
        ],
      );
    }

    return CustomAlertDialog(
      title: Text(step == 2 ? 'Save recovery codes' : 'Enable account MFA'),
      contentBoxConstraints: const BoxConstraints(minWidth: 340, maxWidth: 420),
      content: body,
      actions: [
        if (step < 2)
          dialogButton(translate('Cancel'), onPressed: () => close(false), isOutline: true),
        if (step == 1)
          dialogButton(
            translate('Verify'),
            onPressed: busy ? null : confirm,
          ),
        if (step == 2)
          dialogButton(translate('OK'), onPressed: () => close(true)),
      ],
      onCancel: () => close(step == 2),
    );
  });
}

Future<bool?> showAccountMfaDisableDialog(BuildContext context) async {
  final passCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  String? error;
  var busy = false;
  var obscure = true;

  return gFFI.dialogManager.show<bool>((setState, close, ctx) {
    Future<void> submit() async {
      final pass = passCtrl.text;
      final digits = codeCtrl.text.trim();
      if (pass.isEmpty) {
        setState(() => error = 'Password required');
        return;
      }
      if (digits.length < 6) {
        setState(() => error = translate('2FA code must be 6 digits.'));
        return;
      }
      setState(() {
        busy = true;
        error = null;
      });
      try {
        await gFFI.userModel.mfaDisable(password: pass, code: digits);
        BotToast.showText(text: 'Account MFA disabled');
        close(true);
        return;
      } on RequestException catch (e) {
        error = e.cause;
      } catch (e) {
        error = e.toString();
      }
      setState(() => busy = false);
    }

    return CustomAlertDialog(
      title: const Text('Disable account MFA'),
      contentBoxConstraints: const BoxConstraints(minWidth: 320, maxWidth: 400),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Turning this off means password alone can sign into your account. '
            'Enter your account password and a current authenticator (or recovery) code.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passCtrl,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: translate('Password'),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => obscure = !obscure),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Dialog2FaField(
            controller: codeCtrl,
            title: 'Authenticator or recovery code',
            errorText: error,
            autoSubmit: false,
            onChanged: () => setState(() => error = null),
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
      actions: [
        dialogButton(translate('Cancel'), onPressed: () => close(false), isOutline: true),
        dialogButton(translate('OK'), onPressed: busy ? null : submit),
      ],
      onCancel: () => close(false),
    );
  });
}
