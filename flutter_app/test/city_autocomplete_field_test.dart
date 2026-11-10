import 'dart:async';

import 'package:beneede_app/data/restaurant_repository.dart';
import 'package:beneede_app/widgets/city_autocomplete_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('city choice distinguishes countries and fills a manual form', (
    tester,
  ) async {
    final city = TextEditingController();
    final country = TextEditingController();
    addTearDown(city.dispose);
    addTearDown(country.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CityAutocompleteField(
            controller: city,
            countryController: country,
            search: (query, selectedCountry) async => const [
              CitySuggestion(
                id: 1,
                name: 'London',
                country: 'England, United Kingdom',
                region: 'England',
              ),
              CitySuggestion(
                id: 2,
                name: 'London',
                country: 'Canada',
                region: 'Ontario',
              ),
            ],
            fieldViewBuilder: (context, controller, focus, submit) =>
                TextFormField(
                  controller: controller,
                  focusNode: focus,
                  onFieldSubmitted: (_) => submit(),
                ),
            onSelected: (value) => country.text = value.country,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'Lon');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Ontario · Canada'), findsOneWidget);
    await tester.tap(find.text('Ontario · Canada'));
    await tester.pumpAndSettle();
    expect(city.text, 'London');
    expect(country.text, 'Canada');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late responses cannot replace a newer city query', (
    tester,
  ) async {
    final city = TextEditingController();
    final country = TextEditingController();
    final oldResponse = Completer<List<CitySuggestion>>();
    addTearDown(city.dispose);
    addTearDown(country.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CityAutocompleteField(
            controller: city,
            countryController: country,
            search: (query, _) => query == 'Lon'
                ? oldResponse.future
                : Future.value(const [
                    CitySuggestion(
                      id: 3,
                      name: 'Paris',
                      country: 'France',
                      region: 'Île-de-France',
                    ),
                  ]),
            fieldViewBuilder: (context, controller, focus, submit) =>
                TextFormField(controller: controller, focusNode: focus),
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'Lon');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextFormField), 'Par');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    oldResponse.complete(const [
      CitySuggestion(
        id: 1,
        name: 'London',
        country: 'United Kingdom',
        region: '',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('London'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
