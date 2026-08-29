import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common.dart';
import '../../desktop/widgets/update_progress.dart';
import '../../models/platform_model.dart';
import '../../models/state_model.dart';

const _brand = Color(0xFF2B5CE6);

/// In-place install (installed Windows/macOS) or open the GitHub release page.
void openSoftwareUpdate([String? url]) {
  final u = (url ?? stateGlobal.updateUrl.value).trim();
  if (u.isEmpty) return;
  if ((isWindows || isMacOS) && bind.mainIsInstalled()) {
    handleUpdate(u);
    return;
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
      if (url.isEmpty) return const SizedBox.shrink();
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
