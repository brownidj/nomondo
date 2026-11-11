import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _showKey = false;
  String? _error;
  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _pasteKey() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      final value = data?.text?.trim() ?? '';
      setState(() {
        if (value.isEmpty) {
          _error = 'Copy the Mac pairing key first, then press Paste key.';
        } else {
          _key.text = value;
          _error = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not read the clipboard. Touch and hold the key field to paste.';
        });
      }
    }
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Connect to the Mac’s network. Copy its pairing key and paste it here rather than typing it. The key stays on this phone.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              obscureText: !_showKey,
              maxLines: _showKey ? 3 : 1,
              autocorrect: false,
              enableSuggestions: false,
              smartQuotesType: SmartQuotesType.disabled,
              smartDashesType: SmartDashesType.disabled,
              keyboardType: TextInputType.visiblePassword,
              style: const TextStyle(fontFamily: 'monospace'),
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'Mac pairing key',
                suffixIcon: IconButton(
                  tooltip: _showKey ? 'Hide key' : 'Show key',
                  onPressed: _busy
                      ? null
                      : () => setState(() => _showKey = !_showKey),
                  icon: Icon(
                    _showKey ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _pasteKey,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste key'),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
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
