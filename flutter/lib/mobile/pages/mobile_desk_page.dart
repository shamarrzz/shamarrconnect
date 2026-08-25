import 'package:flutter/material.dart';

import '../../common.dart';
import '../../common/widgets/desk/desk_page.dart';
import '../../models/platform_model.dart';
import 'connection_page.dart';
import 'home_page.dart';
import 'onboarding_page.dart';

/// Mobile tab: desk of named computers. Share is on This computer.
class MobileDeskPage extends StatelessWidget implements PageShape {
  MobileDeskPage({this.helpMode = false, Key? key}) : super(key: key);

  final bool helpMode;

  @override
  final title = 'Computers';

  @override
  final icon = const Icon(Icons.devices);

  @override
  final List<Widget> appBarActions = const [];

  @override
  Widget build(BuildContext context) {
    return DeskPage(
      helpMode: helpMode || bind.isIncomingOnly(),
      showSettings: false,
      onConnectById: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Connect by ID')),
            body: ConnectionPage(appBarActions: const []),
          ),
        ));
      },
      onContinueSetup: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OnboardingPage(
            popOnDone: true,
            destination: (_) => const SizedBox.shrink(),
          ),
        ));
      },
    );
  }
}
