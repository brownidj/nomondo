import 'package:beneede_app/models/restaurant.dart';
import 'package:beneede_app/widgets/cuisine_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'short cuisine opens full cuisine, special dishes and notes together',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CuisineDetails(
              restaurant: Restaurant(
                id: 1,
                name: 'Example',
                cuisine: 'South Indian',
                specialDish: 'Masala dosa',
                notes: 'Try the breakfast menu',
              ),
            ),
          ),
        ),
      );
      expect(find.text('🍽️'), findsNothing);
      expect(find.text('📝'), findsNothing);
      expect(
        find.byTooltip('Click to see cuisine, special dishes and notes'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'South Indian'));
      await tester.pumpAndSettle();
      expect(find.text('Cuisine — Example'), findsOneWidget);
      expect(find.text('🍽️'), findsOneWidget);
      expect(find.text('📝'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SelectableText && widget.data == 'Masala dosa',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.data == 'Try the breakfast menu',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Cuisine — Example'), findsNothing);
    },
  );

  testWidgets(
    'missing cuisine still opens notes without an empty dish section',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CuisineDetails(
              restaurant: Restaurant(
                id: 1,
                name: 'Example',
                specialDish: ' Not listed ',
                notes: 'Keep this note',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Not listed'));
      await tester.pumpAndSettle();
      expect(find.text('Special dishes'), findsNothing);
      expect(find.text('🍽️'), findsNothing);
      expect(find.text('Notes'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText && widget.data == 'Keep this note',
        ),
        findsOneWidget,
      );
    },
  );
}
