import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../consts.dart';
import '../../../models/platform_model.dart';

/// Last opened computer + last screen snapshot for the desk.
class DeskMemory {
  static const lastKey = 'sc_desk_last';
  /// Wait until the session is past the remote's own home chrome (old ID pad).
  static const captureDelay = Duration(seconds: 8);
  static Directory? _dir;
  static final Map<String, String> pending = {};

  static String lastId() => bind.mainGetLocalOption(key: lastKey);

  static void remember(String id) {
    if (id.isEmpty) return;
    bind.mainSetLocalOption(key: lastKey, value: id);
  }

  static Future<Directory> _thumbs() async {
    if (_dir != null) return _dir!;
    final root = await getApplicationSupportDirectory();
    final d = Directory('${root.path}/desk_thumbs');
    await d.create(recursive: true);
    _dir = d;
    return d;
  }

  static String _safe(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static Future<String> pathFor(String id) async {
    final d = await _thumbs();
    return '${d.path}/${_safe(id)}.png';
  }

  static File? fileIfPresent(String id) {
    final d = _dir;
    if (d == null) return null;
    final f = File('${d.path}/${_safe(id)}.png');
    return f.existsSync() ? f : null;
  }

  static Future<void> clear(String id) async {
    if (id.isEmpty) return;
    try {
      await warmup();
      final f = fileIfPresent(id);
      if (f != null) await f.delete();
    } catch (e) {
      debugPrint('desk thumb clear: $e');
    }
  }

  static Widget? preview(String id) {
    if (kIsWeb) return null;
    final f = fileIfPresent(id);
    if (f == null) return null;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Image.file(
          f,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  static Future<void> warmup() async {
    if (kIsWeb) return;
    try {
      await _thumbs();
    } catch (e) {
      debugPrint('desk thumbs: $e');
    }
  }

  /// After the remote picture is up, grab a still for the desk card.
  static Future<void> capture({
    required UuidValue sessionId,
    required String peerId,
    required int display,
  }) async {
    if (kIsWeb || peerId.isEmpty) return;
    try {
      final supported = bind.sessionGetCommonSync(
          sessionId: sessionId, key: 'is_screenshot_supported', param: '');
      if (supported != 'true') return;
      final path = await pathFor(peerId);
      pending[sessionId.toString()] = path;
      await bind.sessionTakeScreenshot(sessionId: sessionId, display: display);
    } catch (e) {
      debugPrint('desk capture: $e');
    }
  }

  static bool consumeSilent(UuidValue sessionId, String msg) {
    final path = pending.remove(sessionId.toString());
    if (path == null) return false;
    if (msg.isNotEmpty) return true;
    bind.sessionHandleScreenshot(sessionId: sessionId, action: '0:$path');
    return true;
  }

  /// One-time: sessions open in their own window so they can sit on another screen.
  static void preferOwnWindow() {
    if (bind.mainGetLocalOption(key: kOptionOpenNewConnInTabs).isEmpty) {
      bind.mainSetLocalOption(key: kOptionOpenNewConnInTabs, value: 'N');
    }
  }
}
