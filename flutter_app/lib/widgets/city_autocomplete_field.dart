import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/restaurant_repository.dart';

/// Suggestions enhance the existing form field; a manual city is always valid.
class CityAutocompleteField extends StatefulWidget {
  const CityAutocompleteField({
    super.key,
    required this.controller,
    required this.countryController,
    required this.search,
    required this.fieldViewBuilder,
    required this.onSelected,
    this.enabled = true,
  });

  final TextEditingController controller;
  final TextEditingController countryController;
  final Future<List<CitySuggestion>> Function(String, String) search;
  final AutocompleteFieldViewBuilder fieldViewBuilder;
  final ValueChanged<CitySuggestion> onSelected;
  final bool enabled;

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  final _focus = FocusNode();
  int _request = 0;
  late String _country;

  @override
  void initState() {
    super.initState();
    _country = widget.countryController.text;
    widget.countryController.addListener(_countryChanged);
  }

  void _countryChanged() {
    if (_country == widget.countryController.text) return;
    setState(() {
      _country = widget.countryController.text;
      _request++;
    });
  }

  @override
  void dispose() {
    _request++;
    widget.countryController.removeListener(_countryChanged);
    _focus.dispose();
    super.dispose();
  }

  Future<Iterable<CitySuggestion>> _options(TextEditingValue value) async {
    final request = ++_request;
    final query = value.text.trim();
    if (!widget.enabled || query.length < 2 || query.length > 80) {
      return const [];
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || request != _request) return const [];
    try {
      final options = await widget.search(query, _country);
      return mounted && request == _request ? options : const [];
    } catch (_) {
      // Keep manual entry available if the service or city index is unavailable.
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<CitySuggestion>(
    key: ValueKey(_country),
    textEditingController: widget.controller,
    focusNode: _focus,
    displayStringForOption: (city) => city.name,
    optionsBuilder: _options,
    optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
    fieldViewBuilder: widget.fieldViewBuilder,
    onSelected: widget.onSelected,
    optionsViewBuilder: (context, select, options) {
      final cities = options.toList(growable: false);
      return Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: math.min(
              360.0,
              math.max(0.0, MediaQuery.sizeOf(context).width - 80),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: cities.length,
                itemBuilder: (context, index) {
                  final city = cities[index];
                  return ListTile(
                    dense: true,
                    selected:
                        AutocompleteHighlightedOption.of(context) == index,
                    title: Text(city.name),
                    subtitle: Text(
                      [
                        city.region,
                        city.country,
                      ].where((part) => part.isNotEmpty).join(' · '),
                    ),
                    onTap: () => select(city),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
