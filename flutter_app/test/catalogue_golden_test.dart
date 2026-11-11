import 'package:beneede_app/data/restaurant_repository.dart';
import 'package:beneede_app/main.dart';
import 'package:beneede_app/screens/restaurant_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/catalogue_fixture.dart';

void main() {
  for (final config in [
    ('phone', const Size(390, 844), 1.0, TargetPlatform.iOS),
    ('small_phone', const Size(320, 780), 1.0, TargetPlatform.iOS),
    ('large_text', const Size(390, 1000), 1.6, TargetPlatform.iOS),
    ('desktop', const Size(1280, 900), 1.0, TargetPlatform.macOS),
  ]) {
    testWidgets('catalogue visual baseline ${config.$1}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = config.$2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await loadCatalogueFonts();
      final repository = RestaurantRepository(
        client: CatalogueFixture().client(),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('catalogue-golden'),
          child: BeneEdeApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(config.$3)),
                child: RestaurantListPage(repository: repository),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/beneede-icon.png'),
          tester.element(find.byType(MaterialApp)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Could not load your restaurants.'), findsNothing);
      await expectLater(
        find.byKey(const ValueKey('catalogue-golden')),
        matchesGoldenFile('goldens/catalogue_${config.$1}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant({config.$4}));
  }
}
