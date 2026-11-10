import 'dart:convert';

import 'package:beneede_app/data/restaurant_repository.dart';
import 'package:beneede_app/widgets/edit_restaurant_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// City completion is independent of the add/research request under test.
http.Client addClient(Future<http.Response> Function(http.Request) handle) =>
    MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/cities') {
        return http.Response('{"cities": []}', 200);
      }
      return handle(request);
    });

Map<String, dynamic> saved(int id, String address) => {
  'id': id,
  'restaurant_name': 'Example',
  'city': 'London',
  'address': address,
  'needs_review': 1,
  'revision': 'saved-$id',
};

Future<void> openAdd(
  WidgetTester tester,
  RestaurantRepository repository, {
  void Function(RestaurantAddResult?)? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await addRestaurant(
                context,
                repository: repository,
              );
              onResult?.call(result);
            },
            child: const Text('Open add'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open add'));
  await tester.pumpAndSettle();
}

Future<void> enterIdentity(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Example');
  await tester.enterText(find.byType(TextFormField).at(1), 'London');
}

void main() {
  testWidgets(
    'clearing a failed website lookup retries by name and city with other details',
    (tester) async {
      final modes = <String>[];
      final repository = RestaurantRepository(
        client: addClient((request) async {
          expect(request.url.path, '/api/restaurant-lookups');
          final body = jsonDecode(request.body);
          modes.add(body['mode'] as String);
          if (modes.length == 1) {
            return http.Response(
              jsonEncode({
                'status': 'failed',
                'message': 'Website could not be read',
              }),
              202,
            );
          }
          expect(body['fields'].containsKey('internet_link'), isFalse);
          expect(body['fields']['restaurant_name'], 'Example');
          expect(body['fields']['city'], 'London');
          expect(body['fields']['country'], 'UK');
          return http.Response(
            jsonEncode({
              'lookup_id': body['request_id'],
              'status': 'ready',
              'issues': [],
              'venues': [
                {
                  'fields': {
                    'restaurant_name': 'Example',
                    'city': 'London',
                    'country': 'UK',
                    'address': '1 Main Road',
                    'internet_link': 'https://official.example',
                  },
                  'issues': [],
                },
              ],
            }),
            202,
          );
        }),
      );
      await openAdd(tester, repository);
      await enterIdentity(tester);
      await tester.enterText(find.byType(TextFormField).at(2), 'UK');
      await tester.enterText(
        find.byType(TextFormField).at(5),
        'https://unreadable.example',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add restaurant'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(5), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Add restaurant'));
      await tester.pumpAndSettle();
      expect(modes, ['website', 'web']);
      expect(find.text('https://official.example'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },

    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets('website alone can look up the name and city', (tester) async {
    var lookups = 0;
    final repository = RestaurantRepository(
      client: addClient((request) async {
        lookups++;
        expect(request.url.path, '/api/restaurant-lookups');
        final body = jsonDecode(request.body);
        expect(body['mode'], 'website');
        return http.Response(
          jsonEncode({
            'lookup_id': body['request_id'],
            'status': 'ready',
            'issues': [],
            'venues': [
              {
                'fields': {
                  'restaurant_name': 'Example',
                  'city': 'London',
                  'address': '1 Main Road',
                  'internet_link': 'https://example.com',
                },
                'issues': [],
              },
            ],
          }),
          202,
        );
      }),
    );
    await openAdd(tester, repository);
    await tester.enterText(
      find.byType(TextFormField).at(5),
      'https://example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add restaurant'));
    await tester.pumpAndSettle();
    expect(lookups, 1);
    expect(find.text('Name is required'), findsNothing);
    expect(find.text('City is required'), findsNothing);
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('London'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('name and city required when no website is supplied', (
    tester,
  ) async {
    var requests = 0;
    final repository = RestaurantRepository(
      client: addClient((_) async {
        requests++;
        return http.Response('{}', 500);
      }),
    );
    await openAdd(tester, repository);
    await tester.tap(find.widgetWithText(FilledButton, 'Add restaurant'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('City is required'), findsOneWidget);
    expect(requests, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('declining automatic data adds manually without lookup', (
    tester,
  ) async {
    final paths = <String>[];
    RestaurantAddResult? result;
    final repository = RestaurantRepository(
      client: addClient((request) async {
        paths.add(request.url.path);
        final body = jsonDecode(request.body);
        expect(body['lookup_id'], isNull);
        expect(body['records'][0]['restaurant_name'], 'Example');
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
    await enterIdentity(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add restaurant'));
    await tester.pumpAndSettle();
    expect(find.text('Add details automatically?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(paths, ['/api/restaurants']);
    expect(result?.addedCount, 1);
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('website lookup previews and saves every discovered branch', (
    tester,
  ) async {
    final paths = <String>[];
    final repository = RestaurantRepository(
      client: addClient((request) async {
        paths.add(request.url.path);
        final body = jsonDecode(request.body);
        if (request.url.path == '/api/restaurant-lookups') {
          expect(body['mode'], 'website');
          return http.Response(
            jsonEncode({
              'lookup_id': body['request_id'],
              'status': 'ready',
              'issues': [],
              'venues': [
                for (final address in ['1 Main Road', '20 Main Road'])
                  {
                    'fields': {
                      'restaurant_name': 'Example',
                      'city': 'London',
                      'address': address,
                    },
                    'issues': [],
                  },
              ],
            }),
            202,
          );
        }
        expect((body['records'] as List).length, 2);
        expect(body['lookup_id'], isNotNull);
        return http.Response(
          jsonEncode({
            'restaurants': [saved(1, '1 Main Road'), saved(2, '20 Main Road')],
            'added_count': 2,
            'existing_count': 0,
          }),
          200,
        );
      }),
    );
    await openAdd(tester, repository);
    await enterIdentity(tester);
    await tester.enterText(
      find.byType(TextFormField).at(5),
      'https://example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add restaurant'));
    await tester.pumpAndSettle();
    expect(paths, ['/api/restaurant-lookups']);
    expect(find.text('All 2 venues'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add 2 venues'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add 2 venues'));
    await tester.pumpAndSettle();
    expect(paths, ['/api/restaurant-lookups', '/api/restaurants']);
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('failed automatic lookup retains typed data and saves nothing', (
    tester,
  ) async {
    var creates = 0;
    final repository = RestaurantRepository(
      client: addClient((request) async {
        if (request.url.path == '/api/restaurants') creates++;
        return http.Response(
          jsonEncode({
            'status': 'failed',
            'message': 'Set OPENAI_API_KEY or add manually.',
          }),
          202,
        );
      }),
    );
    await openAdd(tester, repository);
    await enterIdentity(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add restaurant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Set OPENAI_API_KEY or add manually.'), findsOneWidget);
    expect(find.text('Example'), findsOneWidget);
    expect(creates, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));
}
