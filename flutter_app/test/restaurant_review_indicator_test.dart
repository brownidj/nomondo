import 'package:beneede_app/models/restaurant.dart';
import 'package:beneede_app/widgets/restaurant_review_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('amber light and confidence both open the same review action', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RestaurantReviewIndicator(
              restaurant: const Restaurant(
                id: 1,
                name: 'Example',
                needsReview: true,
                confidence: .73,
              ),
              onReview: () => opens++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('review-led')));
    await tester.pump();
    await tester.tap(find.text('73%'));
    await tester.pump();
    expect(opens, 2);
  });

  testWidgets(
    'passed light is informational without a review button or percentage',
    (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RestaurantReviewIndicator(
                restaurant: const Restaurant(
                  id: 1,
                  name: 'Example',
                  reviewStatus: 'passed',
                  confidence: 1,
                ),
                onReview: () => opens++,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TextButton), findsNothing);
      expect(find.text('100%'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('review-led')));
      await tester.pump();
      expect(opens, 0);
      expect(find.byTooltip('Passed'), findsOneWidget);
    },
  );
}
