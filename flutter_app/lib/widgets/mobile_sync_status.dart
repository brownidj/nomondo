import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/mobile_catalogue.dart';
import 'pair_with_mac_dialog.dart';

/// A compact status line; sync problems never replace the local catalogue.
class MobileSyncStatus extends StatelessWidget {
  const MobileSyncStatus({super.key, required this.catalogue});
  final MobileCatalogue catalogue;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: catalogue,
    builder: (context, _) {
      final conflicts = catalogue.conflicts.length;
      final pending = catalogue.pendingCount;
      final label = !catalogue.hasLocalData
          ? 'Connect to your Mac to download the catalogue'
          : conflicts > 0
          ? '$conflicts sync issue(s) · $pending pending'
          : catalogue.syncing
          ? 'Syncing · saved on this device'
          : pending > 0
          ? 'Saved on this device · $pending to sync'
          : !catalogue.hasChanges
          ? 'Saved on this device · no pending changes'
          : catalogue.online
          ? 'Saved on this device · synced'
          : 'Offline · saved on this device';
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _SyncDialog(catalogue: catalogue),
          ),
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(vertical: 3),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 11),
            foregroundColor: conflicts > 0 ? Colors.deepOrange : null,
          ),
          icon: Icon(
            conflicts > 0
                ? Icons.sync_problem
                : catalogue.online
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            size: 14,
          ),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    },
  );
}

class _SyncDialog extends StatefulWidget {
  const _SyncDialog({required this.catalogue});
  final MobileCatalogue catalogue;
  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  String? _error;
  bool _wasSyncing = false;
  bool _completedSync = false;

  @override
  void initState() {
    super.initState();
    _wasSyncing = widget.catalogue.syncing;
    widget.catalogue.addListener(_syncChanged);
  }

  @override
  void dispose() {
    widget.catalogue.removeListener(_syncChanged);
    super.dispose();
  }

  bool get _successfullySynced =>
      !widget.catalogue.syncing &&
      widget.catalogue.online &&
      widget.catalogue.lastError == null &&
      widget.catalogue.lastSynced != null &&
      !widget.catalogue.hasChanges &&
      widget.catalogue.pendingCount == 0 &&
      widget.catalogue.conflicts.isEmpty;

  void _syncChanged() {
    if (_wasSyncing && !widget.catalogue.syncing) {
      _completedSync = _successfullySynced;
      _closeAfterSync();
    }
    _wasSyncing = widget.catalogue.syncing;
  }

  void _closeAfterSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _completedSync &&
          _successfullySynced &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _pair() async {
    await pairWithMac(context, widget.catalogue);
    if (mounted) {
      _closeAfterSync();
    }
  }

  Widget _facts(Map<String, dynamic>? row, {required String fallback}) {
    if (row == null) {
      return Text(fallback);
    }
    const labels = {
      'restaurant_name': 'Name',
      'city': 'City',
      'country': 'Country',
      'address': 'Address',
      'telephone': 'Telephone',
      'internet_link': 'Website',
      'cuisine': 'Cuisine',
      'special_dish': 'Special dishes',
      'notes': 'Notes',
      'region': 'Region',
      'venue_type': 'Venue type',
      'historical_ranking': 'Historical ranking',
      'rating': 'Personal rating',
      'venue_status': 'Venue status',
      'review_status': 'Review status',
      'review_note': 'Review note',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in labels.entries)
          if (row[field.key] != null && row[field.key].toString().isNotEmpty)
            SelectableText('${field.value}: ${row[field.key]}'),
      ],
    );
  }

  Future<void> _resolve(Map<String, dynamic> op, bool useLocal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          useLocal
              ? 'Apply your changes to the Mac record?'
              : 'Use the Mac version?',
        ),
        content: Text(
          useLocal
              ? 'This retries your queued changes against the latest Mac record. Check both versions first.'
              : 'This removes this record’s queued changes from the sync queue. A copy remains in local sync history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.catalogue.resolve(op['key'] as String, useLocal: useLocal);
      if (useLocal) {
        await widget.catalogue.syncAll();
      }
      if (mounted) {
        setState(() => _error = null);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.catalogue,
    builder: (context, _) {
      final catalogue = widget.catalogue;
      return AlertDialog(
        title: const Text('Local storage and sync'),
        scrollable: true,
        content: SizedBox(
          width: 540,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${catalogue.pendingCount} change(s) waiting to sync.'),
              Text(
                'Last download: ${catalogue.lastSynced == null ? 'Not yet' : DateTime.parse(catalogue.lastSynced!).toLocal()}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Sync checks every 15 seconds while the app is open, after at least 5 seconds without interaction. Keep the Mac awake and reachable. An initial catalogue is included. Changes sync when you return to the paired Mac’s network. This window closes when sync succeeds with no pending changes or conflicts. Maps and websites still need internet access.',
              ),
              if (catalogue.pairWithServer != null)
                TextButton.icon(
                  onPressed: catalogue.syncing ? null : _pair,
                  icon: const Icon(Icons.link),
                  label: const Text('Pair with Mac'),
                ),
              if (catalogue.lastError != null) Text(catalogue.lastError!),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              for (final op in catalogue.conflicts)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    (op['before']?['restaurant_name'] ?? 'New venue')
                        .toString(),
                  ),
                  subtitle: Text(op['error'].toString()),
                  children: [
                    const Text(
                      'Your saved change',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _facts(
                      catalogue.localRecord(op['record_id'] as int),
                      fallback: op['method'] == 'DELETE'
                          ? 'You requested deletion of this venue.'
                          : 'Your saved change is retained in local history.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Current Mac record',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _facts(
                      catalogue.serverRecord(op['record_id'] as int),
                      fallback: 'This venue is no longer on the Mac.',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: catalogue.syncing
                              ? null
                              : () => _resolve(op, false),
                          child: const Text('Use Mac version'),
                        ),
                        TextButton(
                          onPressed: catalogue.syncing
                              ? null
                              : () => _resolve(op, true),
                          child: const Text('Apply my changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: catalogue.exportLocalHistory()),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Local sync history copied'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy pending changes and conflict history'),
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
            onPressed: catalogue.syncing ? null : catalogue.syncAll,
            child: Text(catalogue.syncing ? 'Syncing…' : 'Sync now'),
          ),
        ],
      );
    },
  );
}
