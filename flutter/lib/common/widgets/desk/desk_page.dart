import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../common.dart';
import '../../../desktop/pages/connection_page.dart' as dconn;
import '../../../desktop/pages/desktop_tab_page.dart';
import '../../../models/fleet_model.dart';
import '../../../models/platform_model.dart';
import '../../../models/server_model.dart';
import '../../widgets/login.dart';
import '../../widgets/s_mark.dart';
import '../place_name_dialog.dart';

const _navy = Color(0xFF0A1737);

/// Desk of named computers. Remote ID lives in Connect by ID.
class DeskPage extends StatefulWidget {
  const DeskPage({
    Key? key,
    this.helpMode = false,
    this.showSettings = true,
    this.onConnectById,
    this.onContinueSetup,
  }) : super(key: key);

  /// Incoming-only / Get Help: this computer only, Share is the job.
  final bool helpMode;

  /// Desktop chrome Settings gear. Mobile hides this (Settings is a tab).
  final bool showSettings;

  /// Mobile: push the Connection page. Desktop: in-window sheet.
  final VoidCallback? onConnectById;

  /// Android: open the permission wizard. Desktop unused.
  final VoidCallback? onContinueSetup;

  @override
  State<DeskPage> createState() => _DeskPageState();
}

class _DeskPageState extends State<DeskPage> {
  String _myId = '';
  String _status = '';

  @override
  void initState() {
    super.initState();
    bind.mainGetMyId().then((id) {
      if (mounted) setState(() => _myId = id);
    });
    if (gFFI.userModel.isLogin) {
      gFFI.fleetModel.pull();
    }
    if (widget.helpMode || !bind.isOutgoingOnly()) {
      gFFI.serverModel.startService();
    }
  }

  bool get _outgoingOnly => bind.isOutgoingOnly();

  RxBool get _svcStopped {
    try {
      return Get.find<RxBool>(tag: 'stop-service');
    } catch (_) {
      return false.obs;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(
        builder: (context, _, __) {
          return Obx(() {
            final loggedIn = gFFI.userModel.isLogin;
            final devices = gFFI.fleetModel.devices.toList();
            final stopped = _svcStopped.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _chrome(context, loggedIn),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _grid(context, loggedIn, devices, stopped),
                  ),
                ),
                _foot(context),
              ],
            );
          });
        },
      ),
    );
  }

  Widget _chrome(BuildContext context, bool loggedIn) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
      child: Row(
        children: [
          const SMark(size: 22),
          const SizedBox(width: 8),
          Text(
            'Your computers',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (!widget.helpMode && loggedIn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                gFFI.userModel.displayNameOrUserName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            )
          else if (!widget.helpMode)
            TextButton(
              onPressed: () => loginDialog(),
              child: Text(translate('Login')),
            ),
          if (widget.showSettings)
            IconButton(
              tooltip: translate('Settings'),
              onPressed: DesktopTabPage.onAddSetting,
              icon: Icon(Icons.settings, size: 20, color: muted),
            ),
          if (widget.showSettings && loggedIn)
            PopupMenuButton<String>(
              tooltip: translate('Logout'),
              icon: Icon(Icons.expand_more, size: 20, color: muted),
              onSelected: (v) async {
                if (v == 'logout') gFFI.userModel.logOut();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'logout',
                  child: Text(translate('Logout')),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    bool loggedIn,
    List<FleetDevice> devices,
    bool stopped,
  ) {
    final cards = <Widget>[
      _thisCard(context, stopped),
    ];
    if (loggedIn && !widget.helpMode) {
      for (final d in devices) {
        if (_myId.isNotEmpty && d.deviceId == _myId) continue;
        cards.add(_placeCard(context, d));
      }
      cards.add(_addSlot(context));
    }
    return GridView.count(
      crossAxisCount: (!isDesktop || MediaQuery.of(context).size.width < 720)
          ? 1
          : 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: cards,
    );
  }

  Widget _thisCard(BuildContext context, bool stopped) {
    final model = gFFI.serverModel;
    final needSetup = isAndroid && (!model.mediaOk || !model.inputOk);
    final String sentence;
    if (stopped) {
      sentence =
          'This computer is not reachable until ShamarrConnect is open.';
    } else if (needSetup) {
      sentence = 'Almost ready. This computer still needs a permission.';
    } else {
      sentence = 'This is the computer you\'re on.';
    }
    Widget action;
    if (_outgoingOnly) {
      action = const SizedBox.shrink();
    } else if (needSetup) {
      action = _btn(
        context,
        'Continue setup',
        onTap: widget.onContinueSetup ?? () => _shareSheet(context),
      );
    } else {
      action = _btn(
        context,
        'Share',
        outlined: true,
        onTap: () => _shareSheet(context),
      );
    }
    return _cardShell(
      context: context,
      title: 'This computer',
      badge: 'Here',
      awake: !stopped && !needSetup,
      warn: stopped || needSetup,
      sentence: sentence,
      os: '',
      child: action,
    );
  }

  Widget _placeCard(BuildContext context, FleetDevice d) {
    final name = looksLikeFactoryName(d.deviceName)
        ? 'Computer'
        : (d.deviceName.trim().isEmpty ? 'Computer' : d.deviceName.trim());
    final stale = !d.online || d.ready == false;
    final sentence = _sentence(d);
    return _cardShell(
      context: context,
      title: name,
      awake: d.online && d.ready != false,
      warn: d.reason == 'battery' || d.reason == 'permission',
      sentence: sentence,
      os: d.deviceOs,
      child: _btn(
        context,
        'Open',
        outlined: stale,
        onTap: () => _open(context, d, stale),
      ),
    );
  }

  Widget _addSlot(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _addNewComputer,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              style: BorderStyle.solid,
            ),
          ),
          child: const Center(
            child: Text(
              '+ Add a new computer',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardShell({
    required BuildContext context,
    required String title,
    String badge = '',
    required bool awake,
    bool warn = false,
    required String sentence,
    required String os,
    required Widget child,
  }) {
    final line = Theme.of(context).dividerColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: warn
                      ? const Color(0xFFD97706)
                      : awake
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFC4CDD8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    if (badge.isNotEmpty)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _navy,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              badge.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(_osIcon(os), size: 18, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              sentence,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _btn(
    BuildContext context,
    String label, {
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          child: Text(label),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }

  Widget _foot(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          if (!widget.helpMode)
            TextButton(
              onPressed: () {
                if (widget.onConnectById != null) {
                  widget.onConnectById!();
                } else {
                  _connectById(context);
                }
              },
              child: const Text('Connect by ID'),
            ),
          const Spacer(),
          if (_status.isNotEmpty)
            Flexible(
              child: Text(
                _status,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: muted),
              ),
            )
          else if (bind.isCustomClient())
            loadPowered(context),
        ],
      ),
    );
  }

  String _sentence(FleetDevice d) {
    if (d.reason == 'battery') {
      return 'Can\'t reach it. The phone closed the app.';
    }
    if (d.reason == 'permission') {
      return 'Almost ready. This computer still needs a permission.';
    }
    if (d.reason == 'service_stopped' || d.reason == 'app_closed') {
      return 'Can\'t reach it. ShamarrConnect isn\'t open there.';
    }
    if (d.online && d.ready != false) {
      return 'Online. You can open it.';
    }
    final seen = formatLastSeen(d.lastSeen);
    if (seen.isEmpty) return 'Not reachable right now.';
    return 'Last seen $seen.';
  }

  Future<void> _open(BuildContext context, FleetDevice d, bool stale) async {
    final name = looksLikeFactoryName(d.deviceName)
        ? 'Computer'
        : d.deviceName.trim();
    if (stale) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(name),
          content: Text(_explain(d)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Try anyway'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
      setState(() => _status = 'Trying $name.');
    } else {
      setState(() => _status = 'You\'re on $name');
    }
    connect(context, d.deviceId);
  }

  String _explain(FleetDevice d) {
    if (d.reason == 'battery') {
      return 'The phone closed the app. Open ShamarrConnect there. On Samsung, set battery to Unrestricted so it stays reachable.';
    }
    if (d.reason == 'permission') {
      return 'That computer still needs a permission. Open ShamarrConnect there and finish setup.';
    }
    final seen = formatLastSeen(d.lastSeen);
    final when = seen.isEmpty ? 'a while ago' : seen;
    return 'Last seen $when. Open ShamarrConnect on that computer, or turn it on. Then you can open it from here.';
  }

  void _shareSheet(BuildContext context) {
    final model = gFFI.serverModel;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share this computer'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Only share these with someone you trust. A session starts after you accept it.',
              ),
              const SizedBox(height: 12),
              _secretBox(ctx, 'Your ID', model.serverId.text),
              const SizedBox(height: 8),
              _secretBox(ctx, 'One-time password', model.serverPasswd.text),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _secretBox(BuildContext context, String label, String value) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value.replaceAll(' ', '')));
        showToast(translate('Copied'));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _connectById(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 720,
          height: 520,
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Connect by ID',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'For a computer that is not on your desk yet.',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const Divider(height: 1),
              const Expanded(child: dconn.ConnectionPage()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addNewComputer() async {
    if (!gFFI.userModel.isLogin) {
      await loginDialog();
      return;
    }
    final code = await gFFI.userModel.enrollGenerate();
    if (code != null && code.isNotEmpty) {
      await showEnrollmentCodeDialog(code);
    }
  }

  IconData _osIcon(String os) {
    final k = os.toLowerCase();
    if (k.contains('android') || k.contains('ios')) return Icons.phone_android;
    if (k.contains('linux')) return Icons.terminal;
    if (k.contains('mac')) return Icons.laptop_mac;
    return Icons.laptop_windows;
  }
}
