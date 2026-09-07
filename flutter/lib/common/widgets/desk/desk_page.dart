import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../common.dart';
import '../../../consts.dart';
import '../../../desktop/pages/connection_page.dart' as dconn;
import '../../../models/fleet_model.dart';
import '../../../models/platform_model.dart';
import '../../../models/server_model.dart';
import '../../../models/user_model.dart';
import '../../../desktop/pages/desktop_tab_page.dart';
import '../../widgets/login.dart';
import '../../place_names.dart';
import '../place_name_dialog.dart';
import 'desk_layout.dart';
import 'desk_memory.dart';

const _navy = Color(0xFF0A1737);
const _brand = Color(0xFF2B5CE6);
const _ok = Color(0xFF16A34A);
const _warn = Color(0xFFD97706);
const _asleep = Color(0xFFC4CDD8);
const _star = Color(0xFFD97706);
const _kHiddenOpt = 'sc_desk_hidden';
const _kMaskOpt = 'sc_desk_mask';

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

  /// Kept so callers still compile. Settings lives on the window title bar.
  final bool showSettings;

  /// Mobile: push the Connection page. Desktop: in-window sheet.
  final VoidCallback? onConnectById;

  /// Android: open the permission wizard. Desktop unused.
  final VoidCallback? onContinueSetup;

  @override
  State<DeskPage> createState() => _DeskPageState();
}

enum _DeskSort { online, name, lastSeen }

enum _DeskFilter { all, starred }

class _DeskPageState extends State<DeskPage> {
  String _myId = '';
  String _status = '';
  String _hoverId = '';
  bool _listMode = false;
  _DeskSort _sort = _DeskSort.online;
  _DeskFilter _filter = _DeskFilter.all;
  /// Quiet attic. Not a pill on the glass. Search still finds them.
  bool _peekHidden = false;
  /// One click: hide names and screen stills on this desk.
  bool _mask = false;
  bool _searchOpen = false;
  String _thisPlace = '';
  int _statusGen = 0;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final Set<String> _favs = {};
  final Set<String> _hidden = {};

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    bind.mainGetMyId().then((id) {
      if (mounted) setState(() => _myId = id);
    });
    _loadPins();
    DeskMemory.preferOwnWindow();
    DeskMemory.warmup().then((_) {
      if (mounted) setState(() {});
    });
    if (gFFI.userModel.isLogin) {
      gFFI.fleetModel.pull();
    }
    if (widget.helpMode || !bind.isOutgoingOnly()) {
      gFFI.serverModel.startService();
    }
  }

  Future<void> _loadPins() async {
    try {
      final favs = await bind.mainGetFav();
      final raw = bind.mainGetLocalOption(key: _kHiddenOpt);
      final hidden = <String>{};
      if (raw.isNotEmpty) {
        try {
          final v = jsonDecode(raw);
          if (v is List) {
            hidden.addAll(v.map((e) => e.toString()));
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _favs
          ..clear()
          ..addAll(favs);
        _hidden
          ..clear()
          ..addAll(hidden);
        _mask = bind.mainGetLocalOption(key: _kMaskOpt) == 'Y';
        final saved = bind.mainGetLocalOption(key: kPlaceNameOpt).trim();
        if (saved.isNotEmpty) _thisPlace = saved;
      });
    } catch (e) {
      debugPrint('desk _loadPins: $e');
    }
  }

  void _persistHidden() {
    bind.mainSetLocalOption(
      key: _kHiddenOpt,
      value: jsonEncode(_hidden.toList()),
    );
  }

  void _persistMask() {
    bind.mainSetLocalOption(key: _kMaskOpt, value: _mask ? 'Y' : 'N');
  }

  bool _isMe(String id) {
    if (_myId.isEmpty || id.isEmpty) return false;
    return sameDeviceId(id, _myId);
  }

  void _toggleMask() {
    setState(() {
      _mask = !_mask;
    });
    _persistMask();
    if (_mask) {
      _flashStatus('Names and stills are hidden.');
    }
  }

  bool get _outgoingOnly => bind.isOutgoingOnly();

  String _thisNameRaw() {
    final saved = bind.mainGetLocalOption(key: kPlaceNameOpt).trim();
    if (saved.isNotEmpty && !looksLikeFactoryName(saved)) {
      return saved;
    }
    if (_thisPlace.isNotEmpty && !looksLikeFactoryName(_thisPlace)) {
      return _thisPlace;
    }
    for (final d in gFFI.fleetModel.devices) {
      if (_isMe(d.deviceId) && d.deviceName.trim().isNotEmpty) {
        final n = d.deviceName.trim();
        if (!looksLikeFactoryName(n)) return n;
      }
    }
    if (_thisPlace.isNotEmpty) return _thisPlace;
    for (final d in gFFI.fleetModel.devices) {
      if (_isMe(d.deviceId) && d.deviceName.trim().isNotEmpty) {
        return d.deviceName.trim();
      }
    }
    final host = loginDeviceHostname();
    if (host.isNotEmpty) return host;
    return 'This computer';
  }

  void _flashStatus(String text) {
    final gen = ++_statusGen;
    setState(() => _status = text);
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted || gen != _statusGen) return;
      if (_status == text) setState(() => _status = '');
    });
  }

  String _thisName() => _mask ? 'This computer' : _thisNameRaw();

  bool _isHidden(String id) => _hidden.any((h) => sameDeviceId(h, id));

  String _localOs() {
    if (isWindows) return kPeerPlatformWindows;
    if (isMacOS) return kPeerPlatformMacOS;
    if (isAndroid) return kPeerPlatformAndroid;
    if (isIOS) return kPeerPlatformMacOS;
    return kPeerPlatformLinux;
  }

  String _osKey(String raw) {
    final k = raw.toLowerCase();
    if (k.contains('win')) return kPeerPlatformWindows;
    if (k.contains('mac') || k.contains('darwin') || k.contains('ios')) {
      return kPeerPlatformMacOS;
    }
    if (k.contains('android')) return kPeerPlatformAndroid;
    if (k.contains('linux')) return kPeerPlatformLinux;
    return raw.isEmpty ? _localOs() : kPeerPlatformWindows;
  }

  Widget _osTile(BuildContext context, String os, {double size = 22}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(0.08) : const Color(0xFFEEF2F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: getPlatformImage(_osKey(os), size: size),
    );
  }

  Future<void> _rename({String? deviceId, required String initial}) async {
    if (!gFFI.userModel.isLogin) {
      await loginDialog();
      if (!gFFI.userModel.isLogin) return;
    }
    final seed = looksLikeFactoryName(initial) ||
            initial.trim().toLowerCase() == 'computer' ||
            initial.trim().toLowerCase() == 'this computer'
        ? ''
        : initial;
    final name = await showPlaceNameDialog(initial: seed);
    if (name == null || name.trim().isEmpty || !mounted) return;
    var id = (deviceId == null || deviceId.isEmpty) ? _myId : deviceId;
    final trimmed = name.trim();
    final me = deviceId == null || deviceId.isEmpty || _isMe(id);
    var uuid = '';
    if (me) {
      _thisPlace = trimmed;
      await bind.mainSetLocalOption(key: kPlaceNameOpt, value: trimmed);
      uuid = await UserModel.accountDeviceUuid();
      if (id.isEmpty) id = uuid;
    } else {
      for (final d in gFFI.fleetModel.devices) {
        if (sameDeviceId(d.deviceId, id)) {
          uuid = d.deviceUuid;
          break;
        }
      }
    }
    if (id.isEmpty && uuid.isEmpty) {
      if (mounted) {
        setState(() => _status = 'Could not rename: this computer has no id yet.');
      }
      return;
    }
    final ok = await gFFI.fleetModel.rename(
      deviceId: id,
      deviceName: trimmed,
      deviceUuid: uuid,
    );
    await bind.mainSetPeerAlias(id: id, alias: trimmed);
    try {
      await gFFI.abModel.changeAlias(id: id, alias: trimmed);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _status = ok
          ? '$trimmed is the name on this desk.'
          : 'Could not save $trimmed on the account. Check you are signed in.';
    });
  }

  Future<void> _toggleStar(String id) async {
    if (id.isEmpty) return;
    final next = _favs.toList();
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    await bind.mainStoreFav(favs: next);
    if (!mounted) return;
    setState(() {
      _favs
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _toggleHide({
    required String id,
    required String name,
  }) async {
    if (id.isEmpty || _isMe(id)) return;
    setState(() {
      if (_isHidden(id)) {
        _hidden.removeWhere((h) => sameDeviceId(h, id));
        _status = '$name is back on the desk.';
        if (_hidden.isEmpty) _peekHidden = false;
      } else {
        _hidden.add(id);
        _status = 'Hidden. Search the name to show it again.';
      }
    });
    _persistHidden();
  }

  Widget _hideBtn(String id, String name) {
    final on = _isHidden(id);
    return IconButton(
      tooltip: on ? 'Show on desk' : 'Hide from this desk',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Icon(
        on ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 18,
        color: Theme.of(context).iconTheme.color?.withOpacity(0.55),
      ),
      onPressed: () => _toggleHide(id: id, name: name),
    );
  }

  Widget _starBtn(String id) {
    final on = _favs.contains(id);
    return IconButton(
      tooltip: on ? 'Unstar' : 'Star',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Icon(
        on ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 20,
        color: on ? _star : Theme.of(context).iconTheme.color?.withOpacity(0.55),
      ),
      onPressed: () => _toggleStar(id),
    );
  }

  Widget _peerMore(BuildContext context, FleetDevice d) {
    final android = _osKey(d.deviceOs) == kPeerPlatformAndroid;
    final winPeer = _osKey(d.deviceOs) == kPeerPlatformWindows;
    final starred = _favs.contains(d.deviceId);
    final hidden = _isHidden(d.deviceId);
    return PopupMenuButton<String>(
      tooltip: 'More',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (v) => _onPeerMore(context, d, v),
      itemBuilder: (_) {
        final hosted = bind.isCustomClient();
        final items = <PopupMenuEntry<String>>[
          PopupMenuItem(value: 'files', child: Text(translate('Transfer file'))),
        ];
        if (!hosted) {
          items.add(PopupMenuItem(
              value: 'camera', child: Text(translate('View camera'))));
          items.add(PopupMenuItem(
              value: 'terminal',
              child: Text('${translate('Terminal')} (beta)')));
        }
        if (!hosted && isDesktop && !android) {
          items.add(PopupMenuItem(
              value: 'tunnel', child: Text(translate('TCP tunneling'))));
        }
        if (isWindows && winPeer) {
          items.add(PopupMenuItem(value: 'rdp', child: Text(translate('RDP'))));
        }
        if (isWindows) {
          items.add(PopupMenuItem(
              value: 'shortcut',
              child: Text(translate('Create desktop shortcut'))));
        }
        items.add(const PopupMenuDivider());
        items.add(
            PopupMenuItem(value: 'rename', child: Text(translate('Rename'))));
        items.add(PopupMenuItem(
          value: 'star',
          child: Text(starred ? 'Unstar' : 'Star'),
        ));
        items.add(PopupMenuItem(
          value: 'hide',
          child: Text(hidden ? 'Show on desk' : 'Hide from this desk'),
        ));
        if (DeskMemory.fileIfPresent(d.deviceId) != null) {
          items.add(const PopupMenuItem(
              value: 'clear_still', child: Text('Remove picture')));
        }
        return items;
      },
    );
  }

  Future<void> _onPeerMore(
      BuildContext context, FleetDevice d, String v) async {
    switch (v) {
      case 'files':
        await connect(context, d.deviceId, isFileTransfer: true);
        break;
      case 'camera':
        await connect(context, d.deviceId, isViewCamera: true);
        break;
      case 'terminal':
        await connect(context, d.deviceId, isTerminal: true);
        break;
      case 'tunnel':
        await connect(context, d.deviceId, isTcpTunneling: true);
        break;
      case 'rdp':
        await connect(context, d.deviceId, isRDP: true);
        break;
      case 'shortcut':
        await bind.mainCreateShortcut(id: d.deviceId);
        showToast(translate('Successful'));
        break;
      case 'star':
        await _toggleStar(d.deviceId);
        break;
      case 'hide':
        await _toggleHide(id: d.deviceId, name: _realName(d));
        break;
      case 'rename':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _rename(deviceId: d.deviceId, initial: _realName(d));
        });
        break;
      case 'clear_still':
        await DeskMemory.clear(d.deviceId);
        if (mounted) {
          setState(() => _status = 'Picture removed from ${_realName(d)}.');
        }
        break;
    }
  }

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
            return CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.slash): _openSearch,
                const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                    _openSearch,
              },
              child: Focus(
                autofocus: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.helpMode)
                      _toolbar(context, loggedIn, devices, stopped),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: _body(context, loggedIn, devices, stopped),
                      ),
                    ),
                    _foot(context, devices, stopped),
                  ],
                ),
              ),
            );
          });
        },
      ),
    );
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  Widget _toolbar(BuildContext context, bool loggedIn,
      List<FleetDevice> devices, bool stopped) {
    final others = devices.where((d) => !_isMe(d.deviceId)).toList();
    final allN = others.where((d) => !_isHidden(d.deviceId)).length;
    final starN = others
        .where((d) => _favs.contains(d.deviceId) && !_isHidden(d.deviceId))
        .length;
    final onlineN =
        others.where((d) => _awake(d) && !_isHidden(d.deviceId)).length +
            ((!stopped) ? 1 : 0);
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    if (_peekHidden) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Computers off this desk. They stay on the account.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _peekHidden = false),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _pill('All', allN + 1, _DeskFilter.all),
                  _pill('Starred', starN, _DeskFilter.starred),
                ],
              ),
            ),
          ),
          _searchBox(muted),
          PopupMenuButton<String>(
            tooltip: 'Sort',
            onSelected: (v) {
              switch (v) {
                case 'online':
                  setState(() => _sort = _DeskSort.online);
                  break;
                case 'name':
                  setState(() => _sort = _DeskSort.name);
                  break;
                case 'seen':
                  setState(() => _sort = _DeskSort.lastSeen);
                  break;
                case 'peek':
                  setState(() => _peekHidden = true);
                  break;
                case 'unpeek':
                  setState(() => _peekHidden = false);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'online', child: Text('Online first')),
              const PopupMenuItem(value: 'name', child: Text('Name')),
              const PopupMenuItem(value: 'seen', child: Text('Last seen')),
              if (_hidden.isNotEmpty) const PopupMenuDivider(),
              if (_hidden.isNotEmpty)
                PopupMenuItem(
                  value: _peekHidden ? 'unpeek' : 'peek',
                  child: Text(_peekHidden
                      ? 'Back to the desk'
                      : 'Show computers I hid'),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.sort, size: 20, color: muted),
            ),
          ),
          IconButton(
            tooltip: _listMode ? 'Cards' : 'List',
            onPressed: () => setState(() => _listMode = !_listMode),
            icon: Icon(
              _listMode ? Icons.grid_view : Icons.view_list,
              size: 20,
              color: muted,
            ),
          ),
          IconButton(
            tooltip: _mask ? 'Show names and stills' : 'Mask names and stills',
            onPressed: _toggleMask,
            icon: Icon(
              _mask ? Icons.blur_off : Icons.blur_on,
              size: 20,
              color: muted,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              onlineN == 1 ? '1 online' : '$onlineN online',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ),
          _account(loggedIn, muted),
        ],
      ),
    );
  }

  Widget _searchBox(Color? muted) {
    final open = _searchOpen || _search.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: open ? 188 : 36,
      height: 32,
      margin: const EdgeInsets.only(right: 2),
      child: open
          ? TextField(
              controller: _search,
              focusNode: _searchFocus,
              onChanged: (_) => setState(() {}),
              onTapOutside: (_) {
                if (_search.text.isEmpty && mounted) {
                  setState(() => _searchOpen = false);
                }
              },
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: IconButton(
                  tooltip: 'Clear',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    _search.clear();
                    setState(() => _searchOpen = false);
                  },
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            )
          : IconButton(
              tooltip: 'Search this desk',
              padding: EdgeInsets.zero,
              onPressed: _openSearch,
              icon: Icon(Icons.search, size: 20, color: muted),
            ),
    );
  }

  Widget _account(bool loggedIn, Color? muted) {
    if (!loggedIn) {
      return TextButton(
        onPressed: () => loginDialog(),
        child: Text(translate('Login')),
      );
    }
    return PopupMenuButton<String>(
      tooltip: gFFI.userModel.displayNameOrUserName,
      onSelected: (v) async {
        if (v == 'settings') {
          DesktopTabPage.onAddSetting();
        } else if (v == 'logout') {
          gFFI.userModel.logOut();
        }
      },
      itemBuilder: (_) => [
        if (isDesktop)
          PopupMenuItem(
            value: 'settings',
            child: Text(translate('Settings')),
          ),
        PopupMenuItem(
          value: 'logout',
          child: Text(translate('Logout')),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          gFFI.userModel.displayNameOrUserName,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, int n, _DeskFilter f) {
    final on = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? _navy : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () async {
            await _loadPins();
            if (!mounted) return;
            setState(() {
              _filter = f;
              _peekHidden = false;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: on ? _navy : Theme.of(context).dividerColor,
              ),
            ),
            child: Text(
              n > 0 ? '$label $n' : label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _realName(FleetDevice d) {
    final n = d.deviceName.trim();
    return n.isEmpty ? 'Computer' : n;
  }

  String _faceName(FleetDevice d) => _mask ? 'Computer' : _realName(d);

  bool _awake(FleetDevice d) => d.online && d.ready != false;

  List<FleetDevice> _others(List<FleetDevice> devices) {
    final q = _search.text.trim().toLowerCase();
    var list = devices.where((d) {
      if (_isMe(d.deviceId)) return false;
      final hidden = _isHidden(d.deviceId);
      final matches = q.isEmpty || _realName(d).toLowerCase().contains(q);
      if (!matches) return false;
      if (_peekHidden) return hidden;
      if (hidden) return q.isNotEmpty;
      if (_filter == _DeskFilter.starred && !_favs.contains(d.deviceId)) {
        return false;
      }
      return true;
    }).toList();
    list.sort((a, b) {
      switch (_sort) {
        case _DeskSort.online:
          final c = (_awake(b) ? 1 : 0) - (_awake(a) ? 1 : 0);
          if (c != 0) return c;
          return _realName(a)
              .toLowerCase()
              .compareTo(_realName(b).toLowerCase());
        case _DeskSort.name:
          return _realName(a)
              .toLowerCase()
              .compareTo(_realName(b).toLowerCase());
        case _DeskSort.lastSeen:
          final at = a.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
      }
    });
    return list;
  }

  Widget _body(
    BuildContext context,
    bool loggedIn,
    List<FleetDevice> devices,
    bool stopped,
  ) {
    final others =
        (loggedIn && !widget.helpMode) ? _others(devices) : <FleetDevice>[];
    final q = _search.text.trim().toLowerCase();
    final showThis = !_peekHidden &&
        (q.isEmpty ||
            _thisName().toLowerCase().contains(q) ||
            'this computer'.contains(q));
    if (_listMode && !widget.helpMode) {
      return _list(context, stopped, others, showThis, loggedIn);
    }
    return _grid(context, stopped, others, showThis, loggedIn);
  }

  Widget _empty(String text) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }

  String _emptyCopy() {
    if (_peekHidden) {
      return 'Nothing is off this desk.';
    }
    if (_filter == _DeskFilter.starred) {
      return 'Star a computer to pin it here. The star is on each card.';
    }
    if (_search.text.trim().isNotEmpty) {
      return 'No computers match that search. A computer you hid will show up if you type its name.';
    }
    return 'No computers match that search.';
  }

  Widget _grid(
    BuildContext context,
    bool stopped,
    List<FleetDevice> others,
    bool showThis,
    bool loggedIn,
  ) {
    final showAdd = loggedIn &&
        !widget.helpMode &&
        !_peekHidden &&
        _filter == _DeskFilter.all &&
        _search.text.trim().isEmpty;
    final cards = <Widget>[
      if (showThis) _thisCard(context, stopped),
      for (final d in others) _placeCard(context, d),
      if (showAdd) _addSlot(context),
    ];
    if (cards.isEmpty) return _empty(_emptyCopy());
    final tall = <bool>[
      if (showThis) false,
      for (final d in others)
        !_mask && DeskMemory.fileIfPresent(d.deviceId) != null,
      if (showAdd) false,
    ];
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final cols = deskColumnCount(w);
      const gap = 10.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      final heights = [
        for (final t in tall)
          deskCardHeight(hasStill: t, cardWidth: cardW),
      ];
      final packed = packShortestColumn(cols: cols, heights: heights);
      return SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var col = 0; col < cols; col++) ...[
              if (col > 0) const SizedBox(width: gap),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final i in packed[col]) ...[
                      cards[i],
                      const SizedBox(height: gap),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _list(
    BuildContext context,
    bool stopped,
    List<FleetDevice> others,
    bool showThis,
    bool loggedIn,
  ) {
    final rows = <Widget>[];
    if (showThis) rows.add(_thisRow(context, stopped));
    for (final d in others) {
      rows.add(_placeRow(context, d));
    }
    if (loggedIn &&
        !widget.helpMode &&
        !_peekHidden &&
        _filter == _DeskFilter.all &&
        _search.text.trim().isEmpty) {
      rows.add(ListTile(
        leading: const Icon(Icons.add),
        title: const Text('+ Add a new computer'),
        onTap: _addNewComputer,
      ));
    }
    if (rows.isEmpty) return _empty(_emptyCopy());
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => rows[i],
    );
  }

  Widget _dot(bool awake, {bool warn = false}) {
    final color = warn
        ? _warn
        : awake
            ? _ok
            : _asleep;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: (awake || warn)
            ? [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _thisRow(BuildContext context, bool stopped) {
    final model = gFFI.serverModel;
    final needSetup = isAndroid && (!model.mediaOk || !model.inputOk);
    final sentence = stopped
        ? 'This computer is not reachable until ShamarrConnect is open.'
        : needSetup
            ? 'Almost ready. This computer still needs a permission.'
            : 'This is the computer you\'re on.';
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(!stopped && !needSetup, warn: stopped || needSetup),
          const SizedBox(width: 8),
          _osTile(context, _localOs(), size: 18),
        ],
      ),
      title: Text(_thisName()),
      subtitle: Text(sentence),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _rename(initial: _thisNameRaw()),
          ),
          if (!_outgoingOnly)
            TextButton(
              onPressed: needSetup
                  ? (widget.onContinueSetup ?? () => _shareSheet(context))
                  : () => _shareSheet(context),
              child: Text(needSetup ? 'Continue setup' : 'Share'),
            ),
        ],
      ),
    );
  }

  Widget _placeRow(BuildContext context, FleetDevice d) {
    final stale = !_awake(d);
    final hidden = _isHidden(d.deviceId);
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(_awake(d),
              warn: d.reason == 'battery' || d.reason == 'permission'),
          const SizedBox(width: 8),
          _osTile(context, d.deviceOs, size: 18),
        ],
      ),
      title: Text(_faceName(d)),
      subtitle: Text(hidden
          ? 'Off this desk. Still on the account.'
          : _sentence(d)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _starBtn(d.deviceId),
          _hideBtn(d.deviceId, _realName(d)),
          _peerMore(context, d),
          TextButton(
            onPressed: () => _open(context, d, stale),
            child: const Text('Open'),
          ),
        ],
      ),
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
      id: _myId.isEmpty ? 'this' : _myId,
      title: _thisName(),
      badge: 'Here',
      isThis: true,
      awake: !stopped && !needSetup,
      warn: stopped || needSetup,
      sentence: sentence,
      os: _localOs(),
      onRename: () => _rename(initial: _thisNameRaw()),
      child: action,
    );
  }

  Widget _placeCard(BuildContext context, FleetDevice d) {
    final name = _realName(d);
    final stale = !_awake(d);
    final hidden = _isHidden(d.deviceId);
    final last = sameDeviceId(DeskMemory.lastId(), d.deviceId);
    return _cardShell(
      context: context,
      id: d.deviceId,
      title: _faceName(d),
      badge: hidden
          ? 'Hidden'
          : last
              ? 'Last'
              : '',
      last: last && !hidden,
      thumb: _mask ? null : DeskMemory.preview(d.deviceId),
      awake: d.online && d.ready != false,
      warn: d.reason == 'battery' || d.reason == 'permission',
      sentence: hidden
          ? 'Off this desk. Still on the account.'
          : _sentence(d),
      os: d.deviceOs,
      onRename: () => _rename(deviceId: d.deviceId, initial: name),
      extra: _peerMore(context, d),
      star: _starBtn(d.deviceId),
      hide: _hideBtn(d.deviceId, name),
      child: _btn(
        context,
        'Open',
        outlined: stale,
        onTap: () => _open(context, d, stale),
      ),
    );
  }

  Widget _addSlot(BuildContext context) {
    final line = Theme.of(context).dividerColor;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _addNewComputer,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: dark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFF),
            border: Border.all(color: line),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: line),
                  ),
                  child: const Icon(Icons.add, size: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  '+ Add a new computer',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardShell({
    required BuildContext context,
    required String id,
    required String title,
    String badge = '',
    bool isThis = false,
    bool last = false,
    Widget? thumb,
    required bool awake,
    bool warn = false,
    required String sentence,
    required String os,
    VoidCallback? onRename,
    Widget? extra,
    Widget? star,
    Widget? hide,
    required Widget child,
  }) {
    final line = Theme.of(context).dividerColor;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hover = _hoverId == id;
    final bg = isThis
        ? (dark ? const Color(0xFF121A2C) : const Color(0xFFF7F9FF))
        : Theme.of(context).colorScheme.background;
    final border = last
        ? _brand
        : isThis
            ? const Color(0xFFD5E0F7)
            : hover
                ? const Color(0xFFC5D4F5)
                : line;
    final lastBadge = badge.toLowerCase() == 'last';
    final hiddenBadge = badge.toLowerCase() == 'hidden';
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _dot(awake, warn: warn),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
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
                            color: hiddenBadge
                                ? const Color(0xFF5A6B85)
                                : lastBadge
                                    ? _brand
                                    : _navy,
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
            if (star != null) star,
            if (hide != null) hide,
            if (onRename != null)
              IconButton(
                tooltip: 'Rename',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.edit_outlined, size: 16),
                onPressed: onRename,
              ),
            if (extra != null) extra,
            _osTile(context, os),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          sentence,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hoverId = id),
      onExit: (_) {
        if (_hoverId == id) setState(() => _hoverId = '');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transformAlignment: Alignment.center,
        transform: Matrix4.translationValues(0, hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: last ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: Color(hover ? 0x1A14285A : 0x0D14285A),
              blurRadius: hover ? 18 : 10,
              offset: Offset(0, hover ? 8 : 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (thumb != null) thumb,
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: body,
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(
    BuildContext context,
    String label, {
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(9),
    );
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 36,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            shape: shape,
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          shape: shape,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _foot(
      BuildContext context, List<FleetDevice> devices, bool stopped) {
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
          else
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
    final name = _realName(d);
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
      _flashStatus('Trying $name.');
    } else {
      _flashStatus('You\'re on $name');
    }
    DeskMemory.remember(d.deviceId);
    if (mounted) setState(() {});
    try {
      await connect(context, d.deviceId)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      if (mounted) {
        setState(() => _status =
            'Couldn\'t open. Check the phone is awake and Share screen is allowed.');
      }
    }
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
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.all(24),
        content: SizedBox(
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
    ).whenComplete(_loadPins);
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
}
