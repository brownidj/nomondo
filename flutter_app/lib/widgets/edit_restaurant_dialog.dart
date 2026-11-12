import 'package:flutter/material.dart';

import '../data/restaurant_repository.dart';
import '../data/mobile_catalogue.dart';
import '../models/restaurant.dart';
import '../services/restaurant_website.dart';
import '../services/app_capabilities.dart';
import 'city_autocomplete_field.dart';

class RestaurantEditResult {
  const RestaurantEditResult.saved(Restaurant value)
    : restaurant = value,
      deletedId = null,
      addition = null;
  const RestaurantEditResult.deleted(int value)
    : restaurant = null,
      deletedId = value,
      addition = null;
  const RestaurantEditResult.added(this.addition)
    : restaurant = null,
      deletedId = null;
  final RestaurantAddResult? addition;
  final Restaurant? restaurant;
  final int? deletedId;
}

Future<RestaurantEditResult?> editRestaurant(
  BuildContext context,
  Restaurant restaurant,
) async {
  final catalogue = MobileCatalogue.active;
  RestaurantEditResult? result;
  await catalogue?.beginEditing();
  try {
    if (!context.mounted) return null;
    result = await showDialog<RestaurantEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditRestaurantDialog(restaurant),
    );
    return result;
  } finally {
    catalogue?.endEditing(saved: result != null);
  }
}

Future<RestaurantAddResult?> addRestaurant(
  BuildContext context, {
  RestaurantRepository? repository,
}) async {
  final result = await showDialog<RestaurantEditResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EditRestaurantDialog(
      const Restaurant(id: 0, name: ''),
      adding: true,
      repository: repository,
    ),
  );
  return result?.addition;
}

class _EditRestaurantDialog extends StatefulWidget {
  const _EditRestaurantDialog(
    this.restaurant, {
    this.adding = false,
    this.repository,
  });
  final RestaurantRepository? repository;
  final Restaurant restaurant;
  final bool adding;

  @override
  State<_EditRestaurantDialog> createState() => _EditRestaurantDialogState();
}

class _EditRestaurantDialogState extends State<_EditRestaurantDialog> {
  final _form = GlobalKey<FormState>();
  late final RestaurantRepository _repository;
  late final Map<String, String> _initial;
  late final Map<String, TextEditingController> _fields;
  bool _saving = false;
  bool _deleting = false;
  bool _researching = false;
  final _addRequestId = newRestaurantRequestId();
  RestaurantLookupResult? _lookup;
  Map<String, String>? _lookupIdentity;
  String? _lookupMode;
  String _progress = 'Looking up restaurant details…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RestaurantRepository();
    _initial = widget.restaurant.editValues.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
    _fields = _initial.map(
      (key, value) => MapEntry(key, TextEditingController(text: value)),
    );
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _repository.close();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (widget.adding) {
      await _add();
      return;
    }
    final changes = <String, Object?>{};
    for (final field in _fields.entries) {
      if (field.value.text == _initial[field.key]) continue;
      final value = field.value.text.trim();
      changes[field.key] = field.key == 'rating'
          ? double.parse(value)
          : (value.isEmpty ? null : value);
    }
    if (changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _repository.save(widget.restaurant, changes);
      if (mounted) Navigator.of(context).pop(RestaurantEditResult.saved(saved));
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not confirm the save. Keep your changes and try again, or cancel and refresh the list.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, Object?> _newFields() => _fields.map((key, controller) {
    final value = controller.text.trim();
    return MapEntry(
      key,
      key == 'rating' ? double.parse(value) : (value.isEmpty ? null : value),
    );
  });

  bool _meaningful(Object? value) =>
      value != null &&
      ![
        '',
        'not listed',
        'unknown',
        'n/a',
      ].contains(value.toString().trim().toLowerCase());

  bool get _hasWebsite =>
      _meaningful(_fields['internet_link']!.text) &&
      websiteUri(_fields['internet_link']!.text) != null;

  Map<String, String> _identity() => {
    for (final key in ['restaurant_name', 'city', 'country', 'internet_link'])
      key: _fields[key]!.text.trim(),
  };

  Future<void> _add({bool manualOnly = false}) async {
    manualOnly = manualOnly || !allowsRestaurantDiscovery;
    final fields = _newFields();
    if (manualOnly) {
      _lookup = null;
      _lookupIdentity = null;
    }
    String? repeatMode =
        _lookup == null && _error != null && _lookupMode != null
        ? (_meaningful(fields['internet_link']) ? 'website' : 'web')
        : null;
    if (_lookup != null &&
        _lookupIdentity!.entries.any(
          (entry) => _identity()[entry.key] != entry.value,
        )) {
      repeatMode = _meaningful(fields['internet_link']) ? 'website' : 'web';
      _lookup = null;
      _lookupIdentity = null;
    }
    if (_lookup == null && !manualOnly) {
      final supplied = Map<String, Object?>.fromEntries(
        fields.entries.where(
          (entry) =>
              _meaningful(entry.value) &&
              !(entry.key == 'rating' && entry.value == 0),
        ),
      );
      final hasNameAndCity =
          _meaningful(fields['restaurant_name']) && _meaningful(fields['city']);
      String? mode = repeatMode;
      if (mode == null && _meaningful(fields['internet_link'])) {
        mode = 'website';
      } else if (mode == null && hasNameAndCity) {
        final automatic = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Add details automatically?'),
            content: Text(
              'Find missing details and all matching venues in ${fields['city']}? '
              'Web research uses your OpenAI API key and may incur usage charges. You can review the results before adding.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
        if (!mounted || automatic == null) return;
        if (automatic) mode = 'web';
      }
      if (mode != null) {
        setState(() {
          _saving = true;
          _researching = true;
          _lookupMode = mode;
          _error = null;
        });
        try {
          final result = await _repository.lookup(
            supplied,
            mode,
            onProgress: (message) {
              if (mounted) setState(() => _progress = message);
            },
          );
          if (!mounted) return;
          // Fill blanks only. User-supplied facts are never silently overwritten.
          for (final entry in result.venues.first.entries) {
            if (_fields.containsKey(entry.key) &&
                !_meaningful(_fields[entry.key]!.text) &&
                entry.value != null) {
              _fields[entry.key]!.text = entry.value.toString();
            }
          }
          setState(() {
            _lookup = result;
            _lookupIdentity = _identity();
            _lookupMode = mode;
          });
        } on FormatException catch (error) {
          if (mounted) setState(() => _error = error.message);
        } catch (_) {
          if (mounted) {
            setState(
              () => _error = 'Lookup could not finish. Your entered details are still here; try again or add manually.',
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _saving = false;
              _researching = false;
            });
          }
        }
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final records = _lookup == null
          ? [_newFields()]
          : [_newFields(), ..._lookup!.venues.skip(1)];
      final result = await _repository.add(_addRequestId, records, _lookup?.id);
      if (mounted) {
        Navigator.of(context).pop(RestaurantEditResult.added(result));
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not confirm the addition. Retry unchanged details to avoid duplicates, or cancel and refresh.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete restaurant?'),
        content: Text(
          'Delete “${widget.restaurant.name}” from the catalogue? '
          'Any unsaved changes in this editor will be discarded.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _saving = true;
      _deleting = true;
      _error = null;
    });
    try {
      await _repository.delete(widget.restaurant);
      if (mounted) {
        Navigator.of(context)
            .pop(RestaurantEditResult.deleted(widget.restaurant.id));
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not confirm deletion. Cancel and refresh the list before retrying.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _deleting = false;
        });
      }
    }
  }

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    TextInputType? keyboard,
    FocusNode? focusNode,
    VoidCallback? onSubmitted,
    String? helperText,
  }) => TextFormField(
    controller: _fields[key],
    focusNode: focusNode,
    onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
    onChanged:
        widget.adding &&
            ['restaurant_name', 'city', 'internet_link'].contains(key)
        ? (_) => setState(() {})
        : null,
    enabled: !_saving,
    minLines: lines,
    maxLines: lines == 1 ? 1 : lines + 2,
    keyboardType:
        keyboard ?? (lines > 1 ? TextInputType.multiline : TextInputType.text),
    decoration: InputDecoration(
      labelText: label,
      helperText: helperText,
      helperMaxLines: 3,
      errorMaxLines: 3,
      isDense: true,
      alignLabelWithHint: lines > 1,
    ),
    validator: (text) {
      if (!widget.adding &&
          key == 'restaurant_name' &&
          (text?.trim().isEmpty ?? true)) {
        return 'Name is required';
      }
      if (widget.adding &&
          !_hasWebsite &&
          ['restaurant_name', 'city'].contains(key) &&
          [
            '',
            'not listed',
            'unknown',
          ].contains((text ?? '').trim().toLowerCase())) {
        return key == 'city' ? 'City is required' : 'Name is required';
      }
      if (widget.adding &&
          key == 'internet_link' &&
          _meaningful(text) &&
          websiteUri(text!) == null) {
        return 'Enter a valid HTTP or HTTPS website address';
      }
      if (key == 'rating') {
        final rating = double.tryParse(text ?? '');
        if (rating == null || !rating.isFinite || rating < 0) {
          return 'Enter a non-negative number';
        }
      }
      return null;
    },
  );

  Widget _pair(Widget first, Widget second) {
    // AlertDialog uses intrinsic measurement. LayoutBuilder cannot participate
    // in that pass, so choose columns using the available window width instead.
    // Account for the dialog's horizontal insets (32) and content padding (48).
    final contentWidth = MediaQuery.sizeOf(context).width - 80;
    if (contentWidth < 430) {
      return Column(children: [first, const SizedBox(height: 12), second]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }

  Widget _actionBar() {
    final compact =
        MediaQuery.sizeOf(context).width < 480 ||
        MediaQuery.textScalerOf(context).scale(14) > 18;
    final delete = TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
      onPressed: _saving ? null : _delete,
      child: Text(_deleting ? 'Deleting…' : 'Delete'),
    );
    final saveCancel = Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: _saving && !_researching
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _researching
                  ? 'Looking up…'
                  : _saving && !_deleting
                  ? 'Saving…'
                  : widget.adding
                  ? (_lookup != null && _lookup!.venues.length > 1
                        ? 'Add ${_lookup!.venues.length} venues'
                        : 'Add restaurant')
                  : 'Save',
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      width: 560,
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.adding) ...[
                  Align(alignment: Alignment.centerLeft, child: delete),
                  const SizedBox(height: 8),
                ],
                saveCancel,
              ],
            )
          : Row(
              children: [
                if (!widget.adding) delete,
                Expanded(child: saveCancel),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving || _researching,
    child: AlertDialog(
      title: Text(widget.adding ? 'Add restaurant' : 'Edit restaurant'),
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.adding) ...[
                Text(
                  allowsRestaurantDiscovery
                      ? 'Enter restaurant name and city, or an internet address on its own. A website will be used to find missing details and branches, using AI extraction if your OpenAI API key is configured.'
                      : 'Enter restaurant name and city, or an internet address on its own. Your entered details will be saved for review.',
                ),
                const SizedBox(height: 12),
              ],
              if (_researching) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(_progress),
                const SizedBox(height: 12),
              ],
              if (_lookup != null) ...[
                Text(
                  'Review ${_lookup!.venues.length} venue(s), then press Add. All distinct venues below will be included.',
                ),
                if (_lookup!.venues.length > 1)
                  ExpansionTile(
                    title: Text('All ${_lookup!.venues.length} venues'),
                    children: [
                      for (final venue in _lookup!.venues)
                        ListTile(
                          title: Text(
                            venue['restaurant_name']?.toString() ?? '',
                          ),
                          subtitle: Text(
                            venue['address']?.toString() ?? 'Address not found',
                          ),
                        ),
                    ],
                  ),
                if (_lookup!.issues.isNotEmpty)
                  ExpansionTile(
                    title: const Text('Lookup notes'),
                    children: [
                      for (final issue in _lookup!.issues)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(issue),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
              ],
              _field(
                'restaurant_name',
                widget.adding && !_hasWebsite
                    ? 'Restaurant name *'
                    : 'Restaurant name',
              ),
              const SizedBox(height: 12),
              _pair(
                CityAutocompleteField(
                  controller: _fields['city']!,
                  countryController: _fields['country']!,
                  enabled: !_saving,
                  search: _repository.cities,
                  fieldViewBuilder: (context, controller, focus, submit) =>
                      _field(
                        'city',
                        widget.adding && !_hasWebsite ? 'City *' : 'City',
                        focusNode: focus,
                        onSubmitted: submit,
                        helperText: 'Type 2+ letters · GeoNames (CC BY 4.0)',
                      ),
                  onSelected: (city) => setState(() {
                    _fields['country']!.text = city.country;
                    _fields['region']!.text = city.region;
                  }),
                ),
                _field('country', 'Country'),
              ),
              const SizedBox(height: 12),
              _field('address', 'Address', lines: 2),
              const SizedBox(height: 12),
              _pair(
                _field('telephone', 'Telephone', keyboard: TextInputType.phone),
                _field('internet_link', 'Website', keyboard: TextInputType.url),
              ),
              const SizedBox(height: 12),
              _field('cuisine', 'Cuisine', lines: 2),
              const SizedBox(height: 12),
              _field('special_dish', 'Special dishes', lines: 2),
              const SizedBox(height: 12),
              _field('notes', 'Notes', lines: 3),
              ExpansionTile(
                title: const Text('More details'),
                tilePadding: EdgeInsets.zero,
                maintainState: true,
                children: [
                  _pair(
                    _field('region', 'Region'),
                    _field('venue_type', 'Venue type'),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    'historical_ranking',
                    'Historical rankings / awards',
                    lines: 2,
                  ),
                  const SizedBox(height: 12),
                  _pair(
                    _field(
                      'rating',
                      'Personal rating',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_fields['venue_status']!.text),
                      initialValue: _fields['venue_status']!.text,
                      decoration: const InputDecoration(
                        labelText: 'Venue status',
                        isDense: true,
                      ),
                      items: ['open', 'closed', 'renamed', 'unknown']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => _fields['venue_status']!.text =
                                value ?? 'unknown',
                    ),
                  ),
                ],
              ),
              if (widget.adding && _error != null && !_saving)
                TextButton(
                  onPressed: () async {
                    if (_form.currentState!.validate()) {
                      await _add(manualOnly: true);
                    }
                  },
                  child: const Text('Add entered details only'),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [_actionBar()],
    ),
  );
}
