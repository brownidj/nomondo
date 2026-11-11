import 'package:beneede_app/models/restaurant.dart';
import 'package:beneede_app/models/restaurant_sort.dart';
import 'package:beneede_app/services/restaurant_website.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final field in [
    RestaurantSortField.name,
    RestaurantSortField.city,
    RestaurantSortField.country,
    RestaurantSortField.cuisine,
  ]) {
    test('${field.label} sorts case-insensitively in both directions', () {
      const rows = [
        Restaurant(
          id: 1,
          name: 'Zulu',
          city: 'Zurich',
          country: 'Switzerland',
          cuisine: 'Swiss',
        ),
        Restaurant(
          id: 2,
          name: 'alpha',
          city: 'athens',
          country: 'Greece',
          cuisine: 'Greek',
        ),
      ];
      final sorted = [...rows]
        ..sort((a, b) => field.compare(a, b, ascending: true));
      expect(sorted.map((row) => row.id), [2, 1]);
      sorted.sort((a, b) => field.compare(a, b, ascending: false));
      expect(sorted.map((row) => row.id), [1, 2]);
    });
  }
  test('missing values stay last and ties have a stable record order', () {
    const rows = [
      Restaurant(id: 3, name: 'Same', city: null),
      Restaurant(id: 2, name: 'Same', city: 'London'),
      Restaurant(id: 1, name: 'Same', city: 'London'),
    ];
    for (final ascending in [true, false]) {
      final sorted = [...rows]
        ..sort(
          (a, b) =>
              RestaurantSortField.city.compare(a, b, ascending: ascending),
        );
      expect(sorted.map((row) => row.id), [1, 2, 3]);
    }
  });
  test(
    'unknown review confidence stays distinct from an actual zero percent',
    () {
      const rows = [
        Restaurant(id: 1, name: 'Unknown'),
        Restaurant(id: 2, name: 'Zero', confidence: 0),
        Restaurant(id: 3, name: 'High', confidence: .9),
      ];
      final sorted = [...rows]
        ..sort(
          (a, b) =>
              RestaurantSortField.confidence.compare(a, b, ascending: true),
        );
      expect(sorted.map((row) => row.id), [1, 2, 3]);
      sorted.sort(
        (a, b) =>
            RestaurantSortField.confidence.compare(a, b, ascending: false),
      );
      expect(sorted.map((row) => row.id), [1, 3, 2]);
    },
  );
  test('website links default to HTTPS and refuse absent/unsafe inputs', () {
    expect(
      websiteUri(' example.com/menu ')?.toString(),
      'https://example.com/menu',
    );
    for (final input in [
      '',
      'Not listed',
      'javascript://alert',
      'file:///tmp/restaurant',
      'https://user:password@example.com',
    ]) {
      expect(websiteUri(input), isNull, reason: input);
    }
  });
}
