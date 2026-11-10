import 'package:beneede_app/models/restaurant.dart';
import 'package:beneede_app/widgets/edit_restaurant_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const restaurant = Restaurant(
    id: 1,
    name: 'Original restaurant',
    city: 'London',
    notes: 'Full original note',
    revision: 'original',
  );

  for (final size in [const Size(1200, 900), const Size(390, 844)]) {
    testWidgets(
      'delete asks for confirmation and cancelling keeps the editor at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => editRestaurant(context, restaurant),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        final deletePosition = tester.getCenter(find.text('Delete'));
        final cancelPosition = tester.getCenter(find.text('Cancel'));
        expect(deletePosition.dx, lessThan(cancelPosition.dx));
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Delete restaurant?'), findsOneWidget);
        expect(find.textContaining('Original restaurant'), findsWidgets);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(find.text('Delete restaurant?'), findsNothing);
        expect(find.text('Edit restaurant'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('editor lays out and expands more details at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => editRestaurant(context, restaurant),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Edit restaurant'), findsOneWidget);
      await tester.ensureVisible(find.text('More details'));
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Region'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancel closes the modal without a saved record', (tester) async {
    RestaurantEditResult? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await editRestaurant(context, restaurant);
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit restaurant'), findsOneWidget);
    expect(find.text('Full original note'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit restaurant'), findsNothing);
    expect(saved, isNull);
  });

  testWidgets('blank restaurant name is rejected before saving', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => editRestaurant(context, restaurant),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Edit restaurant'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
