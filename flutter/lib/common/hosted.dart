import 'dart:convert';

import '../models/platform_model.dart';
import 'place_names.dart';

/// Hosted ShamarrConnect client (store / AppImage / public exe).
bool isHostedClient() => bind.isCustomClient();

String defaultPlaceNameForOs() {
  try {
    final info = jsonDecode(bind.mainGetLoginDeviceInfo());
    if (info is Map) {
      final os = (info['os'] ?? '').toString().toLowerCase();
      if (os.contains('android') || os.contains('ios')) return 'This phone';
      if (os.contains('windows')) return 'Windows PC';
      if (os.contains('mac')) return 'Mac';
    }
  } catch (_) {}
  return 'Linux PC';
}

String _loginHostname() {
  try {
    final info = jsonDecode(bind.mainGetLoginDeviceInfo());
    if (info is Map) {
      return (info['name'] ?? info['hostname'] ?? '').toString().trim();
    }
  } catch (_) {}
  return '';
}

/// Name we send on login: saved place, else generic OS, never a factory hostname.
String loginDeviceName() {
  final host = _loginHostname();
  final saved = bind.mainGetLocalOption(key: 'sc_place_name').trim();
  if (saved.isNotEmpty && !looksLikeFactoryName(saved, hostname: host)) {
    return saved;
  }
  if (host.isNotEmpty && !looksLikeFactoryName(host, hostname: host)) {
    return host;
  }
  return defaultPlaceNameForOs();
}
