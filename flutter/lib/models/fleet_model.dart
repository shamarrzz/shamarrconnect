import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../utils/http_service.dart' as http;
import 'platform_model.dart';

/// One signed-in computer on this account (GET /api/user/fleet).
class FleetDevice {
  FleetDevice({
    required this.deviceId,
    required this.deviceName,
    required this.deviceOs,
    this.lastSeen,
    required this.online,
    this.ready,
    this.reason,
  });

  final String deviceId;
  final String deviceName;
  final String deviceOs;
  final DateTime? lastSeen;
  final bool online;
  final bool? ready;
  final String? reason;

  factory FleetDevice.fromJson(Map<String, dynamic> j) {
    return FleetDevice(
      deviceId: (j['device_id'] ?? '').toString(),
      deviceName: (j['device_name'] ?? '').toString(),
      deviceOs: (j['device_os'] ?? '').toString(),
      lastSeen: parseApiTime(j['last_seen']),
      online: j['online'] == true,
      ready: j['ready'] is bool ? j['ready'] as bool : null,
      reason: (j['reason'] is String && (j['reason'] as String).isNotEmpty)
          ? j['reason'] as String
          : null,
    );
  }
}

/// Parse SQLite `YYYY-MM-DD HH:MM:SS` (UTC) or ISO-8601.
DateTime? parseApiTime(dynamic raw) {
  if (raw == null) return null;
  var s = raw.toString().trim();
  if (s.isEmpty) return null;
  if (!s.contains('T')) {
    s = s.replaceFirst(' ', 'T');
  }
  if (!s.endsWith('Z') && !s.contains('+')) {
    s = '${s}Z';
  }
  return DateTime.tryParse(s)?.toLocal();
}

/// WhatsApp-plain last seen. Empty string if unknown.
String formatLastSeen(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  final sec = now.difference(t).inSeconds;
  if (sec < 45) return 'just now';
  if (sec < 3600) {
    final m = (sec / 60).round().clamp(1, 59);
    return '$m min ago';
  }
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final days = today.difference(day).inDays;
  if (days == 0) {
    if (t.hour < 12) return 'this morning';
    if (t.hour < 17) return 'this afternoon';
    return 'this evening';
  }
  if (days == 1) return 'yesterday';
  return '$days days ago';
}

/// Polls /api/user/fleet while signed in. Does not change the home screen.
class FleetModel {
  final RxList<FleetDevice> devices = <FleetDevice>[].obs;
  Timer? _timer;
  bool _busy = false;

  bool get isPolling => _timer != null;

  void start() {
    _timer?.cancel();
    pull();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => pull());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    devices.clear();
  }

  Future<void> pull() async {
    if (_busy) return;
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token.isEmpty) {
      stop();
      return;
    }
    _busy = true;
    try {
      final url = await bind.mainGetApiServer();
      final resp = await http.get(
        Uri.parse('$url/api/user/fleet'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode == 401 || resp.statusCode == 400) {
        stop();
        return;
      }
      if (resp.statusCode != 200) return;
      final body = jsonDecode(resp.body);
      if (body is! Map) return;
      final raw = body['devices'];
      if (raw is! List) return;
      devices.assignAll(
        raw
            .whereType<Map>()
            .map((e) => FleetDevice.fromJson(Map<String, dynamic>.from(e))),
      );
    } catch (e) {
      debugPrint('FleetModel.pull: $e');
    } finally {
      _busy = false;
    }
  }

  Future<bool> rename({
    required String deviceId,
    required String deviceName,
  }) async {
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token.isEmpty) return false;
    try {
      final url = await bind.mainGetApiServer();
      final resp = await http.patch(
        Uri.parse('$url/api/user/device-name'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'device_id': deviceId,
          'device_name': deviceName,
        }),
      );
      if (resp.statusCode != 200) return false;
      await pull();
      return true;
    } catch (e) {
      debugPrint('FleetModel.rename: $e');
      return false;
    }
  }
}
