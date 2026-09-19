import 'package:flutter/material.dart';

import '../../../common.dart';
import '../../../common/formatter/id_formatter.dart';
import '../../../models/platform_model.dart';

const _brand = Color(0xFF2B5CE6);

/// Small ID sheet. Not the factory ConnectionPage (recents / Terminal / WorkSans).
Future<void> showConnectByIdSheet(BuildContext context) async {
  final id = await showDialog<String>(
    context: context,
    builder: (ctx) => const _ConnectByIdSheet(),
  );
  if (id == null || id.isEmpty) return;
  if (!context.mounted) return;
  await connect(context, id);
}

class _ConnectByIdSheet extends StatefulWidget {
  const _ConnectByIdSheet();

  @override
  State<_ConnectByIdSheet> createState() => _ConnectByIdSheetState();
}

class _ConnectByIdSheetState extends State<_ConnectByIdSheet> {
  final _id = IDTextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    bind.mainGetLastRemoteId().then((last) {
      if (!mounted) return;
      if (last.trim().isEmpty || _id.text.isNotEmpty) return;
      setState(() => _id.id = last);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _id.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go() {
    final id = _id.id;
    if (id.isEmpty) return;
    Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect by ID'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For a computer that is not on your desk yet.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _id,
              focusNode: _focus,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              inputFormatters: [IDTextInputFormatter()],
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _go(),
              decoration: const InputDecoration(
                hintText: 'Nine-digit ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _brand,
            foregroundColor: Colors.white,
          ),
          onPressed: _go,
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
