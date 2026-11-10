import 'dart:convert';

import 'package:beneede_app/data/restaurant_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'add_restaurant_dialog_test.dart' show openAdd, enterIdentity, saved;

void main() {
  for (final websiteOnly in [false, true]) {
    testWidgets(
      'mobile adds manually without discovery, websiteOnly=$websiteOnly',
      (tester) async {
        final paths = <String>[];
        RestaurantAddResult? result;
        final repository = RestaurantRepository(
          client: MockClient((request) async {
            if (request.url.path == '/api/cities') {
              return http.Response('{"cities":[]}', 200);
            }
            paths.add(request.url.path);
            expect(request.method, 'POST');
            expect(request.url.path, '/api/restaurants');
            final body = jsonDecode(request.body);
            expect(body['lookup_id'], isNull);
            if (websiteOnly) {
              expect(
                body['records'][0]['internet_link'],
                'https://example.com',
              );
            }
            return http.Response(
              jsonEncode({
                'restaurants': [saved(1, '')],
                'added_count': 1,
                'existing_count': 0,
              }),
              200,
            );
          }),
        );
        await openAdd(tester, repository, onResult: (value) => result = value);
        if (websiteOnly) {
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Website'),
            'https://example.com',
          );
        } else {
          await enterIdentity(tester);
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Add restaurant'));
        await tester.pumpAndSettle();
        expect(find.text('Add details automatically?'), findsNothing);
        expect(paths, ['/api/restaurants']);
        expect(result!.addedCount, 1);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }

  testWidgets(
    'mobile repository rejects direct discovery before HTTP',
    (tester) async {
      var requests = 0;
      final repository = RestaurantRepository(
        client: MockClient((request) async {
          requests++;
          return http.Response('{}', 500);
        }),
      );
      addTearDown(repository.close);
      await expectLater(
        repository.lookup(
          {'restaurant_name': 'Example', 'city': 'London'},
          'web',
          onProgress: (_) {},
        ),
        throwsA(isA<FormatException>()),
      );
      expect(requests, 0);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
