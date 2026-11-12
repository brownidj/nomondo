import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../data/restaurant_repository.dart';
import '../data/mobile_catalogue.dart';
import '../widgets/mobile_sync_status.dart';
import '../models/restaurant.dart';
import '../models/restaurant_sort.dart';
import '../services/restaurant_maps.dart';
import '../services/restaurant_website.dart';
import '../widgets/contact_tooltip.dart';
import '../widgets/edit_restaurant_dialog.dart';
import '../widgets/review_restaurant_dialog.dart';
import '../widgets/restaurant_review_indicator.dart';
import '../widgets/cuisine_details.dart';
import '../services/app_capabilities.dart';

class RestaurantListPage extends StatefulWidget {
  const RestaurantListPage({super.key, this.repository});
  final RestaurantRepository? repository;

  @override
  State<RestaurantListPage> createState() => _RestaurantListPageState();
}

class _RestaurantListPageState extends State<RestaurantListPage>
    with WidgetsBindingObserver {
  MobileCatalogue? _offline;
  int _generation = -1;

  void _localChanged() {
    if (_offline!.editing) return;
    if (_offline!.generation == _generation) return;
    _generation = _offline!.generation;
    if (mounted) _load();
  }

  void _pointerActivity(PointerEvent event) => _offline?.activity();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _offline?.resume();
    } else {
      _offline?.pause();
    }
  }

  Future<void> _refresh() async {
    if (_offline != null) {
      await _offline!.syncAll();
    }
    if (mounted) await _load();
  }

  late final RestaurantRepository _repository;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<Restaurant> _restaurants = const [];
  String _country = '';
  String _city = '';
  bool _needsReviewOnly = false;
  bool _showArchived = false;
  bool _loading = false;
  bool _hasLoaded = false;
  bool _failed = false;
  RestaurantSortField _sortField = RestaurantSortField.name;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RestaurantRepository();
    _offline = widget.repository == null ? MobileCatalogue.active : null;
    _offline?.addListener(_localChanged);
    _offline?.resume();
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointerActivity);
    _load();
  }

  @override
  void dispose() {
    _offline?.removeListener(_localChanged);
    _offline?.pause();
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointerActivity);
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
            !_locationOptions(
              restaurants.map((restaurant) => restaurant.country),
            ).contains(_country)) {
          _country = '';
        }
        if (_city.isNotEmpty && !_citiesFor(_country).contains(_city)) {
          _city = '';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _acceptEdit(Restaurant updated) {
    if (!mounted) return;
    setState(() {
      _restaurants = _restaurants
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
      if (!_locationOptions(_restaurants.map((item) => item.country))
          .contains(_country)) {
        _country = '';
      }
      if (!_citiesFor(_country).contains(_city)) _city = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _offline == null
              ? 'Restaurant saved'
              : 'Saved on this device — waiting to sync',
        ),
      ),
    );
  }

  void _acceptDelete(int id) {
    if (!mounted) return;
    setState(() {
      _restaurants = _restaurants.where((item) => item.id != id).toList();
      if (!_locationOptions(_restaurants.map((item) => item.country))
          .contains(_country)) {
        _country = '';
      }
      if (!_citiesFor(_country).contains(_city)) _city = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _offline == null
              ? 'Restaurant deleted'
              : 'Removed on this device — waiting to sync',
        ),
      ),
    );
  }

  Future<void> _addRestaurant() async {
    final result = await addRestaurant(context);
    if (!mounted || result == null) return;
    setState(() {
      final records = {
        for (final restaurant in _restaurants) restaurant.id: restaurant,
      };
      for (final restaurant in result.restaurants) {
        records[restaurant.id] = restaurant;
      }
      _restaurants = records.values.toList();
    });
    await _load();
    if (!mounted) return;
    final message =
        '${result.addedCount} restaurant(s) added'
        '${result.existingCount > 0 ? '; ${result.existingCount} already in the catalogue' : ''}';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
    final countries = _locationOptions(
      _restaurants.map((restaurant) => restaurant.country),
    );
    final cities = _citiesFor(_country);
    final query = _search.text.trim();
    final visible = _restaurants
        .where((restaurant) {
          return restaurant.isArchived == _showArchived &&
              (_country.isEmpty ||
                  _sameLocation(restaurant.country, _country)) &&
              (_city.isEmpty || _sameLocation(restaurant.city, _city)) &&
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
                final wide = !isMobilePlatform && constraints.maxWidth >= 1150;
                final compact = constraints.maxWidth < 650;
                final padding = compact ? 16.0 : 32.0;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    padding,
                    isMobilePlatform ? 8 : 24,
                    padding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/beneede-icon.png',
                              width: 48,
                              height: 48,
                              cacheWidth: 144,
                              semanticLabel: 'BeneEde icon',
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
                                const Text('Your world of good eats.'),
                              ],
                            ),
                          ),
                          if (compact)
                            IconButton.filledTonal(
                              tooltip: 'Refresh restaurants',
                              onPressed: _loading ? null : _refresh,
                              icon: const Icon(Icons.refresh_rounded),
                            )
                          else
                            FilledButton.tonalIcon(
                              onPressed: _loading ? null : _refresh,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh'),
                            ),
                        ],
                      ),
                      SizedBox(height: isMobilePlatform ? 10 : 28),
                      Text(
                        'The restaurant collection',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Find a place, a cuisine, or something worth trying.',
                      ),
                      SizedBox(height: isMobilePlatform ? 8 : 20),
                      _filters(countries, cities, constraints.maxWidth < 1000),
                      SizedBox(height: isMobilePlatform ? 6 : 16),
                      if (_offline != null)
                        MobileSyncStatus(catalogue: _offline!),
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

  bool _sameLocation(String? value, String selected) =>
      value?.trim().toLowerCase() == selected.toLowerCase();

  List<String> _locationOptions(Iterable<String?> values) {
    final labels = <String, String>{};
    for (final value in values) {
      final label = value?.trim() ?? '';
      if (label.isNotEmpty && label.toLowerCase() != 'not listed') {
        labels.putIfAbsent(label.toLowerCase(), () => label);
      }
    }
    return labels.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> _citiesFor(String country) => _locationOptions(
    _restaurants
        .where(
          (restaurant) =>
              country.isEmpty || _sameLocation(restaurant.country, country),
        )
        .map((restaurant) => restaurant.city),
  );

  Widget _filters(List<String> countries, List<String> cities, bool compact) {
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
      decoration: const InputDecoration(labelText: 'Countries'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _country,
          isDense: true,
          isExpanded: true,
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text(
                'All countries',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            ...countries.map(
              (country) => DropdownMenuItem(
                value: country,
                child: Text(country, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) => setState(() {
            _country = value ?? '';
            if (_city.isNotEmpty && !_citiesFor(_country).contains(_city)) {
              _city = '';
            }
          }),
        ),
      ),
    );
    final city = InputDecorator(
      decoration: const InputDecoration(labelText: 'Cities'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _city,
          isDense: true,
          isExpanded: true,
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text(
                'All cities',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            ...cities.map(
              (city) => DropdownMenuItem(
                value: city,
                child: Text(city, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _city = value ?? ''),
        ),
      ),
    );
    final locationFilters = compact || isMobilePlatform
        ? Column(
            children: [
              search,
              const SizedBox(height: 12),
              if (isMobilePlatform)
                Row(
                  children: [
                    Expanded(child: country),
                    const SizedBox(width: 12),
                    Expanded(child: city),
                  ],
                )
              else ...[
                country,
                const SizedBox(height: 12),
                city,
              ],
            ],
          )
        : Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 16),
              SizedBox(width: 230, child: country),
              const SizedBox(width: 16),
              SizedBox(width: 230, child: city),
            ],
          );
    final reviewCount = _restaurants
        .where((restaurant) => !restaurant.isArchived && restaurant.needsReview)
        .length;
    final sortSelector = InputDecorator(
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
                  child: Text(
                    field.label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              )
              .toList(),
          onChanged: (field) {
            if (field != null) _selectSort(field);
          },
        ),
      ),
    );
    final directionControl = Tooltip(
      message: _sortField == RestaurantSortField.confidence
          ? (_sortAscending
                ? 'Show highest confidence first'
                : 'Show lowest confidence first')
          : (_sortAscending ? 'Switch to Z–A' : 'Switch to A–Z'),
      child: OutlinedButton.icon(
        onPressed: _toggleSortDirection,
        icon: Icon(
          _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
          size: 18,
        ),
        label: Text(
          _sortField == RestaurantSortField.confidence
              ? (_sortAscending ? 'Low–high' : 'High–low')
              : (_sortAscending ? 'A–Z' : 'Z–A'),
        ),
      ),
    );
    final sortingControls = Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          avatar: const Icon(Icons.flag_outlined, size: 18),
          label: Text('Needs review only ($reviewCount)'),
          selected: _needsReviewOnly,
          onSelected: (selected) => setState(() {
            _needsReviewOnly = selected;
            if (selected) {
              _showArchived = false;
              _sortField = RestaurantSortField.confidence;
              _sortAscending = true;
            }
          }),
        ),
        FilterChip(
          avatar: const Icon(Icons.inventory_2_outlined, size: 18),
          label: const Text('Archived'),
          selected: _showArchived,
          onSelected: (selected) => setState(() {
            _showArchived = selected;
            _needsReviewOnly = false;
          }),
        ),
        SizedBox(width: 230, child: sortSelector),
        directionControl,
      ],
    );
    final addButton = IconButton.filled(
      onPressed: _loading ? null : _addRestaurant,
      tooltip: 'Add restaurant',
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF269344),
        foregroundColor: Colors.white,
      ),
      icon: const Text(
        '+',
        style: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        locationFilters,
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (isMobilePlatform) {
              return Row(
                children: [
                  Expanded(child: sortSelector),
                  const SizedBox(width: 8),
                  directionControl,
                  const SizedBox(width: 8),
                  addButton,
                ],
              );
            }
            if (constraints.maxWidth < 820) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sortingControls,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: addButton),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: sortingControls),
                const SizedBox(width: 16),
                addButton,
              ],
            );
          },
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
            isMobilePlatform
                ? 'Could not connect to your Mac’s restaurant catalogue. Keep your Mac awake and both devices on the same Wi-Fi, then try Refresh.'
                : _hasLoaded
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
        padding: EdgeInsets.only(bottom: isMobilePlatform ? 8 : 24),
        itemCount: visible.length,
        separatorBuilder: (_, _) => SizedBox(
          height: wide
              ? 1
              : isMobilePlatform
              ? 3
              : 12,
        ),
        itemBuilder: (context, index) {
          final restaurant = visible[index];
          return wide
              ? _RestaurantRow(
                  key: ValueKey(restaurant.id),
                  restaurant: restaurant,
                  onSaved: _acceptEdit,
                  onDeleted: _acceptDelete,
                )
              : _RestaurantCard(
                  key: ValueKey(restaurant.id),
                  restaurant: restaurant,
                  onSaved: _acceptEdit,
                  onDeleted: _acceptDelete,
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
  const _RestaurantName(
    this.restaurant, {
    required this.onSaved,
    required this.onDeleted,
  });
  final Restaurant restaurant;
  final ValueChanged<Restaurant> onSaved;
  final ValueChanged<int> onDeleted;

  @override
  State<_RestaurantName> createState() => _RestaurantNameState();
}

class _RestaurantNameState extends State<_RestaurantName> {
  final _telephoneTooltip = GlobalKey<TooltipState>();
  bool _websiteUnavailable = false;
  bool _checkingWebsite = false;

  @override
  void didUpdateWidget(covariant _RestaurantName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurant.id != widget.restaurant.id ||
        oldWidget.restaurant.internetLink != widget.restaurant.internetLink) {
      _websiteUnavailable = false;
      _checkingWebsite = false;
    }
  }

  Future<void> _edit() async {
    final result = await editRestaurant(context, widget.restaurant);
    if (!mounted || result == null) return;
    if (result.deletedId != null) {
      widget.onDeleted(result.deletedId!);
    } else if (result.restaurant != null) {
      widget.onSaved(result.restaurant!);
    }
  }

  Future<void> _review() async {
    final result = await reviewRestaurant(context, widget.restaurant);
    if (!mounted || result == null) return;
    if (result.deletedId != null) {
      widget.onDeleted(result.deletedId!);
    } else if (result.restaurant != null) {
      widget.onSaved(result.restaurant!);
    }
  }

  Future<void> _openWebsite() async {
    if (_checkingWebsite) return;
    final restaurant = widget.restaurant;
    final raw = restaurant.internetLink ?? '';
    final uri = websiteUri(raw);
    if (uri == null) {
      setState(() => _websiteUnavailable = true);
      return;
    }
    setState(() => _checkingWebsite = true);
    bool unavailable = false;
    String? message;
    try {
      final opened = await openRestaurantWebsite(uri);
      unavailable = !opened;
      if (opened) {
        unavailable = await checkRestaurantWebsite(restaurant.id) == false;
      }
    } on MissingPluginException {
      message = 'Website support needs an app restart. Stop Flutter and run it again.';
    } catch (_) {
      unavailable = true;
    }
    if (!mounted ||
        widget.restaurant.id != restaurant.id ||
        widget.restaurant.internetLink != raw) {
      return;
    }
    setState(() {
      _checkingWebsite = false;
      _websiteUnavailable = unavailable;
    });
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

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
    final name = SelectionArea(
      key: ValueKey('restaurant-name-${widget.restaurant.id}'),
      child: Text.rich(
        TextSpan(
          text: widget.restaurant.name,
          children: [
            if (!widget.restaurant.isArchived)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: RestaurantReviewIndicator(
                  restaurant: widget.restaurant,
                  onReview: _review,
                  compact: isMobilePlatform,
                ),
              ),
          ],
        ),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
    final actions = Wrap(
      spacing: isMobilePlatform ? 0 : 4,
      children: [
        if (hasTelephone)
          ContactTooltip(
            tooltipKey: _telephoneTooltip,
            message: telephone,
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
          ContactTooltip(
            message:
                'Press $internetLink to open the website'
                '${_websiteUnavailable ? '\nWebsite unavailable' : ''}',
            child: IconButton(
              icon: Icon(
                Icons.language,
                color: _websiteUnavailable ? Colors.red : null,
                semanticLabel: _websiteUnavailable
                    ? 'Website unavailable'
                    : 'Open website',
              ),
              onPressed: _checkingWebsite ? null : _openWebsite,
            ),
          ),
        ContactTooltip(
          message: 'Edit restaurant',
          child: IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              semanticLabel: 'Edit restaurant',
            ),
            onPressed: _edit,
          ),
        ),
        if (widget.restaurant.isArchived) ...[
          ContactTooltip(
            message: 'Review archived restaurant',
            child: IconButton(
              icon: const Icon(
                Icons.inventory_2_outlined,
                color: Colors.red,
                semanticLabel: 'Review archived restaurant',
              ),
              onPressed: _review,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              widget.restaurant.reviewLabel,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ],
    );
    if (isMobilePlatform) {
      return IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            iconSize: 18,
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: name),
            const SizedBox(width: 4),
            actions,
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [name, actions],
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
        message = 'Could not open Maps. Please try again.';
      }
    } on MissingPluginException {
      message =
          'Maps support needs an app restart. Stop Flutter and run it again.';
    } catch (error) {
      debugPrint('Map launch failed (${error.runtimeType}).');
      message = 'Could not open Maps. Please try again.';
    }
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final city = widget.restaurant.city?.trim();
    if (city == null || city.isEmpty || city.toLowerCase() == 'not listed') {
      return isMobilePlatform
          ? const Text('City: Not listed', style: TextStyle(fontSize: 13))
          : _Value(widget.restaurant.city);
    }
    return ContactTooltip(
      message: 'Click to show map and address',
      child: TextButton(
        onPressed: _openMap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size(0, isMobilePlatform ? 0 : 32),
          tapTargetSize: isMobilePlatform
              ? MaterialTapTargetSize.shrinkWrap
              : null,
          alignment: Alignment.centerLeft,
          textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: isMobilePlatform ? 13 : 14,
            fontWeight: FontWeight.w400,
            height: isMobilePlatform ? 1.3 : 1.5,
          ),
        ),
        child: Text(
          isMobilePlatform ? 'City: $city' : city,
          textAlign: TextAlign.left,
        ),
      ),
    );
  }
}

class _RestaurantRow extends StatelessWidget {
  const _RestaurantRow({
    super.key,
    required this.restaurant,
    required this.onSaved,
    required this.onDeleted,
  });
  final Restaurant restaurant;
  final ValueChanged<Restaurant> onSaved;
  final ValueChanged<int> onDeleted;

  @override
  Widget build(BuildContext context) {
    final values = <Widget>[
      _RestaurantName(restaurant, onSaved: onSaved, onDeleted: onDeleted),
      _RestaurantCity(restaurant),
      _Value(restaurant.country),
      CuisineDetails(restaurant: restaurant),
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
  const _RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onSaved,
    required this.onDeleted,
  });
  final Restaurant restaurant;
  final ValueChanged<Restaurant> onSaved;
  final ValueChanged<int> onDeleted;

  @override
  Widget build(BuildContext context) => isMobilePlatform
      ? Container(
          key: ValueKey('restaurant-card-${restaurant.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RestaurantName(
                restaurant,
                onSaved: onSaved,
                onDeleted: onDeleted,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _RestaurantCity(restaurant)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      'Country: ${restaurant.country ?? 'Not listed'}',
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'Cuisine: ',
                    style: TextStyle(fontSize: 13, height: 1.3),
                  ),
                  Expanded(child: CuisineDetails(restaurant: restaurant)),
                ],
              ),
            ],
          ),
        )
      : Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RestaurantName(
                restaurant,
                onSaved: onSaved,
                onDeleted: onDeleted,
              ),
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
              _Detail(
                'Cuisine',
                restaurant.cuisine,
                child: CuisineDetails(restaurant: restaurant),
              ),
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

class _Value extends StatelessWidget {
  const _Value(this.value);
  final String? value;

  @override
  Widget build(BuildContext context) => SelectableText(
    value ?? 'Not listed',
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: value == null
          ? Theme.of(context).colorScheme.onSurfaceVariant
          : Theme.of(context).colorScheme.onSurface,
    ),
  );
}
