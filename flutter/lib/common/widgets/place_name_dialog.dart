import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common.dart';
import '../../models/fleet_model.dart';
import '../../models/platform_model.dart';
import '../place_names.dart';

export '../place_names.dart' show looksLikeFactoryName;

const kPlaceNameChips = ['Office', 'Shop', 'Home', 'Workshop', 'Phone'];
const kPlaceNameOpt = 'sc_place_name';
const _kPlaceSkipOpt = 'sc_place_skip';

Future<void>? _placeNameInFlight;

void resetPlaceNamePrompt() {
  _placeNameInFlight = null;
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
      if (text.isEmpty) {
        close(null);
        return;
      }
      if (text.length > 40) {
        setState(() => error = 'Keep it under 40 characters.');
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
            'Call it whatever you want. Suggestions below are optional.',
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
        dialogButton('Skip', isOutline: true, onPressed: () {
          bind.mainSetLocalOption(key: _kPlaceSkipOpt, value: 'Y');
          close(null);
        }),
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
      if (sameDeviceId(d.deviceId, id)) {
        current = d.deviceName;
        break;
      }
    }
    final hostname = loginDeviceHostname();
    final saved = bind.mainGetLocalOption(key: kPlaceNameOpt);
    if (saved.trim().isNotEmpty &&
        !looksLikeFactoryName(saved, hostname: hostname)) {
      return;
    }
    if (!looksLikeFactoryName(current, hostname: hostname)) {
      await bind.mainSetLocalOption(key: kPlaceNameOpt, value: current.trim());
      return;
    }
    // Old sc_place_named=Y was set when the hostname was non-empty, so
    // testers never saw the prompt. Only honor an explicit Skip.
    if (bind.mainGetLocalOption(key: _kPlaceSkipOpt) == 'Y') return;
    final name = await showPlaceNameDialog(
      initial: looksLikeFactoryName(current, hostname: hostname)
          ? ''
          : current,
    );
    if (name == null || name.trim().isEmpty) return;
    final trimmed = name.trim();
    await bind.mainSetLocalOption(key: kPlaceNameOpt, value: trimmed);
    await gFFI.fleetModel.rename(deviceId: id, deviceName: trimmed);
    await bind.mainSetPeerAlias(id: id, alias: trimmed);
    try {
      await gFFI.abModel.changeAlias(id: id, alias: trimmed);
    } catch (_) {}
  } catch (e) {
    debugPrint('maybePromptPlaceNameAfterLogin: $e');
  }
}
