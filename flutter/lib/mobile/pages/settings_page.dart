import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/setting_widgets.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../common.dart';
import '../../common/hbbs/hbbs.dart';
import '../../common/widgets/dialog.dart';
import '../../common/widgets/account_mfa.dart';
import '../../common/widgets/login.dart';
import '../../consts.dart';
import '../../models/model.dart';
import '../../models/platform_model.dart';
import '../../models/user_model.dart';
import '../widgets/deploy_dialog.dart';
import '../widgets/dialog.dart';
import 'home_page.dart';
import 'scan_page.dart';

class SettingsPage extends StatefulWidget implements PageShape {
  @override
  final title = translate("Settings");

  @override
  final icon = Icon(Icons.settings);

  @override
  final appBarActions = bind.isDisableSettings() ? [] : [ScanButton()];

  @override
  State<SettingsPage> createState() => _SettingsState();
}

const url = 'https://shamarrconnect.com/';

enum KeepScreenOn {
  never,
  duringControlled,
  serviceOn,
}

String _keepScreenOnToOption(KeepScreenOn value) {
  switch (value) {
    case KeepScreenOn.never:
      return 'never';
    case KeepScreenOn.duringControlled:
      return 'during-controlled';
    case KeepScreenOn.serviceOn:
      return 'service-on';
  }
}

KeepScreenOn optionToKeepScreenOn(String value) {
  switch (value) {
    case 'never':
      return KeepScreenOn.never;
    case 'service-on':
      return KeepScreenOn.serviceOn;
    default:
      return KeepScreenOn.duringControlled;
  }
}

class _SettingsState extends State<SettingsPage> with WidgetsBindingObserver {
  final _hasIgnoreBattery =
      false; //androidVersion >= 26; // remove because not work on every device
  var _ignoreBatteryOpt = false;
  var _enableStartOnBoot = false;
  var _checkUpdateOnStartup = false;
  var _showTerminalExtraKeys = false;
  var _floatingWindowDisabled = false;
  var _keepScreenOn = KeepScreenOn.duringControlled; // relay on floating window
  var _enableAbr = false;
  var _denyLANDiscovery = false;
  var _onlyWhiteList = false;
  var _enableDirectIPAccess = false;
  var _enableRecordSession = false;
  var _enableHardwareCodec = false;
  var _allowWebSocket = false;
  var _autoRecordIncomingSession = false;
  var _autoRecordOutgoingSession = false;
  var _allowAutoDisconnect = false;
  var _localIP = "";
  var _directAccessPort = "";
  var _fingerprint = "";
  var _buildDate = "";
  var _autoDisconnectTimeout = "";
  var _hideServer = false;
  var _hideProxy = false;
  var _hideNetwork = false;
  var _hideWebSocket = false;
  var _enableTrustedDevices = false;
  var _enableUdpPunch = false;
  var _allowInsecureTlsFallback = false;
  var _disableUdp = false;
  var _enableIpv6Punch = false;
  var _isUsingPublicServer = false;
  var _allowAskForNoteAtEndOfConnection = false;
  var _preventSleepWhileConnected = true;
  var _dataSaver = false;

  _SettingsState() {
    _enableAbr = option2bool(
        kOptionEnableAbr, bind.mainGetOptionSync(key: kOptionEnableAbr));
    _denyLANDiscovery = !option2bool(kOptionEnableLanDiscovery,
        bind.mainGetOptionSync(key: kOptionEnableLanDiscovery));
    _onlyWhiteList = whitelistNotEmpty();
    _enableDirectIPAccess = option2bool(
        kOptionDirectServer, bind.mainGetOptionSync(key: kOptionDirectServer));
    _enableRecordSession = option2bool(kOptionEnableRecordSession,
        bind.mainGetOptionSync(key: kOptionEnableRecordSession));
    _enableHardwareCodec = option2bool(kOptionEnableHwcodec,
        bind.mainGetOptionSync(key: kOptionEnableHwcodec));
    _allowWebSocket = mainGetBoolOptionSync(kOptionAllowWebSocket);
    _allowInsecureTlsFallback =
        mainGetBoolOptionSync(kOptionAllowInsecureTLSFallback);
    _disableUdp = bind.mainGetOptionSync(key: kOptionDisableUdp) == 'Y';
    _autoRecordIncomingSession = option2bool(kOptionAllowAutoRecordIncoming,
        bind.mainGetOptionSync(key: kOptionAllowAutoRecordIncoming));
    _autoRecordOutgoingSession = option2bool(kOptionAllowAutoRecordOutgoing,
        bind.mainGetLocalOption(key: kOptionAllowAutoRecordOutgoing));
    _localIP = bind.mainGetOptionSync(key: 'local-ip-addr');
    _directAccessPort = bind.mainGetOptionSync(key: kOptionDirectAccessPort);
    _dataSaver = bind.mainGetLocalOption(key: 'data_saver') == 'Y';
    _allowAutoDisconnect = option2bool(kOptionAllowAutoDisconnect,
        bind.mainGetOptionSync(key: kOptionAllowAutoDisconnect));
    _autoDisconnectTimeout =
        bind.mainGetOptionSync(key: kOptionAutoDisconnectTimeout);
    _hideServer =
        bind.mainGetBuildinOption(key: kOptionHideServerSetting) == 'Y';
    _hideProxy = bind.mainGetBuildinOption(key: kOptionHideProxySetting) == 'Y';
    _hideNetwork =
        bind.mainGetBuildinOption(key: kOptionHideNetworkSetting) == 'Y';
    _hideWebSocket =
        bind.mainGetBuildinOption(key: kOptionHideWebSocketSetting) == 'Y' ||
            isWeb;
    _enableTrustedDevices = mainGetBoolOptionSync(kOptionEnableTrustedDevices);
    _enableUdpPunch = mainGetLocalBoolOptionSync(kOptionEnableUdpPunch);
    _enableIpv6Punch = mainGetLocalBoolOptionSync(kOptionEnableIpv6Punch);
    _allowAskForNoteAtEndOfConnection =
        mainGetLocalBoolOptionSync(kOptionAllowAskForNoteAtEndOfConnection);
    _preventSleepWhileConnected =
        mainGetLocalBoolOptionSync(kOptionKeepAwakeDuringOutgoingSessions);
    _showTerminalExtraKeys =
        mainGetLocalBoolOptionSync(kOptionEnableShowTerminalExtraKeys);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var update = false;

      if (_hasIgnoreBattery) {
        if (await checkAndUpdateIgnoreBatteryStatus()) {
          update = true;
        }
      }

      if (await checkAndUpdateStartOnBoot()) {
        update = true;
      }

      // start on boot depends on ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS and SYSTEM_ALERT_WINDOW
      var enableStartOnBoot =
          await gFFI.invokeMethod(AndroidChannel.kGetStartOnBootOpt);
      if (enableStartOnBoot) {
        if (!await canStartOnBoot()) {
          enableStartOnBoot = false;
          gFFI.invokeMethod(AndroidChannel.kSetStartOnBootOpt, false);
        }
      }

      if (enableStartOnBoot != _enableStartOnBoot) {
        update = true;
        _enableStartOnBoot = enableStartOnBoot;
      }

      var checkUpdateOnStartup =
          mainGetLocalBoolOptionSync(kOptionEnableCheckUpdate);
      if (checkUpdateOnStartup != _checkUpdateOnStartup) {
        update = true;
        _checkUpdateOnStartup = checkUpdateOnStartup;
      }

      var floatingWindowDisabled =
          bind.mainGetLocalOption(key: kOptionDisableFloatingWindow) == "Y" ||
              !await AndroidPermissionManager.check(kSystemAlertWindow);
      if (floatingWindowDisabled != _floatingWindowDisabled) {
        update = true;
        _floatingWindowDisabled = floatingWindowDisabled;
      }

      final keepScreenOn = _floatingWindowDisabled
          ? KeepScreenOn.never
          : optionToKeepScreenOn(
              bind.mainGetLocalOption(key: kOptionKeepScreenOn));
      if (keepScreenOn != _keepScreenOn) {
        update = true;
        _keepScreenOn = keepScreenOn;
      }

      final fingerprint = await bind.mainGetFingerprint();
      if (_fingerprint != fingerprint) {
        update = true;
        _fingerprint = fingerprint;
      }

      final buildDate = await bind.mainGetBuildDate();
      if (_buildDate != buildDate) {
        update = true;
        _buildDate = buildDate;
      }

      final isUsingPublicServer = await bind.mainIsUsingPublicServer();
      if (_isUsingPublicServer != isUsingPublicServer) {
        update = true;
        _isUsingPublicServer = isUsingPublicServer;
      }

      if (update) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      () async {
        final ibs = await checkAndUpdateIgnoreBatteryStatus();
        final sob = await checkAndUpdateStartOnBoot();
        if (ibs || sob) {
          setState(() {});
        }
      }();
    }
  }

  Future<bool> checkAndUpdateIgnoreBatteryStatus() async {
    final res = await AndroidPermissionManager.check(
        kRequestIgnoreBatteryOptimizations);
    if (_ignoreBatteryOpt != res) {
      _ignoreBatteryOpt = res;
      return true;
    } else {
      return false;
    }
  }

  Future<bool> checkAndUpdateStartOnBoot() async {
    if (!await canStartOnBoot() && _enableStartOnBoot) {
      _enableStartOnBoot = false;
      debugPrint(
          "checkAndUpdateStartOnBoot and set _enableStartOnBoot -> false");
      gFFI.invokeMethod(AndroidChannel.kSetStartOnBootOpt, false);
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<FfiModel>(context);
    final outgoingOnly = bind.isOutgoingOnly();
    final incomingOnly = bind.isIncomingOnly();
    // No header logo/wordmark (was hard to see and not needed).
    // "Powered by RustDesk" stays as a footer under About.
    final List<AbstractSettingsTile> enhancementsTiles = [];
    final enable2fa = bind.mainHasValid2FaSync();
    final List<AbstractSettingsTile> tfaTiles = [
      SettingsTile.switchTile(
        title: Text(translate('enable-2fa-title')),
        initialValue: enable2fa,
        onToggle: (v) async {
          update() async {
            setState(() {});
          }

          if (v == false) {
            CommonConfirmDialog(
                gFFI.dialogManager, translate('cancel-2fa-confirm-tip'), () {
              change2fa(callback: update);
            });
          } else {
            change2fa(callback: update);
          }
        },
      ),
      if (enable2fa)
        SettingsTile.switchTile(
          title: Text(translate('Telegram bot')),
          initialValue: bind.mainHasValidBotSync(),
          onToggle: (v) async {
            update() async {
              setState(() {});
            }

            if (v == false) {
              CommonConfirmDialog(
                  gFFI.dialogManager, translate('cancel-bot-confirm-tip'), () {
                changeBot(callback: update);
              });
            } else {
              changeBot(callback: update);
            }
          },
        ),
      if (enable2fa)
        SettingsTile.switchTile(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(translate('Enable trusted devices')),
              Text(
                  '* Skip 2FA on reconnect only for devices you mark trusted. '
                  'Every other reconnect re-prompts for a code.',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          initialValue: _enableTrustedDevices,
          onToggle: isOptionFixed(kOptionEnableTrustedDevices)
              ? null
              : (v) async {
                  mainSetBoolOption(kOptionEnableTrustedDevices, v);
                  setState(() {
                    _enableTrustedDevices = v;
                  });
                },
        ),
      if (enable2fa && _enableTrustedDevices)
        SettingsTile(
            title: Text(translate('Manage trusted devices')),
            trailing: Icon(Icons.arrow_forward_ios),
            onPressed: (context) {
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return _ManageTrustedDevices();
              }));
            })
    ];
    final List<AbstractSettingsTile> shareScreenTiles = [
      SettingsTile.switchTile(
        title: Text(translate('Deny LAN discovery')),
        initialValue: _denyLANDiscovery,
        onToggle: isOptionFixed(kOptionEnableLanDiscovery)
            ? null
            : (v) async {
                await bind.mainSetOption(
                    key: kOptionEnableLanDiscovery,
                    value: bool2option(kOptionEnableLanDiscovery, !v));
                final newValue = !option2bool(kOptionEnableLanDiscovery,
                    await bind.mainGetOption(key: kOptionEnableLanDiscovery));
                setState(() {
                  _denyLANDiscovery = newValue;
                });
              },
      ),
      SettingsTile.switchTile(
        title: Row(children: [
          Expanded(child: Text(translate('Use IP Whitelisting'))),
          Offstage(
                  offstage: !_onlyWhiteList,
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Color.fromARGB(255, 255, 204, 0)))
              .marginOnly(left: 5)
        ]),
        initialValue: _onlyWhiteList,
        onToggle: (_) async {
          update() async {
            final onlyWhiteList = whitelistNotEmpty();
            if (onlyWhiteList != _onlyWhiteList) {
              setState(() {
                _onlyWhiteList = onlyWhiteList;
              });
            }
          }

          changeWhiteList(callback: update);
        },
      ),
      SettingsTile.switchTile(
        title: Text(translate('Adaptive bitrate')),
        initialValue: _enableAbr,
        onToggle: isOptionFixed(kOptionEnableAbr)
            ? null
            : (v) async {
                await mainSetBoolOption(kOptionEnableAbr, v);
                final newValue = await mainGetBoolOption(kOptionEnableAbr);
                setState(() {
                  _enableAbr = newValue;
                });
              },
      ),
      SettingsTile.switchTile(
        title: Text(translate('Enable recording session')),
        initialValue: _enableRecordSession,
        onToggle: isOptionFixed(kOptionEnableRecordSession)
            ? null
            : (v) async {
                await mainSetBoolOption(kOptionEnableRecordSession, v);
                final newValue =
                    await mainGetBoolOption(kOptionEnableRecordSession);
                setState(() {
                  _enableRecordSession = newValue;
                });
              },
      ),
      SettingsTile.switchTile(
        title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(translate("Direct IP Access")),
                    Offstage(
                        offstage: !_enableDirectIPAccess,
                        child: Text(
                          '${translate("Local Address")}: $_localIP${_directAccessPort.isEmpty ? "" : ":$_directAccessPort"}',
                          style: Theme.of(context).textTheme.bodySmall,
                        )),
                  ])),
              Offstage(
                  offstage: !_enableDirectIPAccess,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.edit,
                        size: 20,
                      ),
                      onPressed: isOptionFixed(kOptionDirectAccessPort)
                          ? null
                          : () async {
                              final port = await changeDirectAccessPort(
                                  _localIP, _directAccessPort);
                              setState(() {
                                _directAccessPort = port;
                              });
                            }))
            ]),
        initialValue: _enableDirectIPAccess,
        onToggle: isOptionFixed(kOptionDirectServer)
            ? null
            : (_) async {
                _enableDirectIPAccess = !_enableDirectIPAccess;
                String value =
                    bool2option(kOptionDirectServer, _enableDirectIPAccess);
                await bind.mainSetOption(
                    key: kOptionDirectServer, value: value);
                setState(() {});
              },
      ),
      SettingsTile.switchTile(
        title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(translate("auto_disconnect_option_tip")),
                    Offstage(
                        offstage: !_allowAutoDisconnect,
                        child: Text(
                          '${_autoDisconnectTimeout.isEmpty ? '10' : _autoDisconnectTimeout} min',
                          style: Theme.of(context).textTheme.bodySmall,
                        )),
                  ])),
              Offstage(
                  offstage: !_allowAutoDisconnect,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.edit,
                        size: 20,
                      ),
                      onPressed: isOptionFixed(kOptionAutoDisconnectTimeout)
                          ? null
                          : () async {
                              final timeout = await changeAutoDisconnectTimeout(
                                  _autoDisconnectTimeout);
                              setState(() {
                                _autoDisconnectTimeout = timeout;
                              });
                            }))
            ]),
        initialValue: _allowAutoDisconnect,
        onToggle: isOptionFixed(kOptionAllowAutoDisconnect)
            ? null
            : (_) async {
                _allowAutoDisconnect = !_allowAutoDisconnect;
                String value = bool2option(
                    kOptionAllowAutoDisconnect, _allowAutoDisconnect);
                await bind.mainSetOption(
                    key: kOptionAllowAutoDisconnect, value: value);
                setState(() {});
              },
      )
    ];
    if (_hasIgnoreBattery) {
      enhancementsTiles.insert(
          0,
          SettingsTile.switchTile(
              initialValue: _ignoreBatteryOpt,
              title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(translate('Keep ShamarrConnect background service')),
                    Text('* ${translate('Ignore Battery Optimizations')}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
              onToggle: (v) async {
                if (v) {
                  await AndroidPermissionManager.request(
                      kRequestIgnoreBatteryOptimizations);
                } else {
                  final res = await gFFI.dialogManager.show<bool>(
                      (setState, close, context) => CustomAlertDialog(
                            title: Text(translate("Open System Setting")),
                            content: Text(translate(
                                "android_open_battery_optimizations_tip")),
                            actions: [
                              dialogButton("Cancel",
                                  onPressed: () => close(), isOutline: true),
                              dialogButton(
                                "Open System Setting",
                                onPressed: () => close(true),
                              ),
                            ],
                          ));
                  if (res == true) {
                    AndroidPermissionManager.startAction(
                        kActionApplicationDetailsSettings);
                  }
                }
              }));
    }
    enhancementsTiles.add(SettingsTile.switchTile(
        initialValue: _dataSaver,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(translate('Data saver')),
          Text(
              '* ${translate('Use less data in remote sessions (lower picture quality)')}',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        onToggle: isOptionFixed(kOptionImageQuality)
            ? null
            : (v) async {
                if (v) {
                  // Remember the user's choice so "off" restores it.
                  await bind.mainSetLocalOption(
                      key: 'data_saver_prev_quality',
                      value: bind.mainGetUserDefaultOption(
                          key: kOptionImageQuality));
                  await bind.mainSetUserDefaultOption(
                      key: kOptionImageQuality, value: kRemoteImageQualityLow);
                } else {
                  final prev =
                      bind.mainGetLocalOption(key: 'data_saver_prev_quality');
                  await bind.mainSetUserDefaultOption(
                      key: kOptionImageQuality,
                      value: prev.isEmpty ? kRemoteImageQualityBalanced : prev);
                }
                await bind.mainSetLocalOption(
                    key: 'data_saver', value: v ? 'Y' : 'N');
                setState(() => _dataSaver = v);
              }));
    enhancementsTiles.add(SettingsTile.switchTile(
        initialValue: _enableStartOnBoot,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(translate('Start on boot')),
          Text(
              '* ${translate('Start the screen sharing service on boot, requires special permissions')}',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        onToggle: (toValue) async {
          if (toValue) {
            // 1. request kIgnoreBatteryOptimizations
            if (!await AndroidPermissionManager.check(
                kRequestIgnoreBatteryOptimizations)) {
              if (!await AndroidPermissionManager.request(
                  kRequestIgnoreBatteryOptimizations)) {
                return;
              }
            }

            // 2. request kSystemAlertWindow
            if (!await AndroidPermissionManager.check(kSystemAlertWindow)) {
              if (!await AndroidPermissionManager.request(kSystemAlertWindow)) {
                return;
              }
            }

            // (Optional) 3. request input permission
          }
          setState(() => _enableStartOnBoot = toValue);

          gFFI.invokeMethod(AndroidChannel.kSetStartOnBootOpt, toValue);
        }));

    if (!bind.isCustomClient()) {
      enhancementsTiles.add(
        SettingsTile.switchTile(
          initialValue: _checkUpdateOnStartup,
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(translate('Check for software update on startup')),
          ]),
          onToggle: (bool toValue) async {
            await mainSetLocalBoolOption(kOptionEnableCheckUpdate, toValue);
            setState(() => _checkUpdateOnStartup = toValue);
          },
        ),
      );
    }

    enhancementsTiles.add(
      SettingsTile.switchTile(
        initialValue: _showTerminalExtraKeys,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(translate('Show terminal extra keys')),
        ]),
        onToggle: (bool v) async {
          await mainSetLocalBoolOption(kOptionEnableShowTerminalExtraKeys, v);
          final newValue =
              mainGetLocalBoolOptionSync(kOptionEnableShowTerminalExtraKeys);
          setState(() {
            _showTerminalExtraKeys = newValue;
          });
        },
      ),
    );

    onFloatingWindowChanged(bool toValue) async {
      if (toValue) {
        if (!await AndroidPermissionManager.check(kSystemAlertWindow)) {
          if (!await AndroidPermissionManager.request(kSystemAlertWindow)) {
            return;
          }
        }
      }
      final disable = !toValue;
      bind.mainSetLocalOption(
          key: kOptionDisableFloatingWindow,
          value: disable ? 'Y' : defaultOptionNo);
      setState(() => _floatingWindowDisabled = disable);
      gFFI.serverModel.androidUpdatekeepScreenOn();
    }

    enhancementsTiles.add(SettingsTile.switchTile(
        initialValue: !_floatingWindowDisabled,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(translate('Floating window')),
          Text('* ${translate('floating_window_tip')}',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        onToggle: bind.mainIsOptionFixed(key: kOptionDisableFloatingWindow)
            ? null
            : onFloatingWindowChanged));

    enhancementsTiles.add(_getPopupDialogRadioEntry(
      title: 'Keep screen on',
      list: [
        _RadioEntry('Never', _keepScreenOnToOption(KeepScreenOn.never)),
        _RadioEntry('During controlled',
            _keepScreenOnToOption(KeepScreenOn.duringControlled)),
        _RadioEntry('During service is on',
            _keepScreenOnToOption(KeepScreenOn.serviceOn)),
      ],
      getter: () => _keepScreenOnToOption(_floatingWindowDisabled
          ? KeepScreenOn.never
          : optionToKeepScreenOn(
              bind.mainGetLocalOption(key: kOptionKeepScreenOn))),
      asyncSetter: isOptionFixed(kOptionKeepScreenOn) || _floatingWindowDisabled
          ? null
          : (value) async {
              await bind.mainSetLocalOption(
                  key: kOptionKeepScreenOn, value: value);
              setState(() => _keepScreenOn = optionToKeepScreenOn(value));
              gFFI.serverModel.androidUpdatekeepScreenOn();
            },
    ));

    final disabledSettings = bind.isDisableSettings();
    final hideSecuritySettings =
        bind.mainGetBuildinOption(key: kOptionHideSecuritySetting) == 'Y';
    final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
    final settings = SettingsList(
      sections: [
        if (!bind.isDisableAccount())
          SettingsSection(
            title: Text(translate('Account')),
            tiles: [
              SettingsTile(
                title: Obx(() => Text(gFFI.userModel.userName.value.isEmpty
                    ? translate('Login')
                    : translate('Logout'))),
                description: Obx(() {
                  final label = gFFI.userModel.accountLabelWithHandle;
                  if (label.isEmpty) return const SizedBox.shrink();
                  return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
                }),
                leading: Obx(() {
                  final avatar = bind.mainResolveAvatarUrl(
                      avatar: gFFI.userModel.avatar.value);
                  return buildAvatarWidget(
                        avatar: avatar,
                        size: 28,
                        borderRadius: null,
                        fallback: Icon(Icons.person),
                      ) ??
                      Icon(Icons.person);
                }),
                onPressed: (context) {
                  if (gFFI.userModel.userName.value.isEmpty) {
                    loginDialog();
                  } else {
                    logOutConfirmDialog();
                  }
                },
              ),
              if (loggedIn)
                SettingsTile(
                  title: Text('Change password'),
                  leading: Icon(Icons.password_outlined),
                  onPressed: (context) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _ChangePasswordPage(),
                      ),
                    );
                  },
                ),
              if (loggedIn)
                SettingsTile(
                  title: Text('Signed-in devices'),
                  description: Text('See and sign out other phones and computers'),
                  leading: Icon(Icons.devices_outlined),
                  onPressed: (context) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _SignedInDevicesPage(),
                      ),
                    );
                  },
                ),
              // Account MFA (sign-in). Device 2FA remains under Security section.
              SettingsTile(
                title: Text('Account MFA (sign-in)'),
                description: Text(
                    'Required on all accounts. Authenticator at login; '
                    'reconnects re-prompt unless trusted device.'),
                leading: Icon(Icons.shield_outlined),
                onPressed: (context) async {
                  if (gFFI.userModel.userName.value.isEmpty) {
                    loginDialog();
                    return;
                  }
                  try {
                    final on = await gFFI.userModel.mfaStatus();
                    if (on) {
                      await showAccountMfaDisableDialog(context);
                    } else {
                      await showAccountMfaEnableDialog(context);
                    }
                  } catch (e) {
                    BotToast.showText(text: e.toString());
                  }
                },
              ),
            ],
          ),
        SettingsSection(title: Text(translate("Settings")), tiles: [
          if (!disabledSettings && !_hideNetwork && !_hideServer)
            SettingsTile(
                title: Text(translate('ID/Relay Server')),
                leading: Icon(Icons.cloud),
                onPressed: (context) {
                  showServerSettings(gFFI.dialogManager, (callback) async {
                    _isUsingPublicServer = await bind.mainIsUsingPublicServer();
                    setState(callback);
                  });
                }),
          if (!_hideNetwork && !_hideProxy)
            SettingsTile(
                title: Text(translate('Socks5/Http(s) Proxy')),
                leading: Icon(Icons.network_ping),
                onPressed: (context) {
                  changeSocks5Proxy();
                }),
          if (isAndroid && !bind.isOutgoingOnly())
            SettingsTile(
                title: Text(translate('Deploy')),
                leading: Icon(Icons.cloud_upload),
                onPressed: (context) {
                  showDeployDialog();
                }),
          if (!disabledSettings && !_hideNetwork && !_hideWebSocket)
            SettingsTile.switchTile(
              title: Text(translate('Use WebSocket')),
              initialValue: _allowWebSocket,
              onToggle: isOptionFixed(kOptionAllowWebSocket)
                  ? null
                  : (v) async {
                      await mainSetBoolOption(kOptionAllowWebSocket, v);
                      final newValue =
                          await mainGetBoolOption(kOptionAllowWebSocket);
                      setState(() {
                        _allowWebSocket = newValue;
                      });
                    },
            ),
          if (!_isUsingPublicServer)
            SettingsTile.switchTile(
              title: Text(translate('Allow insecure TLS fallback')),
              initialValue: _allowInsecureTlsFallback,
              onToggle: isOptionFixed(kOptionAllowInsecureTLSFallback)
                  ? null
                  : (v) async {
                      await mainSetBoolOption(
                          kOptionAllowInsecureTLSFallback, v);
                      final newValue = mainGetBoolOptionSync(
                          kOptionAllowInsecureTLSFallback);
                      setState(() {
                        _allowInsecureTlsFallback = newValue;
                      });
                    },
            ),
          if (isAndroid && !outgoingOnly && !_isUsingPublicServer)
            SettingsTile.switchTile(
              title: Text(translate('Disable UDP')),
              initialValue: _disableUdp,
              onToggle: isOptionFixed(kOptionDisableUdp)
                  ? null
                  : (v) async {
                      await bind.mainSetOption(
                          key: kOptionDisableUdp, value: v ? 'Y' : 'N');
                      final newValue =
                          bind.mainGetOptionSync(key: kOptionDisableUdp) == 'Y';
                      setState(() {
                        _disableUdp = newValue;
                      });
                    },
            ),
          if (!incomingOnly)
            SettingsTile.switchTile(
              title: Text(translate('Enable UDP hole punching')),
              initialValue: _enableUdpPunch,
              onToggle: (v) async {
                await mainSetLocalBoolOption(kOptionEnableUdpPunch, v);
                final newValue =
                    mainGetLocalBoolOptionSync(kOptionEnableUdpPunch);
                setState(() {
                  _enableUdpPunch = newValue;
                });
              },
            ),
          if (!incomingOnly)
            SettingsTile.switchTile(
              title: Text(translate('Enable IPv6 P2P connection')),
              initialValue: _enableIpv6Punch,
              onToggle: (v) async {
                await mainSetLocalBoolOption(kOptionEnableIpv6Punch, v);
                final newValue =
                    mainGetLocalBoolOptionSync(kOptionEnableIpv6Punch);
                setState(() {
                  _enableIpv6Punch = newValue;
                });
              },
            ),
          SettingsTile(
              title: Text(translate('Language')),
              leading: Icon(Icons.translate),
              onPressed: (context) {
                showLanguageSettings(gFFI.dialogManager);
              }),
          SettingsTile(
            title: Text(translate(
                Theme.of(context).brightness == Brightness.light
                    ? 'Light Theme'
                    : 'Dark Theme')),
            leading: Icon(Theme.of(context).brightness == Brightness.light
                ? Icons.dark_mode
                : Icons.light_mode),
            onPressed: (context) {
              showThemeSettings(gFFI.dialogManager);
            },
          ),
          if (!bind.isDisableAccount())
            SettingsTile.switchTile(
              title: Text(translate('note-at-conn-end-tip')),
              initialValue: _allowAskForNoteAtEndOfConnection,
              onToggle: (v) async {
                if (v && !gFFI.userModel.isLogin) {
                  final res = await loginDialog();
                  if (res != true) return;
                }
                await mainSetLocalBoolOption(
                    kOptionAllowAskForNoteAtEndOfConnection, v);
                final newValue = mainGetLocalBoolOptionSync(
                    kOptionAllowAskForNoteAtEndOfConnection);
                setState(() {
                  _allowAskForNoteAtEndOfConnection = newValue;
                });
              },
            ),
          if (!incomingOnly)
            SettingsTile.switchTile(
              title:
                  Text(translate('keep-awake-during-outgoing-sessions-label')),
              initialValue: _preventSleepWhileConnected,
              onToggle: (v) async {
                await mainSetLocalBoolOption(
                    kOptionKeepAwakeDuringOutgoingSessions, v);
                setState(() {
                  _preventSleepWhileConnected = v;
                });
              },
            ),
        ]),
        if (isAndroid)
          SettingsSection(title: Text(translate('Hardware Codec')), tiles: [
            SettingsTile.switchTile(
              title: Text(translate('Enable hardware codec')),
              initialValue: _enableHardwareCodec,
              onToggle: isOptionFixed(kOptionEnableHwcodec)
                  ? null
                  : (v) async {
                      await mainSetBoolOption(kOptionEnableHwcodec, v);
                      final newValue =
                          await mainGetBoolOption(kOptionEnableHwcodec);
                      setState(() {
                        _enableHardwareCodec = newValue;
                      });
                    },
            ),
          ]),
        if (isAndroid)
          SettingsSection(
            title: Text(translate("Recording")),
            tiles: [
              if (!outgoingOnly)
                SettingsTile.switchTile(
                  title:
                      Text(translate('Automatically record incoming sessions')),
                  initialValue: _autoRecordIncomingSession,
                  onToggle: isOptionFixed(kOptionAllowAutoRecordIncoming)
                      ? null
                      : (v) async {
                          await bind.mainSetOption(
                              key: kOptionAllowAutoRecordIncoming,
                              value: bool2option(
                                  kOptionAllowAutoRecordIncoming, v));
                          final newValue = option2bool(
                              kOptionAllowAutoRecordIncoming,
                              await bind.mainGetOption(
                                  key: kOptionAllowAutoRecordIncoming));
                          setState(() {
                            _autoRecordIncomingSession = newValue;
                          });
                        },
                ),
              if (!incomingOnly)
                SettingsTile.switchTile(
                  title:
                      Text(translate('Automatically record outgoing sessions')),
                  initialValue: _autoRecordOutgoingSession,
                  onToggle: isOptionFixed(kOptionAllowAutoRecordOutgoing)
                      ? null
                      : (v) async {
                          await bind.mainSetLocalOption(
                              key: kOptionAllowAutoRecordOutgoing,
                              value: bool2option(
                                  kOptionAllowAutoRecordOutgoing, v));
                          final newValue = option2bool(
                              kOptionAllowAutoRecordOutgoing,
                              bind.mainGetLocalOption(
                                  key: kOptionAllowAutoRecordOutgoing));
                          setState(() {
                            _autoRecordOutgoingSession = newValue;
                          });
                        },
                ),
              SettingsTile(
                title: Text(translate("Directory")),
                description: Text(bind.mainVideoSaveDirectory(root: false)),
              ),
            ],
          ),
        if (isAndroid &&
            !disabledSettings &&
            !outgoingOnly &&
            !hideSecuritySettings)
          SettingsSection(title: Text('2FA'), tiles: tfaTiles),
        if (isAndroid &&
            !disabledSettings &&
            !outgoingOnly &&
            !hideSecuritySettings)
          SettingsSection(
            title: Text(translate("Share screen")),
            tiles: shareScreenTiles,
          ),
        if (!bind.isIncomingOnly()) defaultDisplaySection(),
        if (isAndroid &&
            !disabledSettings &&
            !outgoingOnly &&
            !hideSecuritySettings)
          SettingsSection(
            title: Text(translate("Enhancements")),
            tiles: enhancementsTiles,
          ),
        SettingsSection(
          title: Text(translate("About")),
          tiles: [
            SettingsTile(
                onPressed: (context) async {
                  await launchUrl(Uri.parse(url));
                },
                title: Text(translate("Version: ") + version),
                value: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('shamarrconnect.com',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                      )),
                ),
                leading: Icon(Icons.info)),
            SettingsTile(
                title: Text(translate("Build Date")),
                value: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(_buildDate),
                ),
                leading: Icon(Icons.query_builder)),
            if (isAndroid)
              SettingsTile(
                  onPressed: (context) => onCopyFingerprint(_fingerprint),
                  title: Text(translate("Fingerprint")),
                  value: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(_fingerprint),
                  ),
                  leading: Icon(Icons.fingerprint)),
            SettingsTile(
              title: Text(translate("Privacy Statement")),
              onPressed: (context) =>
                  launchUrlString('https://shamarrconnect.com/privacy'),
              leading: Icon(Icons.privacy_tip),
            )
          ],
        ),
        // Fork credit — footer (not header); AGPL attribution.
        if (bind.isCustomClient())
          CustomSettingsSection(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: Center(child: loadPowered(context)),
            ),
          ),
      ],
    );
    return settings;
  }

  Future<bool> canStartOnBoot() async {
    // start on boot depends on ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS and SYSTEM_ALERT_WINDOW
    if (_hasIgnoreBattery && !_ignoreBatteryOpt) {
      return false;
    }
    if (!await AndroidPermissionManager.check(kSystemAlertWindow)) {
      return false;
    }
    return true;
  }

  defaultDisplaySection() {
    return SettingsSection(
      title: Text(translate("Display Settings")),
      tiles: [
        SettingsTile(
            title: Text(translate('Display Settings')),
            leading: Icon(Icons.desktop_windows_outlined),
            trailing: Icon(Icons.arrow_forward_ios),
            onPressed: (context) {
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return _DisplayPage();
              }));
            })
      ],
    );
  }
}

void showLanguageSettings(OverlayDialogManager dialogManager) async {
  try {
    final langs = json.decode(await bind.mainGetLangs()) as List<dynamic>;
    var lang = bind.mainGetLocalOption(key: kCommConfKeyLang);
    dialogManager.show((setState, close, context) {
      setLang(v) async {
        if (lang != v) {
          setState(() {
            lang = v;
          });
          await bind.mainSetLocalOption(key: kCommConfKeyLang, value: v);
          HomePage.homeKey.currentState?.refreshPages();
          Future.delayed(Duration(milliseconds: 200), close);
        }
      }

      final isOptFixed = isOptionFixed(kCommConfKeyLang);
      return CustomAlertDialog(
        content: Column(
          children: [
                getRadio(Text(translate('Default')), defaultOptionLang, lang,
                    isOptFixed ? null : setLang),
                Divider(color: MyTheme.border),
              ] +
              langs.map((e) {
                final key = e[0] as String;
                final name = e[1] as String;
                return getRadio(Text(translate(name)), key, lang,
                    isOptFixed ? null : setLang);
              }).toList(),
        ),
      );
    }, backDismiss: true, clickMaskDismiss: true);
  } catch (e) {
    //
  }
}

void showThemeSettings(OverlayDialogManager dialogManager) async {
  var themeMode = MyTheme.getThemeModePreference();

  dialogManager.show((setState, close, context) {
    setTheme(v) {
      if (themeMode != v) {
        setState(() {
          themeMode = v;
        });
        MyTheme.changeDarkMode(themeMode);
        Future.delayed(Duration(milliseconds: 200), close);
      }
    }

    final isOptFixed = isOptionFixed(kCommConfKeyTheme);
    return CustomAlertDialog(
      content: Column(children: [
        getRadio(Text(translate('Light')), ThemeMode.light, themeMode,
            isOptFixed ? null : setTheme),
        getRadio(Text(translate('Dark')), ThemeMode.dark, themeMode,
            isOptFixed ? null : setTheme),
        getRadio(Text(translate('Follow System')), ThemeMode.system, themeMode,
            isOptFixed ? null : setTheme)
      ]),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}

void showAbout(OverlayDialogManager dialogManager) {
  dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Text(translate('About ShamarrConnect')),
      content: Wrap(direction: Axis.vertical, spacing: 12, children: [
        Text('Version: $version'),
        InkWell(
            onTap: () async {
              const url = 'https://shamarrconnect.com/';
              await launchUrl(Uri.parse(url));
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('shamarrconnect.com',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                  )),
            )),
      ]),
      actions: [],
    );
  }, clickMaskDismiss: true, backDismiss: true);
}

class ScanButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.qr_code_scanner),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => ScanPage(),
          ),
        );
      },
    );
  }
}

/// Account → Change password (POST /api/user/password).
class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage();

  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _obscure = true;
  var _revokeOthers = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cur = _current.text;
    final next = _next.text;
    final conf = _confirm.text;
    if (cur.isEmpty) {
      setState(() => _error = 'Current password is required');
      return;
    }
    if (next.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters');
      return;
    }
    if (next != conf) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await gFFI.userModel.changePassword(
        currentPassword: cur,
        newPassword: next,
        revokeOtherDevices: _revokeOthers,
      );
      if (!mounted) return;
      BotToast.showText(text: 'Password updated');
      Navigator.pop(context);
    } on RequestException catch (e) {
      setState(() => _error = e.cause.isNotEmpty ? e.cause : 'Request failed');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        title: const Text('Change password'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Update the password for your ShamarrConnect account. '
            'Devices stay signed in unless you choose to sign them out.',
            style: TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _current,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Current password',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _next,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: 'Confirm new password'),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Sign out other devices'),
            subtitle: const Text(
              'Revoke sessions on other phones and computers',
              style: TextStyle(fontSize: 12),
            ),
            value: _revokeOthers,
            onChanged: _busy
                ? null
                : (v) => setState(() => _revokeOthers = v == true),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Update password'),
          ),
        ],
      ),
    );
  }
}

/// Account → Signed-in devices (GET/DELETE /api/user/devices).
class _SignedInDevicesPage extends StatefulWidget {
  const _SignedInDevicesPage();

  @override
  State<_SignedInDevicesPage> createState() => _SignedInDevicesPageState();
}

class _SignedInDevicesPageState extends State<_SignedInDevicesPage> {
  List<Map<String, dynamic>> _devices = [];
  var _loading = true;
  String? _error;
  String? _myId;
  String? _myUuid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _myId = await bind.mainGetMyId();
      _myUuid = await UserModel.accountDeviceUuid();
      final list = await gFFI.userModel.listSignedInDevices();
      if (!mounted) return;
      setState(() {
        _devices = list;
        _loading = false;
      });
    } on RequestException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.cause.isNotEmpty ? e.cause : 'Failed to load devices';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _revokeOne(Map<String, dynamic> d) async {
    final id = (d['id'] ?? '').toString();
    if (id.isEmpty) return;
    final name = (d['device_name'] ?? d['device_id'] ?? 'device').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out device?'),
        content: Text('Sign out "$name"? It will need to log in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await gFFI.userModel.revokeDevice(id);
      BotToast.showText(text: 'Device signed out');
      await _load();
    } on RequestException catch (e) {
      BotToast.showText(text: e.cause);
    } catch (e) {
      BotToast.showText(text: e.toString());
    }
  }

  Future<void> _revokeOthers() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out other devices?'),
        content: const Text(
          'Keep this phone signed in and revoke all other sessions.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out others')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n = await gFFI.userModel.revokeOtherDevices();
      BotToast.showText(text: n == 0 ? 'No other devices' : 'Signed out $n device(s)');
      await _load();
    } on RequestException catch (e) {
      BotToast.showText(text: e.cause);
    } catch (e) {
      BotToast.showText(text: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        title: const Text('Signed-in devices'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Text(
                          'Phones and computers signed into your account. '
                          'Sign out a device you do not recognize.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                      if (_devices.isEmpty)
                        const ListTile(
                          title: Text('No signed-in devices found'),
                        ),
                      ..._devices.map((d) {
                        final name = (d['device_name'] ?? '').toString().trim();
                        final deviceId = (d['device_id'] ?? '').toString();
                        final deviceUuid = (d['device_uuid'] ?? '').toString();
                        final os = (d['device_os'] ?? '').toString();
                        final last = (d['last_seen'] ?? '').toString();
                        final isThis = (_myUuid != null &&
                                _myUuid!.isNotEmpty &&
                                deviceUuid == _myUuid) ||
                            (_myId != null &&
                                _myId!.isNotEmpty &&
                                deviceId == _myId);
                        final title = name.isNotEmpty
                            ? name
                            : (deviceId.isNotEmpty ? deviceId : 'Unknown device');
                        return ListTile(
                          leading: Icon(
                            os.toLowerCase().contains('android') ||
                                    os.toLowerCase().contains('ios')
                                ? Icons.phone_android
                                : Icons.computer,
                          ),
                          title: Text(title),
                          subtitle: Text([
                            if (os.isNotEmpty) os,
                            if (deviceId.isNotEmpty) 'ID $deviceId',
                            if (last.isNotEmpty) 'Last seen $last',
                            if (isThis) 'This device',
                          ].join(' · ')),
                          trailing: isThis
                              ? const Chip(label: Text('This device', style: TextStyle(fontSize: 11)))
                              : IconButton(
                                  icon: const Icon(Icons.logout),
                                  tooltip: 'Sign out',
                                  onPressed: () => _revokeOne(d),
                                ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton.icon(
                          onPressed: _devices.length <= 1 ? null : _revokeOthers,
                          icon: const Icon(Icons.devices_other),
                          label: const Text('Sign out all other devices'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _DisplayPage extends StatefulWidget {
  const _DisplayPage();

  @override
  State<_DisplayPage> createState() => __DisplayPageState();
}

class __DisplayPageState extends State<_DisplayPage> {
  @override
  Widget build(BuildContext context) {
    final Map codecsJson = jsonDecode(bind.mainSupportedHwdecodings());
    final h264 = codecsJson['h264'] ?? false;
    final h265 = codecsJson['h265'] ?? false;
    var codecList = [
      _RadioEntry('Auto', 'auto'),
      _RadioEntry('VP8', 'vp8'),
      _RadioEntry('VP9', 'vp9'),
      _RadioEntry('AV1', 'av1'),
      if (h264) _RadioEntry('H264', 'h264'),
      if (h265) _RadioEntry('H265', 'h265')
    ];
    RxBool showCustomImageQuality = false.obs;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios)),
        title: Text(translate('Display Settings')),
        centerTitle: true,
      ),
      body: SettingsList(sections: [
        SettingsSection(
          tiles: [
            _getPopupDialogRadioEntry(
              title: 'Default View Style',
              list: [
                _RadioEntry('Scale original', kRemoteViewStyleOriginal),
                _RadioEntry('Scale adaptive', kRemoteViewStyleAdaptive)
              ],
              getter: () =>
                  bind.mainGetUserDefaultOption(key: kOptionViewStyle),
              asyncSetter: isOptionFixed(kOptionViewStyle)
                  ? null
                  : (value) async {
                      await bind.mainSetUserDefaultOption(
                          key: kOptionViewStyle, value: value);
                    },
            ),
            _getPopupDialogRadioEntry(
              title: 'Default Image Quality',
              list: [
                _RadioEntry('Good image quality', kRemoteImageQualityBest),
                _RadioEntry('Balanced', kRemoteImageQualityBalanced),
                _RadioEntry('Optimize reaction time', kRemoteImageQualityLow),
                _RadioEntry('Custom', kRemoteImageQualityCustom),
              ],
              getter: () {
                final v =
                    bind.mainGetUserDefaultOption(key: kOptionImageQuality);
                showCustomImageQuality.value = v == kRemoteImageQualityCustom;
                return v;
              },
              asyncSetter: isOptionFixed(kOptionImageQuality)
                  ? null
                  : (value) async {
                      await bind.mainSetUserDefaultOption(
                          key: kOptionImageQuality, value: value);
                      showCustomImageQuality.value =
                          value == kRemoteImageQualityCustom;
                    },
              tail: customImageQualitySetting(),
              showTail: showCustomImageQuality,
              notCloseValue: kRemoteImageQualityCustom,
            ),
            _getPopupDialogRadioEntry(
              title: 'Default Codec',
              list: codecList,
              getter: () =>
                  bind.mainGetUserDefaultOption(key: kOptionCodecPreference),
              asyncSetter: isOptionFixed(kOptionCodecPreference)
                  ? null
                  : (value) async {
                      await bind.mainSetUserDefaultOption(
                          key: kOptionCodecPreference, value: value);
                    },
            ),
          ],
        ),
        SettingsSection(
          title: Text(translate('Other Default Options')),
          tiles:
              otherDefaultSettings().map((e) => otherRow(e.$1, e.$2)).toList(),
        ),
      ]),
    );
  }

  SettingsTile otherRow(String label, String key) {
    final value = bind.mainGetUserDefaultOption(key: key) == 'Y';
    final isOptFixed = isOptionFixed(key);
    return SettingsTile.switchTile(
      initialValue: value,
      title: Text(translate(label)),
      onToggle: isOptFixed
          ? null
          : (b) async {
              await bind.mainSetUserDefaultOption(
                  key: key, value: b ? 'Y' : defaultOptionNo);
              setState(() {});
            },
    );
  }
}

class _ManageTrustedDevices extends StatefulWidget {
  const _ManageTrustedDevices();

  @override
  State<_ManageTrustedDevices> createState() => __ManageTrustedDevicesState();
}

class __ManageTrustedDevicesState extends State<_ManageTrustedDevices> {
  RxList<TrustedDevice> trustedDevices = RxList.empty(growable: true);
  RxList<Uint8List> selectedDevices = RxList.empty();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(translate('Manage trusted devices')),
        centerTitle: true,
        actions: [
          Obx(() => IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: selectedDevices.isEmpty
                  ? null
                  : () {
                      confrimDeleteTrustedDevicesDialog(
                          trustedDevices, selectedDevices);
                    }))
        ],
      ),
      body: FutureBuilder(
          future: TrustedDevice.get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final devices = snapshot.data as List<TrustedDevice>;
            trustedDevices = devices.obs;
            return trustedDevicesTable(trustedDevices, selectedDevices);
          }),
    );
  }
}

class _RadioEntry {
  final String label;
  final String value;
  _RadioEntry(this.label, this.value);
}

typedef _RadioEntryGetter = String Function();
typedef _RadioEntrySetter = Future<void> Function(String);

SettingsTile _getPopupDialogRadioEntry({
  required String title,
  required List<_RadioEntry> list,
  required _RadioEntryGetter getter,
  required _RadioEntrySetter? asyncSetter,
  Widget? tail,
  RxBool? showTail,
  String? notCloseValue,
}) {
  RxString groupValue = ''.obs;
  RxString valueText = ''.obs;

  init() {
    groupValue.value = getter();
    final e = list.firstWhereOrNull((e) => e.value == groupValue.value);
    if (e != null) {
      valueText.value = e.label;
    }
  }

  init();

  void showDialog() async {
    gFFI.dialogManager.show((setState, close, context) {
      final onChanged = asyncSetter == null
          ? null
          : (String? value) async {
              if (value == null) return;
              await asyncSetter(value);
              init();
              if (value != notCloseValue) {
                close();
              }
            };

      return CustomAlertDialog(
          content: Obx(
        () => Column(children: [
          ...list
              .map((e) => getRadio(Text(translate(e.label)), e.value,
                  groupValue.value, onChanged))
              .toList(),
          Offstage(
            offstage:
                !(tail != null && showTail != null && showTail.value == true),
            child: tail,
          ),
        ]),
      ));
    }, backDismiss: true, clickMaskDismiss: true);
  }

  return SettingsTile(
    title: Text(translate(title)),
    onPressed: asyncSetter == null ? null : (context) => showDialog(),
    value: Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Obx(() => Text(translate(valueText.value))),
    ),
  );
}
