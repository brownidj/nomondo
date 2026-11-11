import 'dart:convert';

import 'package:beneede_app/data/mobile_catalogue.dart';
import 'package:beneede_app/data/mobile_catalogue_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> clone(Map value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class MemoryStore implements CatalogueStore {
  Map<String, dynamic>? state;
  bool failWrites = false;
  @override
  Future<Map<String, dynamic>?> read() async =>
      state == null ? null : clone(state!);
  @override
  Future<void> write(Map<String, dynamic> value) async {
    if (failWrites) {
      throw StateError('disk full');
    }
    state = clone(value);
  }
}

Map<String, dynamic> row(int id, String revision) => {
  'id': id,
  'revision': revision,
  'restaurant_name': 'Bistro',
  'city': 'London',
  'country': 'United Kingdom',
  'cuisine': 'French',
  'needs_review': 1,
  'review_status': 'pending',
};

http.Response reply(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);
http.Response snapshot(List<Map<String, dynamic>> rows) => reply({
  'restaurants': rows,
  'version': jsonEncode(rows),
  'reviews': {
    for (final row in rows)
      row['id'].toString(): {
        'restaurant': row,
        'review_reasons': ['Check address'],
        'evidence': [
          {'field': 'address', 'detail': 'Saved source evidence'},
        ],
        'sources': [],
        'history': [],
        'alternatives': [],
        'duplicate_ids': [],
      },
  },
});

void main() {
  test('clean catalogues do not poll; edits set and successful sync clears the flag', () async {
    final store = MemoryStore();
    var current = row(1, 'r1');
    var requests = 0;
    MobileCatalogue create() => MobileCatalogue(
      baseUrl: 'http://mac:8766',
      store: store,
      remote: MockClient((request) async {
        requests++;
        if (request.method == 'PATCH') {
          final body = jsonDecode(request.body);
          current = {...current, ...body['changes'], 'revision': 'r2'};
          return reply({'restaurant': current});
        }
        return snapshot([current]);
      }),
    );
    final catalogue = create();
    await catalogue.catalogue();
    expect(catalogue.hasChanges, false);
    await catalogue.synchronizeIfChanged();
    await catalogue.synchronizeIfChanged();
    expect(requests, 1);
    await catalogue.mutate('PATCH', 1, {
      'revision': 'r1',
      'changes': {'notes': 'Changed'},
    });
    expect(catalogue.hasChanges, true);
    expect(store.state!['has_changes'], true);
    await catalogue.synchronizeIfChanged();
    expect(
      requests,
      3,
    ); // Upload plus snapshot; subsequent idle checks are local.
    expect(catalogue.hasChanges, false);
    expect(store.state!['has_changes'], false);
    await catalogue.synchronizeIfChanged();
    expect(requests, 3);
    catalogue.dispose();
    final reopened = create();
    await reopened.catalogue();
    await reopened.synchronizeIfChanged();
    expect(requests, 3);
    await reopened
        .syncAll(); // Refresh still checks for changes made on the Mac.
    expect(requests, 4);
    reopened.dispose();
  });

  test(
    'dirty flag survives an acknowledged upload followed by a failed download',
    () async {
      final store = MemoryStore();
      var current = row(1, 'r1');
      var failDownload = false;
      final catalogue = MobileCatalogue(
        baseUrl: 'http://mac:8766',
        store: store,
        remote: MockClient((request) async {
          if (request.method == 'PATCH') {
            current = {...current, 'revision': 'r2', 'notes': 'Changed'};
            failDownload = true;
            return reply({'restaurant': current});
          }
          if (failDownload) {
            throw http.ClientException('offline');
          }
          return snapshot([current]);
        }),
      );
      await catalogue.catalogue();
      await catalogue.mutate('PATCH', 1, {
        'revision': 'r1',
        'changes': {'notes': 'Changed'},
      });
      await catalogue.synchronizeIfChanged();
      expect(catalogue.pendingCount, 0);
      expect(catalogue.hasChanges, true);
      expect(store.state!['needs_download'], true);
      failDownload = false;
      await catalogue.synchronizeIfChanged();
      expect(catalogue.hasChanges, false);
      expect(store.state!['needs_download'], false);
      catalogue.dispose();
    },
  );

  test(
    'download, restart offline, edit and review evidence remain available',
    () async {
      final store = MemoryStore();
      var reachable = true;
      MobileCatalogue create() => MobileCatalogue(
        baseUrl: 'http://mac:8766',
        store: store,
        remote: MockClient((request) async {
          if (!reachable) {
            throw http.ClientException('offline');
          }
          return snapshot([row(1, 'r1')]);
        }),
      );
      final first = create();
      await first.catalogue();
      await first.mutate('PATCH', 1, {
        'revision': 'r1',
        'changes': {'cuisine': 'Italian'},
      });
      first.dispose();
      reachable = false;
      final reopened = create();
      final data = jsonDecode((await reopened.catalogue()).body);
      expect(data['restaurants'].single['cuisine'], 'Italian');
      expect(reopened.pendingCount, 1);
      final details = jsonDecode((await reopened.review(1)).body);
      expect(details['evidence'].single['detail'], 'Saved source evidence');
      await reopened.synchronize();
      expect(reopened.pendingCount, 1);
      expect(reopened.online, false);
      reopened.dispose();
    },
  );

  test('temporary ID and dependent revisions are remapped through add/edit/review/delete', () async {
    final store = MemoryStore();
    final server = <int, Map<String, dynamic>>{};
    final paths = <String>[];
    final catalogue = MobileCatalogue(
      baseUrl: 'http://mac:8766',
      store: store,
      remote: MockClient((request) async {
        if (request.method == 'GET') {
          return snapshot(server.values.toList());
        }
        paths.add('${request.method} ${request.url.path}');
        final body = jsonDecode(request.body);
        if (request.method == 'POST' &&
            request.url.path == '/api/restaurants') {
          server[10] = {...row(10, 'r1'), ...body['records'].single};
          return reply({
            'restaurants': [server[10]],
            'added_count': 1,
            'existing_count': 0,
          });
        }
        if (request.method == 'PATCH') {
          expect(body['revision'], 'r1');
          server[10] = {...server[10]!, ...body['changes'], 'revision': 'r2'};
          return reply({'restaurant': server[10]});
        }
        if (request.url.path.endsWith('/review')) {
          expect(body['revision'], 'r2');
          server[10] = {
            ...server[10]!,
            'review_status': 'passed',
            'needs_review': 0,
            'revision': 'r3',
          };
          return reply({'restaurant': server[10]});
        }
        expect(body['revision'], 'r3');
        server.remove(10);
        return reply({'deleted_id': 10});
      }),
    );
    await catalogue.catalogue();
    final added = jsonDecode(
      (await catalogue.mutate('ADD', null, {
        'request_id': 'stable_add_request',
        'lookup_id': null,
        'records': [
          {'restaurant_name': 'New place', 'city': 'London'},
        ],
      })).body,
    )['restaurants'].single;
    final id = added['id'] as int;
    expect(id, isNegative);
    final edited = jsonDecode(
      (await catalogue.mutate('PATCH', id, {
        'revision': added['revision'],
        'changes': {'cuisine': 'Italian'},
      })).body,
    )['restaurant'];
    final reviewed = jsonDecode(
      (await catalogue.mutate('REVIEW', id, {
        'revision': edited['revision'],
        'decision': 'passed',
        'note': 'Checked',
      })).body,
    )['restaurant'];
    await catalogue.mutate('DELETE', id, {
      'revision': reviewed['revision'],
      'confirmed': true,
    });
    for (var i = 0; i < 4; i++) {
      await catalogue.synchronize();
    }
    expect(catalogue.pendingCount, 0);
    expect(paths, [
      'POST /api/restaurants',
      'PATCH /api/restaurants/10',
      'POST /api/restaurants/10/review',
      'DELETE /api/restaurants/10',
    ]);
    expect(
      jsonDecode((await catalogue.catalogue()).body)['restaurants'],
      isEmpty,
    );
    catalogue.dispose();
  });

  test(
    'Mac edits cause a visible conflict; choosing Mac archives local changes',
    () async {
      var current = row(1, 'r1');
      var writes = 0;
      final store = MemoryStore();
      final catalogue = MobileCatalogue(
        baseUrl: 'http://mac:8766',
        store: store,
        remote: MockClient((request) async {
          if (request.method == 'GET') {
            return snapshot([current]);
          }
          writes++;
          return reply({'error': 'This record changed on the Mac.'}, 409);
        }),
      );
      await catalogue.catalogue();
      await catalogue.mutate('PATCH', 1, {
        'revision': 'r1',
        'changes': {'notes': 'Local note'},
      });
      current = {...current, 'revision': 'r2', 'notes': 'Mac note'};
      await catalogue.synchronize();
      expect(catalogue.conflicts, hasLength(1));
      expect(catalogue.localRecord(1)!['notes'], 'Local note');
      expect(catalogue.serverRecord(1)!['notes'], 'Mac note');
      await catalogue.synchronize();
      expect(writes, 1); // Never automatically overwrite a newer Mac revision.
      await catalogue.resolve(
        catalogue.conflicts.single['key'],
        useLocal: false,
      );
      expect(catalogue.pendingCount, 0);
      expect(catalogue.localRecord(1)!['notes'], 'Mac note');
      expect(catalogue.exportLocalHistory(), contains('Local note'));
      catalogue.dispose();
    },
  );

  test(
    'failed durable commit does not acknowledge or expose a local edit',
    () async {
      final store = MemoryStore();
      final catalogue = MobileCatalogue(
        baseUrl: 'http://mac:8766',
        store: store,
        remote: MockClient((_) async => snapshot([row(1, 'r1')])),
      );
      await catalogue.catalogue();
      store.failWrites = true;
      await expectLater(
        catalogue.mutate('PATCH', 1, {
          'revision': 'r1',
          'changes': {'notes': 'Unsaved'},
        }),
        throwsStateError,
      );
      expect(catalogue.pendingCount, 0);
      expect(catalogue.localRecord(1)!['notes'], isNull);
      catalogue.dispose();
    },
  );

  test('stale local modal cannot replace a newer queued edit', () async {
    final catalogue = MobileCatalogue(
      baseUrl: 'http://mac:8766',
      store: MemoryStore(),
      remote: MockClient((_) async => snapshot([row(1, 'r1')])),
    );
    await catalogue.catalogue();
    await catalogue.mutate('PATCH', 1, {
      'revision': 'r1',
      'changes': {'notes': 'First edit'},
    });
    final response = await catalogue.mutate('PATCH', 1, {
      'revision': 'r1',
      'changes': {'notes': 'Stale edit'},
    });
    expect(response.statusCode, 409);
    expect(catalogue.localRecord(1)!['notes'], 'First edit');
    expect(catalogue.pendingCount, 1);
    catalogue.dispose();
  });
}
