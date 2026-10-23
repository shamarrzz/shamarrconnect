import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common.dart';
import '../../desktop/widgets/update_progress.dart';
import '../../models/platform_model.dart';
import '../../models/state_model.dart';

const _brand = Color(0xFF2B5CE6);
const _kIosAppStoreUrl = 'https://apps.apple.com/app/id6824360752';
const _kAndroidPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.shamarrconnect.mobile';
const _kAndroidMarketUrl = 'market://details?id=com.shamarrconnect.mobile';

const softwareUpdateFallbackNotes =
    'Bug fixes, stability improvements, and security updates.';

bool _updateDialogOpen = false;

/// Rank ShamarrConnect tags (`1.4.9-sc32`) or Apple short versions (`1.4.32` -> `sc32`).
int _scVersionRank(String raw) {
  var v = raw.trim();
  if (v.startsWith('v') || v.startsWith('V')) {
    v = v.substring(1).trim();
  }
  if (v.contains('+')) {
    v = v.split('+').first.trim();
  }
  final dashParts = v.split('-');
  final semver = dashParts.first.trim();
  final nums = semver
      .split('.')
      .map((s) => int.tryParse(s.trim()) ?? 0)
      .toList(growable: false);
  if (nums.isEmpty || nums.every((n) => n == 0)) return 0;

  if (dashParts.length > 1) {
    final suffix = dashParts[1].trim().replaceFirst(RegExp(r'^sc'), '');
    final scNum = int.tryParse(suffix) ?? 0;
    final major = nums.isNotEmpty ? nums[0] : 0;
    final minor = nums.length > 1 ? nums[1] : 0;
    final patch = nums.length > 2 ? nums[2] : 0;
    return major * 10000000 + minor * 10000 + patch * 10 + scNum;
  }

  // iOS CFBundleShortVersionString encodes 1.4.9-sc32 as 1.4.32 (minor=4, patch=scNum).
  if (nums.length >= 3 && nums[0] == 1 && nums[1] == 4 && nums[2] >= 20) {
    return 1 * 10000000 + 4 * 10000 + 9 * 10 + nums[2];
  }

  final major = nums.isNotEmpty ? nums[0] : 0;
  final minor = nums.length > 1 ? nums[1] : 0;
  final patch = nums.length > 2 ? nums[2] : 0;
  return major * 10000000 + minor * 10000 + patch * 10;
}

/// True when the server offered a tag strictly newer than the installed build.
bool softwareUpdateVisible(String url) {
  if (url.trim().isEmpty) return false;
  var newer = bind.mainGetNewVersion().trim();
  if (newer.isEmpty && url.contains('/')) {
    newer = url.substring(url.lastIndexOf('/') + 1).trim();
  }
  if (newer.isEmpty) return false;
  final installed = version.trim();
  if (installed.isEmpty) return false;
  if (newer == installed) return false;
  final newerRank = _scVersionRank(newer);
  final installedRank = _scVersionRank(installed);
  if (newerRank > 0 && installedRank > 0) {
    return newerRank > installedRank;
  }
  return newer != installed;
}

String softwareUpdateNotes() {
  final fromState = stateGlobal.updateNotes.value.trim();
  if (fromState.isNotEmpty) return fromState;
  final fromBind =
      bind.mainGetCommonSync(key: 'software-update-notes').trim();
  if (fromBind.isNotEmpty) return fromBind;
  return softwareUpdateFallbackNotes;
}

/// What's New dialog. Returns true when the user chooses to install.
Future<bool> showSoftwareUpdatePreviewDialog(String url) async {
  final ctx = globalKey.currentContext;
  if (ctx == null) return false;
  var installed = version.trim();
  if (installed.isEmpty) {
    try {
      installed = (await bind.mainGetVersion()).trim();
    } catch (_) {}
  }
  if (!ctx.mounted) return false;
  var newer = bind.mainGetNewVersion().trim();
  if (newer.isEmpty && url.contains('/')) {
    newer = url.substring(url.lastIndexOf('/') + 1).trim();
  }
  final notes = softwareUpdateNotes();
  final title = newer.isEmpty
      ? 'Update Available — ShamarrConnect'
      : 'Update Available — ShamarrConnect $newer';
  final actionLabel =
      (isWindows || isMacOS || isLinux) ? 'Update & Restart' : 'Update';
  final go = await showDialog<bool>(
    context: ctx,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final maxWidth = MediaQuery.sizeOf(dialogContext).width - 64;
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: maxWidth > 420 ? 420 : maxWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Installed version: ${installed.isEmpty ? 'unknown' : installed}  →  New version: ${newer.isEmpty ? 'unknown' : newer}',
                ),
                const SizedBox(height: 12),
                const Text(
                  "What's New",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: SingleChildScrollView(child: Text(notes)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not Now'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: _brand,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(actionLabel),
          ),
        ],
      );
    },
  );
  return go == true;
}

/// In-place install (installed Windows/macOS/Linux .deb), mobile store, or release page.
Future<void> openSoftwareUpdate([String? url]) async {
  if (_updateDialogOpen) return;
  final u = (url ?? stateGlobal.updateUrl.value).trim();
  if (!isIOS && !isAndroid && u.isEmpty) return;
  _updateDialogOpen = true;
  try {
    final proceed = await showSoftwareUpdatePreviewDialog(u);
    if (!proceed) return;
    _launchSoftwareUpdate(u);
  } finally {
    _updateDialogOpen = false;
  }
}

void _launchSoftwareUpdate(String url) {
  if (isIOS) {
    launchUrl(Uri.parse(_kIosAppStoreUrl),
        mode: LaunchMode.externalApplication);
    return;
  }
  if (isAndroid) {
    launchUrl(Uri.parse(_kAndroidMarketUrl),
            mode: LaunchMode.externalApplication)
        .then((ok) {
      if (!ok) {
        launchUrl(Uri.parse(_kAndroidPlayStoreUrl),
            mode: LaunchMode.externalApplication);
      }
    }).catchError((_) {
      launchUrl(Uri.parse(_kAndroidPlayStoreUrl),
          mode: LaunchMode.externalApplication);
    });
    return;
  }
  final u = url.trim();
  if (u.isEmpty) return;
  if ((isWindows || isMacOS || isLinux) && bind.mainIsInstalled()) {
    final ver = u.substring(u.lastIndexOf('/') + 1);
    final dlFile = bind.mainGetCommonSync(key: 'download-file-$ver');
    if (!dlFile.startsWith('error:') && dlFile.isNotEmpty) {
      handleUpdate(u);
      return;
    }
  }
  launchUrl(Uri.parse(u));
}

/// Compact Update control for the title bar, left of the Settings hamburger.
class SoftwareUpdateChip extends StatelessWidget {
  const SoftwareUpdateChip({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final url = stateGlobal.updateUrl.value;
      if (!softwareUpdateVisible(url)) return const SizedBox.shrink();
      final ver = bind.mainGetNewVersion();
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Tooltip(
          message: ver.isEmpty
              ? 'A new version is ready'
              : 'A new version is ready ($ver)',
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: _brand,
              minimumSize: const Size(0, 22),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => openSoftwareUpdate(url),
            child: const Text(
              'Update',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
      );
    });
  }
}

/// Home-page strip. Hidden unless the offered tag differs from this build.
class SoftwareUpdateBanner extends StatelessWidget {
  const SoftwareUpdateBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final url = stateGlobal.updateUrl.value;
      if (!softwareUpdateVisible(url)) return const SizedBox.shrink();
      return InkWell(
        onTap: () => openSoftwareUpdate(url),
        child: Container(
          alignment: AlignmentDirectional.center,
          width: double.infinity,
          color: const Color(0xFF0071FF),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            translate('Download new version'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    });
  }
}
