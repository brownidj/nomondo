import 'restaurant.dart';

enum RestaurantSortField {
  name('Restaurant name'),
  city('City'),
  country('Country'),
  cuisine('Cuisine'),
  confidence('Review confidence');

  const RestaurantSortField(this.label);

  final String label;

  String? valueOf(Restaurant restaurant) => switch (this) {
    RestaurantSortField.name => restaurant.name,
    RestaurantSortField.city => restaurant.city,
    RestaurantSortField.country => restaurant.country,
    RestaurantSortField.cuisine => restaurant.cuisine,
    RestaurantSortField.confidence => null,
  };

  int compare(Restaurant a, Restaurant b, {required bool ascending}) {
    if (this == confidence) {
      final left = a.confidence;
      final right = b.confidence;
      // Unscored records need attention first; never treat them as a real 0%.
      if ((left == null) != (right == null)) return left == null ? -1 : 1;
      if (left != null && right != null) {
        final primary = ascending
            ? left.compareTo(right)
            : right.compareTo(left);
        if (primary != 0) return primary;
      }
      return name.compare(a, b, ascending: true);
    }
    final left = valueOf(a)?.trim().toLowerCase() ?? '';
    final right = valueOf(b)?.trim().toLowerCase() ?? '';

    // Keep missing values at the bottom in either direction.
    if (left.isEmpty != right.isEmpty) return left.isEmpty ? 1 : -1;
    final primary = ascending ? left.compareTo(right) : right.compareTo(left);
    if (primary != 0) return primary;

    // Equal groups have a predictable order, including duplicate source entries.
    for (final field in values) {
      final tie = (field.valueOf(a)?.trim().toLowerCase() ?? '').compareTo(
        field.valueOf(b)?.trim().toLowerCase() ?? '',
      );
      if (tie != 0) return tie;
    }
    return a.id.compareTo(b.id);
  }
}
