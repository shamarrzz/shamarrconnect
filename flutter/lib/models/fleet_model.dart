import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../common/place_names.dart';
import '../utils/http_service.dart' as http;
import 'platform_model.dart';

/// One signed-in computer on this account (GET /api/user/fleet).
class FleetDevice {
  FleetDevice({
    required this.deviceId,
    this.deviceUuid = '',
    required this.deviceName,
    required this.deviceOs,
    this.lastSeen,
    required this.online,
    this.ready,
    this.reason,
  });

  final String deviceId;
  final String deviceUuid;
  final String deviceName;
  final String deviceOs;
  final DateTime? lastSeen;
  final bool online;
  final bool? ready;
  final String? reason;

  factory FleetDevice.fromJson(Map<String, dynamic> j) {
    return FleetDevice(
      deviceId: (j['device_id'] ?? '').toString(),
      deviceUuid: (j['device_uuid'] ?? '').toString(),
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

  FleetDevice copyWith({String? deviceName}) {
    return FleetDevice(
      deviceId: deviceId,
      deviceUuid: deviceUuid,
      deviceName: deviceName ?? this.deviceName,
      deviceOs: deviceOs,
      lastSeen: lastSeen,
      online: online,
      ready: ready,
      reason: reason,
    );
  }
}

/// RustDesk IDs are shown with spaces (`1 893 760 099`) and stored without.
String compactDeviceId(String id) => id.replaceAll(RegExp(r'\s+'), '');

bool sameDeviceId(String a, String b) =>
    a == b || compactDeviceId(a) == compactDeviceId(b);

bool _unnamed(String name) {
  final u = name.trim().toLowerCase();
  return u.isEmpty ||
      u == 'computer' ||
      u == 'this computer' ||
      u == 'this phone' ||
      u == 'windows pc' ||
      u == 'linux pc' ||
      u == 'mac';
}

String osFamily(String os) {
  final u = os.trim().toLowerCase();
  if (u.contains('android')) return 'android';
  if (u.contains('win')) return 'windows';
  if (u.contains('mac') || u.contains('ios') || u.contains('darwin')) {
    return 'mac';
  }
  if (u.contains('linux') ||
      u.contains('ubuntu') ||
      u.contains('debian') ||
      u.contains('fedora')) {
    return 'linux';
  }
  return u;
}

String fleetIdentity(FleetDevice d) {
  final uuid = d.deviceUuid.trim();
  if (uuid.isNotEmpty) return 'u:$uuid';
  return 'i:${compactDeviceId(d.deviceId)}';
}

/// One card per box. Stale factory-named clones (two samsung-SM-A037U
/// cards from an old ID) collapse. Two live phones of the same model stay.
List<FleetDevice> dedupeFleetDevices(List<FleetDevice> raw) {
  final newestFirst = [...raw]..sort((a, b) {
      final at = a.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
  final byId = <String, FleetDevice>{};
  for (final d in newestFirst) {
    byId.putIfAbsent(fleetIdentity(d), () => d);
  }
  final kept = <FleetDevice>[];
  outer:
  for (final r in byId.values) {
    for (var i = 0; i < kept.length; i++) {
      final k = kept[i];
      final sameFamily = osFamily(k.deviceOs) == osFamily(r.deviceOs) &&
          osFamily(k.deviceOs).isNotEmpty;
      final unnamed = _unnamed(k.deviceName) && _unnamed(r.deviceName);
      final sameFactoryName = looksLikeFactoryName(k.deviceName) &&
          looksLikeFactoryName(r.deviceName) &&
          k.deviceName.trim().toLowerCase() ==
              r.deviceName.trim().toLowerCase();
      if (sameFamily && unnamed) {
        if (r.online && !k.online) kept[i] = r;
        continue outer;
      }
      if (sameFactoryName && sameFamily && (!k.online || !r.online)) {
        if (r.online && !k.online) kept[i] = r;
        continue outer;
      }
    }
    kept.add(r);
  }
  return kept;
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
      devices.assignAll(dedupeFleetDevices([
        for (final e in raw.whereType<Map>())
          FleetDevice.fromJson(Map<String, dynamic>.from(e)),
      ]));
    } catch (e) {
      debugPrint('FleetModel.pull: $e');
    } finally {
      _busy = false;
    }
  }

  /// Show the new name on the desk immediately. Pull may overwrite later.
  void applyLocalName(String deviceId, String deviceName) {
    devices.assignAll([
      for (final d in devices)
        sameDeviceId(d.deviceId, deviceId)
            ? d.copyWith(deviceName: deviceName)
            : d,
    ]);
  }

  Future<bool> rename({
    required String deviceId,
    required String deviceName,
    String deviceUuid = '',
  }) async {
    applyLocalName(deviceId, deviceName);
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token.isEmpty) return false;
    try {
      final url = await bind.mainGetApiServer();
      var uuid = deviceUuid.trim();
      if (uuid.isEmpty) {
        for (final d in devices) {
          if (sameDeviceId(d.deviceId, deviceId) && d.deviceUuid.trim().isNotEmpty) {
            uuid = d.deviceUuid.trim();
            break;
          }
        }
      }
      final resp = await http.patch(
        Uri.parse('$url/api/user/device-name'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'device_id': deviceId,
          'device_uuid': uuid,
          'device_name': deviceName,
        }),
      );
      if (resp.statusCode != 200) {
        debugPrint('FleetModel.rename: HTTP ${resp.statusCode} ${resp.body}');
        return false;
      }
      await pull();
      applyLocalName(deviceId, deviceName);
      return true;
    } catch (e) {
      debugPrint('FleetModel.rename: $e');
      return false;
    }
  }
}
