import 'package:flutter/material.dart';

import '../data/mobile_catalogue.dart';

Future<void> pairWithMac(BuildContext context, MobileCatalogue catalogue) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PairWithMacDialog(catalogue: catalogue),
    );

class _PairWithMacDialog extends StatefulWidget {
  const _PairWithMacDialog({required this.catalogue});
  final MobileCatalogue catalogue;
  @override
  State<_PairWithMacDialog> createState() => _PairWithMacDialogState();
}

class _PairWithMacDialogState extends State<_PairWithMacDialog> {
  final _key = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.catalogue.pairWithServer!(_key.text);
      await widget.catalogue.syncAll();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (problem) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = problem is FormatException
              ? problem.message.toString()
              : 'Could not pair. Check the key and connection to the Mac.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Pair with Mac'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Connect to the Mac’s network and ask the owner for its pairing key. The key stays on this phone.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Mac pairing key'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _pair,
          child: Text(_busy ? 'Pairing…' : 'Pair'),
        ),
      ],
    ),
  );
}
