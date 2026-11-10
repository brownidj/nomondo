import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/restaurant_repository.dart';
import '../models/restaurant.dart';
import '../models/restaurant_sort.dart';
import '../services/restaurant_maps.dart';

class RestaurantListPage extends StatefulWidget {
  const RestaurantListPage({super.key});

  @override
  State<RestaurantListPage> createState() => _RestaurantListPageState();
}

class _RestaurantListPageState extends State<RestaurantListPage> {
  final _repository = RestaurantRepository();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<Restaurant> _restaurants = const [];
  String _country = '';
  bool _needsReviewOnly = false;
  bool _loading = false;
  bool _hasLoaded = false;
  bool _failed = false;
  RestaurantSortField _sortField = RestaurantSortField.name;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _repository.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final restaurants = await _repository.load();
      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        _hasLoaded = true;
        if (_country.isNotEmpty &&
            !restaurants.any((restaurant) => restaurant.country == _country)) {
          _country = '';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectSort(RestaurantSortField field, {bool toggle = false}) {
    setState(() {
      _sortAscending = toggle && field == _sortField ? !_sortAscending : true;
      _sortField = field;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toggleSortDirection() {
    setState(() => _sortAscending = !_sortAscending);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final countries =
        _restaurants
            .map((restaurant) => restaurant.country)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    final query = _search.text.trim();
    final visible = _restaurants
        .where((restaurant) {
          return (_country.isEmpty || restaurant.country == _country) &&
              (!_needsReviewOnly || restaurant.needsReview) &&
              (query.isEmpty || restaurant.matches(query));
        })
        .toList(growable: false);
    visible.sort((a, b) => _sortField.compare(a, b, ascending: _sortAscending));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1680),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1150;
                final compact = constraints.maxWidth < 650;
                final padding = compact ? 16.0 : 32.0;
                return Padding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF245D50),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.restaurant_menu_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BeneEde',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const Text('Your world of good food.'),
                              ],
                            ),
                          ),
                          if (compact)
                            IconButton.filledTonal(
                              tooltip: 'Refresh restaurants',
                              onPressed: _loading ? null : _load,
                              icon: const Icon(Icons.refresh_rounded),
                            )
                          else
                            FilledButton.tonalIcon(
                              onPressed: _loading ? null : _load,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'The restaurant collection',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Find a place, a cuisine, or something worth trying.',
                      ),
                      const SizedBox(height: 20),
                      _filters(countries, compact),
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _hasLoaded
                              ? '${visible.length} of ${_restaurants.length} restaurants'
                              : 'Loading your collection…',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_failed) ...[
                        _errorMessage(),
                        const SizedBox(height: 12),
                      ],
                      if (_loading) const LinearProgressIndicator(minHeight: 2),
                      if (wide && visible.isNotEmpty)
                        _TableHeading(
                          sortField: _sortField,
                          ascending: _sortAscending,
                          onSort: (field) => _selectSort(field, toggle: true),
                        ),
                      Expanded(child: _results(visible, wide)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _filters(List<String> countries, bool compact) {
    final search = TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: 'Search restaurants',
        hintText: 'Name, location, cuisine, dish, notes or contact details',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () => setState(_search.clear),
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
    final country = InputDecorator(
      decoration: const InputDecoration(labelText: 'Country'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _country,
          isDense: true,
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: '', child: Text('All countries')),
            ...countries.map(
              (country) => DropdownMenuItem(
                value: country,
                child: Text(country, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _country = value ?? ''),
        ),
      ),
    );
    final locationFilters = compact
        ? Column(children: [search, const SizedBox(height: 12), country])
        : Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 16),
              SizedBox(width: 250, child: country),
            ],
          );
    final reviewCount = _restaurants
        .where((restaurant) => restaurant.needsReview)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        locationFilters,
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              avatar: const Icon(Icons.flag_outlined, size: 18),
              label: Text('Needs review only ($reviewCount)'),
              selected: _needsReviewOnly,
              onSelected: (selected) =>
                  setState(() => _needsReviewOnly = selected),
            ),
            SizedBox(
              width: 230,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Sort by'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RestaurantSortField>(
                    value: _sortField,
                    isDense: true,
                    isExpanded: true,
                    items: RestaurantSortField.values
                        .map(
                          (field) => DropdownMenuItem(
                            value: field,
                            child: Text(field.label),
                          ),
                        )
                        .toList(),
                    onChanged: (field) {
                      if (field != null) _selectSort(field);
                    },
                  ),
                ),
              ),
            ),
            Tooltip(
              message: _sortAscending ? 'Switch to Z–A' : 'Switch to A–Z',
              child: OutlinedButton.icon(
                onPressed: _toggleSortDirection,
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18,
                ),
                label: Text(_sortAscending ? 'A–Z' : 'Z–A'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _errorMessage() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.wifi_off_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _hasLoaded
                ? 'Could not refresh. Your previous results are still shown. '
                      'Check the local data service and try again.'
                : 'Could not load your restaurants. Check that the local data '
                      'service is running, then try Refresh.',
          ),
        ),
      ],
    ),
  );

  Widget _results(List<Restaurant> visible, bool wide) {
    if (!_hasLoaded) {
      return Center(
        child: _loading
            ? const CircularProgressIndicator()
            : const Text('Your collection will appear here when connected.'),
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              _restaurants.isEmpty
                  ? 'No restaurants in the collection yet.'
                  : 'No restaurants match these filters.',
            ),
            if (_restaurants.isNotEmpty)
              TextButton(
                onPressed: () => setState(() {
                  _search.clear();
                  _country = '';
                  _needsReviewOnly = false;
                }),
                child: const Text('Clear filters'),
              ),
          ],
        ),
      );
    }
    return Scrollbar(
      controller: _scroll,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: visible.length,
        separatorBuilder: (_, _) => SizedBox(height: wide ? 1 : 12),
        itemBuilder: (context, index) {
          final restaurant = visible[index];
          return wide
              ? _RestaurantRow(
                  key: ValueKey(restaurant.id),
                  restaurant: restaurant,
                )
              : _RestaurantCard(
                  key: ValueKey(restaurant.id),
                  restaurant: restaurant,
                );
        },
      ),
    );
  }
}

const _columns = <(String, int, RestaurantSortField?)>[
  ('Restaurant name', 3, RestaurantSortField.name),
  ('City', 2, RestaurantSortField.city),
  ('Country', 2, RestaurantSortField.country),
  ('Cuisine', 3, RestaurantSortField.cuisine),
];

class _TableHeading extends StatelessWidget {
  const _TableHeading({
    required this.sortField,
    required this.ascending,
    required this.onSort,
  });

  final RestaurantSortField sortField;
  final bool ascending;
  final ValueChanged<RestaurantSortField> onSort;

  Widget _heading(
    BuildContext context,
    (String, int, RestaurantSortField?) column,
  ) {
    final field = column.$3;
    final label = Text(
      column.$1,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
    if (field == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: label,
      );
    }
    final active = sortField == field;
    final nextAscending = !active || !ascending;
    return Semantics(
      selected: active,
      child: Tooltip(
        message: 'Sort by ${field.label}: ${nextAscending ? 'A–Z' : 'Z–A'}',
        child: TextButton(
          onPressed: () => onSort(field),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: const RoundedRectangleBorder(),
          ),
          child: Row(
            children: [
              Expanded(child: label),
              if (active) ...[
                const SizedBox(width: 4),
                Icon(
                  ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE7ECE5),
    child: Row(
      children: _columns
          .map(
            (column) =>
                Expanded(flex: column.$2, child: _heading(context, column)),
          )
          .toList(),
    ),
  );
}

class _RestaurantName extends StatefulWidget {
  const _RestaurantName(this.restaurant);
  final Restaurant restaurant;

  @override
  State<_RestaurantName> createState() => _RestaurantNameState();
}

class _RestaurantNameState extends State<_RestaurantName> {
  final _telephoneTooltip = GlobalKey<TooltipState>();
  final _internetTooltip = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final telephone = widget.restaurant.telephone?.trim();
    final hasTelephone =
        telephone != null &&
        telephone.isNotEmpty &&
        telephone.toLowerCase() != 'not listed';
    final internetLink = widget.restaurant.internetLink?.trim();
    final hasInternetLink =
        internetLink != null &&
        internetLink.isNotEmpty &&
        internetLink.toLowerCase() != 'not listed';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Value(widget.restaurant.name, prominent: true),
        if (hasTelephone || hasInternetLink)
          Wrap(
            spacing: 4,
            children: [
              if (hasTelephone)
                Tooltip(
                  key: _telephoneTooltip,
                  message: telephone,
                  triggerMode: TooltipTriggerMode.manual,
                  showDuration: const Duration(seconds: 10),
                  child: IconButton(
                    icon: const Icon(
                      Icons.phone_outlined,
                      semanticLabel: 'Telephone',
                    ),
                    onPressed: () =>
                        _telephoneTooltip.currentState?.ensureTooltipVisible(),
                  ),
                ),
              if (hasInternetLink)
                Tooltip(
                  key: _internetTooltip,
                  message: internetLink,
                  triggerMode: TooltipTriggerMode.manual,
                  showDuration: const Duration(seconds: 10),
                  child: IconButton(
                    icon: const Icon(Icons.language, semanticLabel: 'Website'),
                    onPressed: () =>
                        _internetTooltip.currentState?.ensureTooltipVisible(),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _RestaurantCity extends StatefulWidget {
  const _RestaurantCity(this.restaurant);
  final Restaurant restaurant;

  @override
  State<_RestaurantCity> createState() => _RestaurantCityState();
}

class _RestaurantCityState extends State<_RestaurantCity> {
  Future<void> _openMap() async {
    String? message;
    try {
      if (!await openRestaurantMap(widget.restaurant)) {
        message =
            'Could not open Maps. The address is available in the tooltip.';
      }
    } on MissingPluginException {
      message =
          'Maps support needs an app restart. Stop Flutter and run it again.';
    } catch (error) {
      debugPrint('Map launch failed (${error.runtimeType}).');
      message = 'Could not open Maps. The address is available in the tooltip.';
    }
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.restaurant.address?.trim();
    final hasAddress =
        address != null &&
        address.isNotEmpty &&
        address.toLowerCase() != 'not listed';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Value(widget.restaurant.city),
        if (hasAddress)
          Tooltip(
            message: address,
            triggerMode: TooltipTriggerMode.longPress,
            showDuration: const Duration(seconds: 10),
            child: IconButton(
              icon: const Icon(
                Icons.location_on_outlined,
                semanticLabel: 'Open address in Maps',
              ),
              onPressed: _openMap,
            ),
          ),
      ],
    );
  }
}

class _RestaurantRow extends StatelessWidget {
  const _RestaurantRow({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final values = <Widget>[
      _RestaurantName(restaurant),
      _RestaurantCity(restaurant),
      _Value(restaurant.country),
      _CuisineCell(restaurant),
    ];
    return ColoredBox(
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          _columns.length,
          (index) => Expanded(
            flex: _columns[index].$2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: values[index],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RestaurantName(restaurant),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Detail(
                'City',
                restaurant.city,
                child: _RestaurantCity(restaurant),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _Detail('Country', restaurant.country)),
          ],
        ),
        const Divider(height: 28),
        _Detail('Cuisine', restaurant.cuisine, child: _CuisineCell(restaurant)),
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value, {this.child});
  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
      const SizedBox(height: 4),
      child ?? _Value(value),
    ],
  );
}

class _CuisineCell extends StatelessWidget {
  const _CuisineCell(this.restaurant);

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final details = _DetailField.values
        .where((field) => field.hasContent(restaurant))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CuisineValue(restaurant),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: details
                .map((field) => _DetailIcon(restaurant, field: field))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _CuisineValue extends StatelessWidget {
  const _CuisineValue(this.restaurant);

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final cuisine = restaurant.cuisine;
    if (cuisine == null) return const _Value(null);
    final words = cuisine.trim().split(RegExp(r'\s+'));
    if (words.length <= 3) {
      return _Value(cuisine);
    }

    return Tooltip(
      message: 'View cuisine for ${restaurant.name}',
      child: TextButton(
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        onPressed: () => _showRestaurantDetail(
          context,
          restaurantName: restaurant.name,
          label: 'Cuisine',
          content: cuisine,
        ),
        // A word joiner keeps the ellipsis attached to the third word on wrap.
        child: Text('${words.take(3).join(' ')}\u2060…'),
      ),
    );
  }
}

enum _DetailField {
  specialDish('Special dish', '🍽️'),
  notes('Notes', '📝');

  const _DetailField(this.label, this.icon);

  final String label;
  final String icon;

  String? valueOf(Restaurant restaurant) => switch (this) {
    _DetailField.specialDish => restaurant.specialDish,
    _DetailField.notes => restaurant.notes,
  };

  bool hasContent(Restaurant restaurant) {
    final value = valueOf(restaurant)?.trim().toLowerCase();
    return value != null && value.isNotEmpty && value != 'not listed';
  }
}

class _DetailIcon extends StatelessWidget {
  const _DetailIcon(this.restaurant, {required this.field});

  final Restaurant restaurant;
  final _DetailField field;

  @override
  Widget build(BuildContext context) {
    final content = field.valueOf(restaurant);
    if (!field.hasContent(restaurant)) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'View ${field.label.toLowerCase()} for ${restaurant.name}',
      icon: Text(field.icon, style: const TextStyle(fontSize: 24)),
      onPressed: () => _showRestaurantDetail(
        context,
        restaurantName: restaurant.name,
        label: field.label,
        content: content!,
      ),
    );
  }
}

Future<void> _showRestaurantDetail(
  BuildContext context, {
  required String restaurantName,
  required String label,
  required String content,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    scrollable: true,
    title: Text('$label — $restaurantName'),
    content: SelectableText(content),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);

class _Value extends StatelessWidget {
  const _Value(this.value, {this.prominent = false});
  final String? value;
  final bool prominent;

  @override
  Widget build(BuildContext context) => SelectableText(
    value ?? 'Not listed',
    style: TextStyle(
      fontSize: prominent ? 16 : 14,
      fontWeight: prominent ? FontWeight.w600 : FontWeight.w400,
      height: 1.5,
      color: value == null
          ? Theme.of(context).colorScheme.onSurfaceVariant
          : Theme.of(context).colorScheme.onSurface,
    ),
  );
}
