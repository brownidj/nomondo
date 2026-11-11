import 'dart:convert';

import 'package:beneede_app/data/restaurant_repository.dart';
import 'package:beneede_app/main.dart';
import 'package:beneede_app/screens/restaurant_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/catalogue_fixture.dart';

void main() {
  testWidgets(
    'mobile records keep actions beside the name and locations together',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = RestaurantRepository(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'restaurants': [
                {
                  'id': 1,
                  'restaurant_name': 'Bistro',
                  'city': 'London',
                  'country': 'United Kingdom',
                  'cuisine': 'French',
                  'telephone': '+44 20 1234 5678',
                  'internet_link': 'https://example.com',
                  'needs_review': 1,
                  'confidence': 0.8,
                },
              ],
            }),
            200,
          ),
        ),
      );
      await loadCatalogueFonts();
      await tester.pumpWidget(
        BeneEdeApp(home: RestaurantListPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      final name = tester.getRect(
        find.byKey(const ValueKey('restaurant-name-1')),
      );
      final phone = tester.getRect(find.byIcon(Icons.phone_outlined));
      final website = tester.getRect(find.byIcon(Icons.language));
      final edit = tester.getRect(find.byIcon(Icons.edit_outlined));
      expect(phone.left, greaterThan(name.right));
      expect(website.left, greaterThan(phone.right));
      expect(edit.left, greaterThan(website.right));
      expect(phone.center.dy, inInclusiveRange(name.top, name.bottom));
      final city = tester.getRect(find.text('City: London'));
      final country = tester.getRect(find.text('Country: United Kingdom'));
      expect((city.top - country.top).abs(), lessThan(2));
      expect(country.left, greaterThan(city.right));
      expect(
        tester.getSize(find.byKey(const ValueKey('restaurant-card-1'))).height,
        lessThan(110),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'mobile pairs location filters and keeps Add beside sorting',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadCatalogueFonts();
      await tester.pumpWidget(
        BeneEdeApp(
          home: RestaurantListPage(
            repository: RestaurantRepository(
              client: CatalogueFixture().client(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        (tester.getCenter(find.text('All countries')).dy -
                tester.getCenter(find.text('All cities')).dy)
            .abs(),
        lessThan(2),
      );
      final add = find.byTooltip('Add restaurant');
      final sort = find.text('Restaurant name');
      expect(
        (tester.getCenter(add).dy - tester.getCenter(sort).dy).abs(),
        lessThan(16),
      );
      expect(tester.getCenter(add).dx, greaterThan(tester.getCenter(sort).dx));
      expect(find.textContaining('Needs review only'), findsNothing);
      expect(find.text('Archived'), findsNothing);
      expect(tester.widget<Text>(find.text('+')).style!.color, Colors.white);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
