import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/restaurant_repository.dart';
import '../models/restaurant.dart';
import '../services/restaurant_website.dart';
import 'edit_restaurant_dialog.dart';

const _labels = {
  'restaurant_name': 'Restaurant',
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
};

Future<RestaurantEditResult?> reviewRestaurant(
  BuildContext context,
  Restaurant restaurant, {
  RestaurantRepository? repository,
}) => showDialog<RestaurantEditResult>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ReviewRestaurantDialog(restaurant, repository),
);

class _ReviewRestaurantDialog extends StatefulWidget {
  const _ReviewRestaurantDialog(this.restaurant, this.repository);
  final Restaurant restaurant;
  final RestaurantRepository? repository;

  @override
  State<_ReviewRestaurantDialog> createState() =>
      _ReviewRestaurantDialogState();
}

class _ReviewRestaurantDialogState extends State<_ReviewRestaurantDialog> {
  late final RestaurantRepository _repository;
  late Restaurant _restaurant;
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  final _noteKey = GlobalKey();
  bool _noteAtTop = false;
  Map<String, dynamic>? _details;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restaurant = widget.restaurant;
    _repository = widget.repository ?? RestaurantRepository();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    _repository.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await _repository.reviewDetails(_restaurant.id);
      if (!mounted) return;
      setState(() {
        _details = details;
        _restaurant = Restaurant.fromJson(
          details['restaurant'] as Map<String, dynamic>,
        );
        _changed =
            _changed || _restaurant.revision != widget.restaurant.revision;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load review details. Try Reload.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final result = await editRestaurant(context, _restaurant);
    if (!mounted || result == null) return;
    if (result.deletedId != null) {
      Navigator.of(context).pop(result);
    } else if (result.restaurant != null) {
      _restaurant = result.restaurant!;
      _changed = true;
      await _load();
    }
  }

  Future<void> _decide(String decision) async {
    if (_busy || _loading) return;
    if (decision == 'failed') {
      setState(() => _noteAtTop = true);
      if (_note.text.trim().isEmpty) {
        setState(
          () => _error =
              'Enter the reason this restaurant failed before archiving it.',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _noteFocus.requestFocus();
          final noteContext = _noteKey.currentContext;
          if (noteContext != null) {
            Scrollable.ensureVisible(
              noteContext,
              duration: const Duration(milliseconds: 200),
              alignment: .25,
            );
          }
        });
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Archive failed restaurant?'),
          content: Text(
            '${_restaurant.name} will leave the active catalogue. Its details and history remain available in Archived, where you can restore it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await _repository.saveReview(
        _restaurant,
        decision,
        _note.text,
      );
      if (mounted) Navigator.of(context).pop(RestaurantEditResult.saved(saved));
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not confirm the review. Reload to check whether it was saved before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _reviewNote() => Padding(
    key: _noteKey,
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _note,
      focusNode: _noteFocus,
      enabled: !_busy,
      minLines: 2,
      maxLines: 4,
      maxLength: 4000,
      decoration: const InputDecoration(
        labelText: 'New review note',
        helperText: 'Required when failing and archiving a restaurant.',
      ),
    ),
  );

  Widget _detail(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        SelectableText(
          value == null || value.toString().trim().isEmpty
              ? 'Not listed'
              : value.toString(),
        ),
      ],
    ),
  );

  Widget _sourceLink(String url) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(url),
      onPressed: websiteUri(url) == null
          ? null
          : () async {
              try {
                if (await openRestaurantWebsite(websiteUri(url)!)) return;
              } catch (_) {
                /* Report below, keeping the review open. */
              }
              if (mounted) {
                setState(() => _error = 'Could not open that source.');
              }
            },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final reasons = (details?['review_reasons'] as List?) ?? const [];
    final evidence = (details?['evidence'] as List?) ?? const [];
    final sources = (details?['sources'] as List?) ?? const [];
    final history = (details?['history'] as List?) ?? const [];
    final alternatives = (details?['alternatives'] as List?) ?? const [];
    final duplicates = (details?['duplicate_ids'] as List?) ?? const [];
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('Review — ${_restaurant.name}'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        content: SizedBox(
          width: 620,
          height: MediaQuery.sizeOf(context).height * .62,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (details?['offline_notice'] != null) ...[
                  Text(
                    details!['offline_notice'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_noteAtTop) _reviewNote(),
                _detail('Review status', _restaurant.reviewLabel),
                if (_restaurant.reviewedAt != null)
                  _detail('Last review action', _restaurant.reviewedAt),
                if (_restaurant.reviewNote.isNotEmpty)
                  _detail('Previous review note', _restaurant.reviewNote),
                const Text(
                  'Check the flags against the details and sources below. Your decision is separate from the recorded venue status.',
                ),
                const SizedBox(height: 12),
                Text(
                  _restaurant.reviewStatus == 'passed'
                      ? 'Flags retained from before review'
                      : 'Why this record needs review',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (details != null && reasons.isEmpty)
                  const Text('No automatic review reasons were recorded.'),
                for (final reason in reasons)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('• $reason'),
                  ),
                if (duplicates.isNotEmpty)
                  _detail(
                    'Possible duplicate record IDs',
                    duplicates.join(', '),
                  ),
                if (details?['confidence'] != null)
                  _detail('Research confidence', details!['confidence']),
                const SizedBox(height: 12),
                ExpansionTile(
                  title: const Text('Restaurant details'),
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  children: [
                    if (!_restaurant.isArchived)
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _busy || _loading || details == null
                              ? null
                              : _edit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit details'),
                        ),
                      ),
                    for (final entry in _restaurant.editValues.entries)
                      _detail(_labels[entry.key] ?? entry.key, entry.value),
                  ],
                ),
                ExpansionTile(
                  title: Text('Supporting evidence (${evidence.length})'),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    if (evidence.isEmpty)
                      const Text('No source evidence was saved.'),
                    for (final item in evidence)
                      if (item is Map)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _detail(
                              (item['field'] ?? 'Source').toString(),
                              item['detail'],
                            ),
                            if (item['url'] is String)
                              _sourceLink(item['url'] as String),
                          ],
                        ),
                  ],
                ),
                ExpansionTile(
                  title: const Text('Original source entries'),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    for (final item in sources)
                      if (item is Map)
                        _detail(
                          '${item['source_file']} · line ${item['line_number']}',
                          item['raw_text'],
                        ),
                  ],
                ),
                if (alternatives.isNotEmpty)
                  ExpansionTile(
                    title: const Text(
                      'Preserved details from consolidated records',
                    ),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      SelectableText(
                        const JsonEncoder.withIndent('  ')
                            .convert(alternatives),
                      ),
                    ],
                  ),
                ExpansionTile(
                  title: const Text('Review history'),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    if (history.isEmpty)
                      const Text('No review decisions recorded yet.'),
                    for (final item in history)
                      if (item is Map)
                        _detail(
                          '${item['decision']} · ${item['reviewed_at']}',
                          item['note'],
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_noteAtTop) _reviewNote(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy || _loading ? null : _load,
            child: const Text('Reload'),
          ),
          if (_restaurant.isArchived)
            FilledButton.icon(
              onPressed: _busy || _loading || details == null
                  ? null
                  : () => _decide('restore'),
              icon: const Icon(Icons.unarchive_outlined),
              label: const Text('Restore'),
            )
          else ...[
            TextButton(
              onPressed: _busy || _loading || details == null
                  ? null
                  : () => _decide('pending'),
              child: const Text('Keep pending'),
            ),
            OutlinedButton(
              onPressed: _busy || _loading || details == null
                  ? null
                  : () => _decide('failed'),
              child: const Text('Fail & archive'),
            ),
            FilledButton(
              onPressed: _busy || _loading || details == null
                  ? null
                  : () => _decide('passed'),
              child: const Text('Pass'),
            ),
          ],
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pop(
                    _changed ? RestaurantEditResult.saved(_restaurant) : null,
                  ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
