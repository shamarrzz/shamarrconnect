import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

const kPlaceNameChips = ['Office', 'Shop', 'Home', 'Workshop', 'Phone'];

Future<void>? _placeNameInFlight;

void resetPlaceNamePrompt() {
  _placeNameInFlight = null;
}

/// True when [name] is empty or looks like a factory hostname, not a place.
bool looksLikeFactoryName(String name, {String hostname = ''}) {
  final n = name.trim();
  if (n.isEmpty) return true;
  if (hostname.isNotEmpty && n.toLowerCase() == hostname.toLowerCase()) {
    return true;
  }
  final u = n.toUpperCase();
  if (u.startsWith('DESKTOP-') ||
      u.startsWith('LAPTOP-') ||
      u.startsWith('WIN-') ||
      u.startsWith('MACBOOK') ||
      u.startsWith('IMAC') ||
      u.startsWith('IPHONE') ||
      u.startsWith('IPAD') ||
      u.startsWith('PIXEL') ||
      u.startsWith('SM-') ||
      u.startsWith('GALAXY')) {
    return true;
  }
  if (n.contains('.') && !n.contains(' ')) return true;
  if (RegExp(r'^[A-Z0-9_-]{8,}$').hasMatch(u) && !n.contains(' ')) {
    return true;
  }
  return false;
}

String loginDeviceHostname() {
  try {
    final info = jsonDecode(bind.mainGetLoginDeviceInfo());
    if (info is Map) {
      final name = (info['name'] ?? info['hostname'] ?? '').toString();
      return name.trim();
    }
  } catch (_) {}
  return '';
}

Future<String?> showPlaceNameDialog({String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  String? error;
  return gFFI.dialogManager.show<String>((setState, close, context) {
    void pick(String chip) {
      setState(() {
        controller.text = chip;
        error = null;
      });
    }

    Future<void> submit() async {
      final text = controller.text.trim();
      final n = text.length;
      if (n < 2 || n > 40) {
        setState(() => error = 'Use 2 to 40 characters.');
        return;
      }
      if (looksLikeFactoryName(text, hostname: loginDeviceHostname())) {
        setState(() =>
            error = 'Pick a name you will recognise, like Shop or Office.');
        return;
      }
      close(text);
    }

    return CustomAlertDialog(
      title: const Text('What do you call this computer?'),
      contentBoxConstraints: const BoxConstraints(minWidth: 320, maxWidth: 400),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A name you will recognise. Not the computer\'s factory name.',
            style: TextStyle(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in kPlaceNameChips)
                ActionChip(
                  label: Text(chip),
                  onPressed: () => pick(chip),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 40,
            inputFormatters: [
              LengthLimitingTextInputFormatter(40),
            ],
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => submit(),
          ),
        ],
      ),
      actions: [
        dialogButton('Save', onPressed: () { submit(); }),
      ],
      onSubmit: () { submit(); },
      onCancel: () => close(null),
    );
  });
}

/// After sign-in, name this machine if the account still has a hostname.
Future<void> maybePromptPlaceNameAfterLogin() {
  _placeNameInFlight ??= _runPlaceNamePrompt().whenComplete(() {
    _placeNameInFlight = null;
  });
  return _placeNameInFlight!;
}

Future<void> _runPlaceNamePrompt() async {
  try {
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token.isEmpty) return;
    final id = await bind.mainGetMyId();
    if (id.isEmpty) return;
    await gFFI.fleetModel.pull();
    var current = '';
    for (final d in gFFI.fleetModel.devices) {
      if (d.deviceId == id) {
        current = d.deviceName;
        break;
      }
    }
    final hostname = loginDeviceHostname();
    if (!looksLikeFactoryName(current, hostname: hostname) &&
        current.trim().length >= 2) {
      return;
    }
    final name = await showPlaceNameDialog(initial: '');
    if (name == null || name.trim().length < 2) return;
    final trimmed = name.trim();
    await gFFI.fleetModel.rename(deviceId: id, deviceName: trimmed);
    await bind.mainSetPeerAlias(id: id, alias: trimmed);
    try {
      await gFFI.abModel.changeAlias(id: id, alias: trimmed);
    } catch (_) {}
  } catch (e) {
    debugPrint('maybePromptPlaceNameAfterLogin: $e');
  }
}
