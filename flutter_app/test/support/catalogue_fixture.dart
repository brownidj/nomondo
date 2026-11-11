import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// No real catalogue, pairing token or paid discovery is used by these fixtures.
class CatalogueFixture {
  CatalogueFixture({List<Map<String, dynamic>>? initial})
    : records = {
        for (final row in initial ?? sampleRecords) row['id'] as int: {...row},
      };
  final Map<int, Map<String, dynamic>> records;
  final Map<String, int> receipts = {};
  final List<String> requests = [];
  bool reachable = true;
  bool loseNextWriteResponse = false;
  int _revision = 10;

  static List<Map<String, dynamic>> get sampleRecords => [
    {
      'id': 1,
      'restaurant_name': 'Bistro',
      'revision': 'r1',
      'city': 'London',
      'country': 'United Kingdom',
      'cuisine': 'French',
      'telephone': '+44 20 1234 5678',
      'internet_link': 'https://example.com',
      'address': '1 Test Street, London',
      'special_dish': 'Onion soup',
      'notes': 'Fixture notes',
      'needs_review': 1,
      'confidence': .8,
      'review_status': 'pending',
    },
    {
      'id': 2,
      'restaurant_name': 'A very long restaurant name with several words',
      'revision': 'r2',
      'city': 'San Sebastián',
      'country': 'Spain',
      'cuisine': 'Basque seasonal tasting menu',
      'needs_review': 0,
      'review_status': 'passed',
    },
    {
      'id': 3,
      'restaurant_name': 'Tokyo Table',
      'revision': 'r3',
      'city': 'Tokyo',
      'country': 'Japan',
      'cuisine': 'Japanese',
      'needs_review': 1,
      'review_status': 'pending',
      'confidence': .65,
    },
    {
      'id': 4,
      'restaurant_name': 'No contact details',
      'revision': 'r4',
      'city': null,
      'country': null,
      'cuisine': null,
      'needs_review': 1,
      'review_status': 'pending',
    },
  ];

  Map<String, dynamic> review(Map<String, dynamic> row) => {
    'restaurant': row,
    'review_reasons': ['Check the address against the saved source'],
    'evidence': [
      {'field': 'address', 'detail': 'Fixture source evidence'},
    ],
    'sources': [
      {
        'source_file': 'fixture.txt',
        'line_number': 1,
        'raw_text': 'Original fixture entry',
      },
    ],
    'history': [],
    'alternatives': [],
    'duplicate_ids': [],
    'confidence': row['confidence'],
  };

  http.Client client() => MockClient(handle);

  http.Response _json(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<http.Response> handle(http.Request request) async {
    requests.add('${request.method} ${request.url.path}');
    if (!reachable) throw http.ClientException('Deliberately offline');
    final path = request.url.path;
    if (request.method == 'GET') {
      if (path == '/api/cities') return _json({'cities': []});
      if (path == '/api/offline-catalogue') {
        final rows = records.values.toList();
        final version = _revision.toString();
        if (request.url.queryParameters['version'] == version) {
          return _json({'version': version, 'unchanged': true});
        }
        return _json({
          'version': version,
          'restaurants': rows,
          'reviews': {
            for (final row in rows) row['id'].toString(): review(row),
          },
        });
      }
      if (path.endsWith('/review')) {
        return _json(review(records[int.parse(path.split('/')[3])]!));
      }
      return _json({'restaurants': records.values.toList()});
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    late http.Response response;
    if (path == '/api/restaurants') {
      final requestId = body['request_id'] as String;
      final existing = receipts[requestId];
      final id =
          existing ?? (records.keys.fold(0, (a, b) => a > b ? a : b) + 1);
      if (existing == null) {
        records[id] = {
          ...Map<String, dynamic>.from((body['records'] as List).single as Map),
          'id': id,
          'revision': 'r${++_revision}',
          'needs_review': 1,
          'review_status': 'pending',
        };
        receipts[requestId] = id;
      }
      response = _json({
        'restaurants': [records[id]],
        'added_count': existing == null ? 1 : 0,
        'existing_count': existing == null ? 0 : 1,
      });
    } else {
      final id = int.parse(path.split('/')[3]);
      final row = records[id];
      if (row == null) {
        return _json({'error': 'Deleted on the other client.'}, 404);
      }
      if (body['revision'] != row['revision']) {
        return _json({'error': 'Changed on the other client.'}, 409);
      }
      if (request.method == 'DELETE') {
        records.remove(id);
        _revision++;
        response = _json({'deleted_id': id});
      } else {
        final updated = {...row, 'revision': 'r${++_revision}'};
        if (request.method == 'PATCH') {
          updated.addAll(Map<String, dynamic>.from(body['changes'] as Map));
          updated['review_status'] = 'pending';
          updated['needs_review'] = 1;
        } else {
          final decision = body['decision'] == 'restore'
              ? 'pending'
              : body['decision'];
          updated.addAll({
            'review_status': decision,
            'needs_review': decision == 'pending' ? 1 : 0,
            'review_note': body['note'],
            'archived_at': decision == 'failed' ? '2026-11-11T00:00:00Z' : null,
          });
        }
        records[id] = updated;
        response = _json({'restaurant': updated});
      }
    }
    if (loseNextWriteResponse) {
      loseNextWriteResponse = false;
      throw http.ClientException('Saved on server, response deliberately lost');
    }
    return response;
  }

  void macEdit(int id, Map<String, dynamic> changes) {
    records[id] = {...records[id]!, ...changes, 'revision': 'r${++_revision}'};
  }
}

Future<void> loadCatalogueFonts() async {
  final loader = FontLoader('NotoSans')
    ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSans-SemiBold.ttf'));
  await loader.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
