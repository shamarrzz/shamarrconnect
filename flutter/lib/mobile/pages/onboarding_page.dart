import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

import '../../common.dart';
import '../../consts.dart';
import '../../models/platform_model.dart';

/// One-permission-per-screen setup shown after sign-in or when entering
/// Get Help mode. Every step explains *why* in plain language; grants are
/// auto-detected and advance the flow. Skippable (with a warning) — the
/// ServerPage health row reflects whatever was skipped.
class OnboardingPage extends StatefulWidget {
  /// Where to go when the flow finishes (or is skipped).
  final WidgetBuilder destination;

  const OnboardingPage({Key? key, required this.destination})
      : super(key: key);

  /// True once the user has seen the flow (regardless of grants).
  static bool get done =>
      bind.mainGetLocalOption(key: 'onboarding_done') == 'Y';

  static Future<void> markDone() =>
      bind.mainSetLocalOption(key: 'onboarding_done', value: 'Y');

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with WidgetsBindingObserver {
  static const _blue = Color(0xFF0071FF);
  static const _navy = Color(0xFF0A1737);

  int _step = 0;
  bool _busy = false;
  bool _finishing = false;
  String _oemTip = '';

  // Runtime-checked statuses (service states come from ServerModel).
  bool _batteryOk = false;
  bool _notifyOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gFFI.serverModel.addListener(_onServiceState);
    _refreshStatuses();
    _loadOemTip();
  }

  /// Per-manufacturer guidance for keeping background services alive —
  /// the brands below dominate our launch market and all kill aggressively.
  Future<void> _loadOemTip() async {
    String tip;
    try {
      final maker =
          (await DeviceInfoPlugin().androidInfo).manufacturer.toLowerCase();
      if (maker.contains('samsung')) {
        tip = 'On Samsung: Settings → Apps → ShamarrConnect → Battery → '
            '"Unrestricted". Also add it under "Never sleeping apps".';
      } else if (maker.contains('xiaomi') ||
          maker.contains('redmi') ||
          maker.contains('poco')) {
        tip = 'On Xiaomi: Settings → Apps → ShamarrConnect → Battery saver → '
            '"No restrictions", and turn on "Autostart".';
      } else if (maker.contains('tecno') ||
          maker.contains('itel') ||
          maker.contains('infinix')) {
        tip = 'On this phone: open Phone Manager (or Battery Lab) and allow '
            'ShamarrConnect to run in the background / auto-launch.';
      } else if (maker.contains('huawei') || maker.contains('honor')) {
        tip = 'On Huawei: Settings → Battery → App launch → find '
            'ShamarrConnect and set it to "Manage manually" (all three on).';
      } else {
        tip = 'If this phone kills background apps, allow ShamarrConnect '
            '"unrestricted" battery use in Settings → Apps.';
      }
    } catch (_) {
      tip = '';
    }
    if (mounted) setState(() => _oemTip = tip);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gFFI.serverModel.removeListener(_onServiceState);
    super.dispose();
  }

  void _onServiceState() {
    if (!mounted) return;
    setState(() {});
    _maybeAdvance();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from a system settings screen: pick up whatever changed.
    if (state == AppLifecycleState.resumed) _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    final battery = await AndroidPermissionManager.check(
        kRequestIgnoreBatteryOptimizations);
    final notify = await AndroidPermissionManager.check(
        kAndroid13Notification);
    if (!mounted) return;
    setState(() {
      _batteryOk = battery;
      _notifyOk = notify;
    });
    _maybeAdvance();
  }

  bool _statusOf(int i) {
    switch (i) {
      case 0:
        return gFFI.serverModel.mediaOk;
      case 1:
        return gFFI.serverModel.inputOk;
      case 2:
        return _batteryOk;
      default:
        return _notifyOk;
    }
  }

  void _maybeAdvance() {
    if (!mounted || _finishing) return;
    var advanced = false;
    while (_step < 4 && _statusOf(_step)) {
      _step++;
      advanced = true;
    }
    if (advanced) setState(() {});
    if (_step >= 4) _finish();
  }

  Future<void> _grant() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      switch (_step) {
        case 0:
          // Triggers the system screen-capture prompt; mediaOk flips on grant.
          await gFFI.serverModel.startService();
          break;
        case 1:
          AndroidPermissionManager.startAction(
              'android.settings.ACCESSIBILITY_SETTINGS');
          break;
        case 2:
          // Fire-and-forget: XXPermissions only calls back on grant, so
          // awaiting would hang on deny. The lifecycle-resume re-check and
          // the delayed refresh below pick up the result either way.
          AndroidPermissionManager.request(kRequestIgnoreBatteryOptimizations);
          break;
        default:
          AndroidPermissionManager.request(kAndroid13Notification);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await Future.delayed(const Duration(milliseconds: 600));
    _refreshStatuses();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await OnboardingPage.markDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => widget.destination(context),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  void _skip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip setup?'),
        content: const Text(
          'Without these permissions a supporter may not be able to see or '
          'control this phone. You can grant them later from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep setting up'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _finish();
            },
            child: const Text('Skip', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  static const _titles = [
    'Share your screen',
    'Let a supporter help',
    'Stay reachable',
    'Session alerts',
  ];

  static const _whys = [
    'So a supporter can see this screen during a session. '
        'Android asks every time — that is normal.',
    'So a supporter can tap and type for you when you ask for help. '
        'Find ShamarrConnect in the list and turn it on.',
    'So this phone stays reachable between sessions. '
        'Allow ShamarrConnect to run in the background.',
    'So you know when a session starts or a message arrives.',
  ];

  static const _icons = [
    Icons.screen_share_outlined,
    Icons.touch_app_outlined,
    Icons.battery_saver_outlined,
    Icons.notifications_outlined,
  ];

  static const _buttonLabels = [
    'Allow screen sharing',
    'Open settings',
    'Allow background running',
    'Allow notifications',
  ];

  @override
  Widget build(BuildContext context) {
    final doneCount = List.generate(4, _statusOf).where((ok) => ok).length;
    final step = _step.clamp(0, 3);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: _navy,
        title: const Text('A quick setup'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusOf(i)
                          ? const Color(0xFF2BB673)
                          : i == step
                              ? _blue
                              : Colors.black12,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Icon(_icons[step], size: 72, color: _blue),
              const SizedBox(height: 24),
              Text(
                _titles[step],
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _whys[step],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, color: Colors.black54, height: 1.45),
              ),
              if (step == 2 && _oemTip.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _oemTip,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black87, height: 1.4),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _busy ? null : _grant,
                  child: Text(
                    _busy ? 'Waiting…' : _buttonLabels[step],
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _skip,
                child: Text(
                  doneCount == 0 ? 'Skip for now' : 'Finish later',
                  style: const TextStyle(color: Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
