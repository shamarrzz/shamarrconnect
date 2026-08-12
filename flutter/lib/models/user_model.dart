import 'dart:async';
import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:get/get.dart';

import '../common.dart';
import '../utils/http_service.dart' as http;
import 'model.dart';
import 'platform_model.dart';

bool refreshingUser = false;

class UserModel {
  final RxString userName = ''.obs;
  final RxString displayName = ''.obs;
  final RxString avatar = ''.obs;
  final RxBool isAdmin = false.obs;
  final RxString networkError = ''.obs;
  bool get isLogin => userName.isNotEmpty;
  String get displayNameOrUserName =>
      displayName.value.trim().isEmpty ? userName.value : displayName.value;
  /// Single-line account label for Settings (avoid "name (@email)" doubling).
  String get accountLabelWithHandle {
    final username = userName.value.trim();
    if (username.isEmpty) {
      return '';
    }
    final preferred = displayName.value.trim();
    // SC accounts use email as `name` — show the email once.
    if (username.contains('@')) {
      if (preferred.isEmpty ||
          preferred.toLowerCase() == username.toLowerCase() ||
          username.toLowerCase().startsWith('${preferred.toLowerCase()}@')) {
        return username;
      }
      return '$preferred · $username';
    }
    if (preferred.isEmpty || preferred == username) {
      return username;
    }
    return '$preferred (@$username)';
  }

  /// Email-only when available (for neat Settings description).
  String get accountEmailLabel {
    final u = userName.value.trim();
    if (u.contains('@')) return u;
    return u;
  }

  /// Stable device identity for account device slots (survives reinstall).
  /// Android: `android:<ANDROID_ID>`. Else RustDesk machine uuid.
  static Future<String> accountDeviceUuid() async {
    if (isAndroid) {
      try {
        final id = await const MethodChannel('mChannel')
            .invokeMethod<String>('get_android_id');
        final s = (id ?? '').trim();
        if (s.isNotEmpty && s != 'null') {
          return 'android:$s';
        }
      } catch (e) {
        debugPrint('accountDeviceUuid android id: $e');
      }
    }
    return bind.mainGetUuid();
  }

  WeakReference<FFI> parent;

  UserModel(this.parent) {
    userName.listen((p0) {
      // When user name becomes empty, show login button
      // When user name becomes non-empty:
      //  For _updateLocalUserInfo, network error will be set later
      //  For login success, should clear network error
      networkError.value = '';
    });
  }

  Future<void> refreshCurrentUser() async {
    if (bind.isDisableAccount()) return;
    networkError.value = '';
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token == '') {
      await updateOtherModels();
      return;
    }
    _updateLocalUserInfo();
    final url = await bind.mainGetApiServer();
    final body = {
      'id': await bind.mainGetMyId(),
      'uuid': await accountDeviceUuid(),
    };
    if (refreshingUser) return;
    try {
      refreshingUser = true;
      final http.Response response;
      try {
        response = await http.post(Uri.parse('$url/api/currentUser'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token'
            },
            body: json.encode(body));
      } catch (e) {
        networkError.value = e.toString();
        rethrow;
      }
      refreshingUser = false;
      final status = response.statusCode;
      if (status == 401 || status == 400) {
        reset(resetOther: status == 401);
        return;
      }
      final data = json.decode(decode_http_response(response));
      final error = data['error'];
      if (error != null) {
        throw error;
      }

      final user = UserPayload.fromJson(data);
      _parseAndUpdateUser(user);
    } catch (e) {
      debugPrint('Failed to refreshCurrentUser: $e');
    } finally {
      refreshingUser = false;
      await updateOtherModels();
    }
  }

  static Map<String, dynamic>? getLocalUserInfo() {
    final userInfo = bind.mainGetLocalOption(key: 'user_info');
    if (userInfo == '') {
      return null;
    }
    try {
      return json.decode(userInfo);
    } catch (e) {
      debugPrint('Failed to get local user info "$userInfo": $e');
    }
    return null;
  }

  _updateLocalUserInfo() {
    final userInfo = getLocalUserInfo();
    if (userInfo != null) {
      userName.value = (userInfo['name'] ?? '').toString();
      displayName.value = (userInfo['display_name'] ?? '').toString();
      avatar.value = (userInfo['avatar'] ?? '').toString();
    }
  }

  Future<void> reset({bool resetOther = false}) async {
    await bind.mainSetLocalOption(key: 'access_token', value: '');
    await bind.mainSetLocalOption(key: 'user_info', value: '');
    if (resetOther) {
      await gFFI.abModel.reset();
      await gFFI.groupModel.reset();
    }
    userName.value = '';
    displayName.value = '';
    avatar.value = '';
  }

  _parseAndUpdateUser(UserPayload user) {
    userName.value = user.name;
    displayName.value = user.displayName;
    avatar.value = user.avatar;
    isAdmin.value = user.isAdmin;
    final encoded = jsonEncode(user);
    // Local (UI process) + shared Config via IPC so the Windows service
    // (same-account auto-auth) can read the logged-in account.
    bind.mainSetLocalOption(key: 'user_info', value: encoded);
    bind.mainSetOption(key: 'user_info', value: encoded);
    if (isWeb) {
      // ugly here, tmp solution
      bind.mainSetLocalOption(key: 'verifier', value: user.verifier ?? '');
    }
  }

  // update ab and group status
  static Future<void> updateOtherModels() async {
    await Future.wait([
      gFFI.abModel.pullAb(force: ForcePullAb.listAndCurrent, quiet: false),
      gFFI.groupModel.pull()
    ]);
  }

  Future<void> logOut({String? apiServer}) async {
    final tag = gFFI.dialogManager.showLoading(translate('Waiting'));
    try {
      final url = apiServer ?? await bind.mainGetApiServer();
      final authHeaders = getHttpHeaders();
      authHeaders['Content-Type'] = "application/json";
      await http
          .post(Uri.parse('$url/api/logout'),
              body: jsonEncode({
                'id': await bind.mainGetMyId(),
                'uuid': await accountDeviceUuid(),
              }),
              headers: authHeaders)
          .timeout(Duration(seconds: 2));
    } catch (e) {
      debugPrint("request /api/logout failed: err=$e");
    } finally {
      await reset(resetOther: true);
      gFFI.dialogManager.dismissByTag(tag);
    }
  }

  /// throw [RequestException]
  Future<LoginResponse> login(LoginRequest loginRequest) async {
    final url = await bind.mainGetApiServer();
    final resp = await http.post(Uri.parse('$url/api/login'),
        body: jsonEncode(loginRequest.toJson()));

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(decode_http_response(resp));
    } catch (e) {
      debugPrint("login: jsonDecode resp body failed: ${e.toString()}");
      if (resp.statusCode != 200) {
        BotToast.showText(
            contentColor: Colors.red, text: 'HTTP ${resp.statusCode}');
      }
      rethrow;
    }
    if (resp.statusCode != 200) {
      throw RequestException(resp.statusCode, body['error'] ?? '');
    }
    if (body['error'] != null) {
      throw RequestException(0, body['error']);
    }

    return getLoginResponseFromAuthBody(body);
  }

  // ── Account MFA (sign-in protection) ──────────────────────────────────────

  Future<Map<String, String>> _authJsonHeaders() async {
    final token = bind.mainGetLocalOption(key: 'access_token');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _mfaRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final url = await bind.mainGetApiServer();
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token.isEmpty) {
      throw RequestException(401, 'Not logged in');
    }
    final headers = await _authJsonHeaders();
    final uri = Uri.parse('$url$path');
    final http.Response resp;
    if (method == 'GET') {
      resp = await http.get(uri, headers: headers);
    } else {
      resp = await http.post(uri,
          headers: headers, body: body == null ? null : jsonEncode(body));
    }
    final raw = decode_http_response(resp).trim();
    Map<String, dynamic> data = {};
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw RequestException(resp.statusCode, 'Invalid server response');
        }
        // Empty / non-JSON success body (e.g. password change → 200).
      }
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw RequestException(
          resp.statusCode, (data['error'] ?? 'Request failed').toString());
    }
    if (data['error'] != null) {
      throw RequestException(0, data['error'].toString());
    }
    return data;
  }

  /// Whether account MFA (login second factor) is enabled.
  Future<bool> mfaStatus() async {
    final data = await _mfaRequest('GET', '/api/user/mfa/status');
    return data['enabled'] == true;
  }

  /// Start enrollment. Returns secret + otpauth_url for QR.
  Future<Map<String, dynamic>> mfaSetup() async {
    return _mfaRequest('POST', '/api/user/mfa/setup');
  }

  /// Confirm enrollment with a live TOTP code. Returns recovery_codes once.
  Future<List<String>> mfaConfirm(String code) async {
    final data =
        await _mfaRequest('POST', '/api/user/mfa/confirm', body: {'code': code});
    final codes = data['recovery_codes'];
    if (codes is List) {
      return codes.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Disable MFA (requires account password + TOTP or recovery code).
  Future<void> mfaDisable({required String password, required String code}) async {
    await _mfaRequest('POST', '/api/user/mfa/disable', body: {
      'password': password,
      'code': code,
    });
  }

  /// Change account password. Optionally sign out other devices.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    bool revokeOtherDevices = false,
  }) async {
    final id = await bind.mainGetMyId();
    final uuid = await accountDeviceUuid();
    await _mfaRequest('POST', '/api/user/password', body: {
      'current_password': currentPassword,
      'new_password': newPassword,
      'revoke_other_devices': revokeOtherDevices,
      'id': id,
      'uuid': uuid,
    });
  }

  /// List signed-in devices (device tokens) for this account.
  Future<List<Map<String, dynamic>>> listSignedInDevices() async {
    final data = await _mfaRequest('GET', '/api/user/devices');
    final raw = data['devices'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Revoke one device token by its row id.
  Future<void> revokeDevice(String deviceTokenId) async {
    final url = await bind.mainGetApiServer();
    final headers = await _authJsonHeaders();
    final resp = await http.delete(
      Uri.parse('$url/api/user/device/$deviceTokenId'),
      headers: headers,
    );
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      String msg = 'Failed to sign out device';
      try {
        final body = jsonDecode(decode_http_response(resp));
        if (body is Map && body['error'] != null) {
          msg = body['error'].toString();
        }
      } catch (_) {}
      throw RequestException(resp.statusCode, msg);
    }
  }

  /// Keep this device; sign out all others.
  Future<int> revokeOtherDevices() async {
    final id = await bind.mainGetMyId();
    final uuid = await accountDeviceUuid();
    final data = await _mfaRequest('POST', '/api/user/devices/revoke-others', body: {
      'id': id,
      'uuid': uuid,
    });
    final n = data['revoked'];
    if (n is int) return n;
    if (n is num) return n.toInt();
    return 0;
  }

  /// Generate a device enrollment code for the currently-logged-in account.
  /// Returns the 6-character code string, or null on failure.
  Future<String?> enrollGenerate() async {
    try {
      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');
      if (token.isEmpty) return null;
      final resp = await http.post(
        Uri.parse('$url/api/enroll/generate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(decode_http_response(resp));
        return body['code'] as String?;
      }
      debugPrint('enrollGenerate: HTTP ${resp.statusCode}');
    } catch (e) {
      debugPrint('enrollGenerate failed: $e');
    }
    return null;
  }

  /// Claim a device enrollment code — joins an existing account without a password.
  /// throw [RequestException]
  Future<LoginResponse> enrollClaim({
    required String code,
    required String id,
    required String uuid,
    String deviceName = '',
    String os = '',
  }) async {
    final url = await bind.mainGetApiServer();
    final resp = await http.post(
      Uri.parse('$url/api/enroll/claim'),
      body: jsonEncode({
        'code': code,
        'id': id,
        'uuid': uuid,
        'device_name': deviceName,
        'os': os,
      }),
    );

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(decode_http_response(resp));
    } catch (e) {
      debugPrint('enrollClaim: jsonDecode failed: $e');
      if (resp.statusCode != 200) {
        BotToast.showText(
            contentColor: Colors.red, text: 'HTTP ${resp.statusCode}');
      }
      rethrow;
    }
    if (resp.statusCode != 200) {
      throw RequestException(resp.statusCode, body['error'] ?? '');
    }
    if (body['error'] != null) {
      throw RequestException(0, body['error']);
    }
    return getLoginResponseFromAuthBody(body);
  }

  /// throw [RequestException]
  Future<LoginResponse> register({
    required String email,
    required String password,
    required String id,
    required String uuid,
    String deviceName = '',
    String os = '',
  }) async {
    final url = await bind.mainGetApiServer();
    final resp = await http.post(
      Uri.parse('$url/api/register'),
      body: jsonEncode({
        'email': email,
        'password': password,
        'id': id,
        'uuid': uuid,
        'device_name': deviceName,
        'os': os,
      }),
    );

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(decode_http_response(resp));
    } catch (e) {
      debugPrint("register: jsonDecode resp body failed: ${e.toString()}");
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        BotToast.showText(
            contentColor: Colors.red, text: 'HTTP ${resp.statusCode}');
      }
      rethrow;
    }
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw RequestException(resp.statusCode, body['error'] ?? '');
    }
    if (body['error'] != null) {
      throw RequestException(0, body['error']);
    }

    return getLoginResponseFromAuthBody(body);
  }

  LoginResponse getLoginResponseFromAuthBody(Map<String, dynamic> body) {
    final LoginResponse loginResponse;
    try {
      loginResponse = LoginResponse.fromJson(body);
    } catch (e) {
      debugPrint("login: jsonDecode LoginResponse failed: ${e.toString()}");
      rethrow;
    }

    final isLogInDone = loginResponse.type == HttpType.kAuthResTypeToken &&
        loginResponse.access_token != null;
    if (isLogInDone && loginResponse.user != null) {
      _parseAndUpdateUser(loginResponse.user!);
    }

    return loginResponse;
  }

  static Future<List<dynamic>> queryOidcLoginOptions() async {
    try {
      final url = await bind.mainGetApiServer();
      if (url.trim().isEmpty) return [];
      final resp = await http.get(Uri.parse('$url/api/login-options'));
      final List<String> ops = [];
      for (final item in jsonDecode(resp.body)) {
        ops.add(item as String);
      }
      for (final item in ops) {
        if (item.startsWith('common-oidc/')) {
          return jsonDecode(item.substring('common-oidc/'.length));
        }
      }
      return ops
          .where((item) => item.startsWith('oidc/'))
          .map((item) => {'name': item.substring('oidc/'.length)})
          .toList();
    } catch (e) {
      debugPrint(
          "queryOidcLoginOptions: jsonDecode resp body failed: ${e.toString()}");
      return [];
    }
  }
}
