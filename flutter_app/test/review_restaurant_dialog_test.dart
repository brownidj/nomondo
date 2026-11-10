import 'dart:convert';

import 'package:beneede_app/data/restaurant_repository.dart';
import 'package:beneede_app/models/restaurant.dart';
import 'package:beneede_app/widgets/edit_restaurant_dialog.dart';
import 'package:beneede_app/widgets/review_restaurant_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> record({String status = 'pending'}) => {
  'id': 1,
  'restaurant_name': 'Example',
  'city': 'London',
  'country': 'United Kingdom',
  'needs_review': status == 'pending' ? 1 : 0,
  'revision': 'revision-$status',
  'review_status': status,
  'archived_at': status == 'failed' ? '2026-11-10T12:00:00Z' : null,
};

Map<String, dynamic> details() => {
  'restaurant': record(),
  'review_reasons': ['Missing address'],
  'evidence': [
    {
      'field': 'city',
      'url': 'https://example.com',
      'detail': 'Listed on the official site',
    },
  ],
  'sources': [],
  'history': [],
  'alternatives': [],
  'duplicate_ids': [],
};

Future<void> openReview(
  WidgetTester tester,
  RestaurantRepository repository, {
  ValueChanged<RestaurantEditResult?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await reviewRestaurant(
                context,
                Restaurant.fromJson(record()),
                repository: repository,
              );
              onResult?.call(result);
            },
            child: const Text('Review'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Review'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Edit details opens Save/Cancel editor and Cancel preserves the review',
    (tester) async {
      var writes = 0;
      final repository = RestaurantRepository(
        client: MockClient((request) async {
          if (request.method != 'GET') writes++;
          return http.Response(jsonEncode(details()), 200);
        }),
      );
      await openReview(tester, repository, onResult: (_) {});
      await tester.ensureVisible(find.text('Edit details'));
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();
      expect(find.text('Edit restaurant'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Unsaved restaurant',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit restaurant'), findsNothing);
      expect(find.text('Unsaved restaurant'), findsNothing);
      expect(find.text('Review — Example'), findsOneWidget);
      expect(writes, 0);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('review shows flags and passing returns an updated restaurant', (
    tester,
  ) async {
    RestaurantEditResult? result;
    final repository = RestaurantRepository(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(details()), 200);
        }
        expect(jsonDecode(request.body)['decision'], 'passed');
        return http.Response(
          jsonEncode({'restaurant': record(status: 'passed')}),
          200,
        );
      }),
    );
    await openReview(tester, repository, onResult: (value) => result = value);
    expect(find.text('• Missing address'), findsOneWidget);
    await tester.tap(find.text('Pass'));
    await tester.pumpAndSettle();
    expect(result!.restaurant!.reviewStatus, 'passed');
    expect(result!.restaurant!.needsReview, isFalse);
  });

  testWidgets('failure needs a reason and confirmation before archival', (
    tester,
  ) async {
    var writes = 0;
    RestaurantEditResult? result;
    final repository = RestaurantRepository(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(details()), 200);
        }
        writes++;
        final body = jsonDecode(request.body);
        expect(body['decision'], 'failed');
        expect(body['note'], 'Wrong venue');
        return http.Response(
          jsonEncode({'restaurant': record(status: 'failed')}),
          200,
        );
      }),
    );
    await openReview(tester, repository, onResult: (value) => result = value);
    await tester.tap(find.text('Fail & archive'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.textContaining('Enter the reason'), findsOneWidget);
    final messageBottom = tester
        .getBottomLeft(find.textContaining('Enter the reason'))
        .dy;
    final noteTop = tester.getTopLeft(find.byType(TextField)).dy;
    expect(noteTop, greaterThanOrEqualTo(messageBottom));
    expect(noteTop - messageBottom, lessThan(24));
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Wrong venue');
    await tester.tap(find.text('Fail & archive'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('Fail & archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(result!.restaurant!.isArchived, isTrue);
  });

  testWidgets('stale review stays open and retains the note', (tester) async {
    final repository = RestaurantRepository(
      client: MockClient(
        (request) async => request.method == 'GET'
            ? http.Response(jsonEncode(details()), 200)
            : http.Response(
                jsonEncode({
                  'error': 'This restaurant changed. Reload its review before deciding.',
                }),
                409,
              ),
      ),
    );
    await openReview(tester, repository, onResult: (_) {});
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Checked official address');
    await tester.tap(find.text('Pass'));
    await tester.pumpAndSettle();
    expect(find.textContaining('This restaurant changed.'), findsOneWidget);
    expect(find.text('Checked official address'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });
}
