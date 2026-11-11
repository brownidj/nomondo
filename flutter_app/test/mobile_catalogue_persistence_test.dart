import 'dart:convert';
import 'dart:io';

import 'package:beneede_app/data/mobile_catalogue.dart';
import 'package:beneede_app/data/mobile_catalogue_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/catalogue_fixture.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  final stores = <SqliteCatalogueStore>[];
  final catalogues = <MobileCatalogue>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('beneede-sqlite-test-');
    path = '${directory.path}/catalogue.sqlite3';
  });
  tearDown(() async {
    for (final catalogue in catalogues) {
      catalogue.dispose();
    }
    catalogues.clear();
    for (final store in stores) {
      await store.close();
    }
    stores.clear();
    await directory.delete(recursive: true);
  });
  SqliteCatalogueStore store([String scope = 'fixture']) {
    final value = SqliteCatalogueStore(
      scope,
      factory: databaseFactoryFfi,
      path: scope == 'fixture' ? path : '${directory.path}/$scope.sqlite3',
    );
    stores.add(value);
    return value;
  }

  MobileCatalogue catalogue(CatalogueFixture server, CatalogueStore store) {
    final value = MobileCatalogue(
      remote: server.client(),
      baseUrl: 'http://fixture:8766',
      store: store,
    );
    catalogues.add(value);
    return value;
  }

  test(
    'real SQLite reopens offline with queued data and review source evidence',
    () async {
      final server = CatalogueFixture();
      final disk = store();
      final first = catalogue(server, disk);
      await first.catalogue();
      await first.mutate('PATCH', 1, {
        'revision': 'r1',
        'changes': {'notes': 'Saved before restart'},
      });
      await disk.close();
      final reopened = catalogue(server..reachable = false, store());
      final response = jsonDecode((await reopened.catalogue()).body);
      expect(
        (response['restaurants'] as List).singleWhere(
          (row) => row['id'] == 1,
        )['notes'],
        'Saved before restart',
      );
      expect(reopened.hasChanges, true);
      expect(reopened.pendingCount, 1);
      final review = jsonDecode((await reopened.review(1)).body);
      expect(review['sources'].single['raw_text'], 'Original fixture entry');
    },
  );

  test('two persisted clients preserve conflicting edits and can explicitly keep local', () async {
    final server = CatalogueFixture();
    final alice = catalogue(server, store('alice'));
    final bob = catalogue(server, store('bob'));
    await alice.catalogue();
    await bob.catalogue();
    await alice.mutate('PATCH', 1, {
      'revision': 'r1',
      'changes': {'notes': 'Alice note'},
    });
    await bob.mutate('PATCH', 1, {
      'revision': 'r1',
      'changes': {'notes': 'Bob note'},
    });
    await alice.syncAll();
    await bob.syncAll();
    expect(server.records[1]!['notes'], 'Alice note');
    expect(bob.conflicts, hasLength(1));
    expect(bob.localRecord(1)!['notes'], 'Bob note');
    final requestCount = server.requests.length;
    await bob.synchronizeIfChanged();
    expect(
      server.requests.length,
      requestCount,
    ); // Conflict-only queues do not poll.
    await bob.resolve(bob.conflicts.single['key'], useLocal: true);
    await bob.syncAll();
    expect(server.records[1]!['notes'], 'Bob note');
    expect(bob.pendingCount, 0);
    expect(bob.hasChanges, false);
    expect(bob.exportLocalHistory(), contains('Alice note'));
    expect(bob.exportLocalHistory(), contains('Bob note'));
  });

  test('lost add response retries with its original receipt and creates only one venue', () async {
    final server = CatalogueFixture();
    final disk = store();
    final first = catalogue(server, disk);
    await first.catalogue();
    await first.mutate('ADD', null, {
      'request_id': 'lost_response_request',
      'lookup_id': null,
      'records': [
        {'restaurant_name': 'Offline addition', 'city': 'Paris'},
      ],
    });
    server.loseNextWriteResponse = true;
    await first.synchronizeIfChanged();
    expect(first.pendingCount, 1);
    expect(server.records.length, 5);
    await disk.close();
    final reopened = catalogue(server, store());
    await reopened.catalogue();
    await reopened.syncAll();
    expect(reopened.pendingCount, 0);
    expect(server.records.length, 5);
    expect(reopened.localRecord(5)!['restaurant_name'], 'Offline addition');
  });

  test('lost edit response is preserved for inspection rather than replayed over newer data', () async {
    final server = CatalogueFixture();
    final app = catalogue(server, store());
    await app.catalogue();
    await app.mutate('PATCH', 1, {
      'revision': 'r1',
      'changes': {'notes': 'Phone edit'},
    });
    server.loseNextWriteResponse = true;
    await app.synchronizeIfChanged();
    expect(app.pendingCount, 1);
    server.macEdit(1, {'notes': 'Newer Mac edit'});
    await app.synchronizeIfChanged();
    expect(app.conflicts, hasLength(1));
    expect(server.records[1]!['notes'], 'Newer Mac edit');
    expect(app.localRecord(1)!['notes'], 'Phone edit');
  });

  test('server deletion stays absent while the pending local edit remains recoverable', () async {
    final server = CatalogueFixture();
    final app = catalogue(server, store());
    await app.catalogue();
    await app.mutate('PATCH', 1, {
      'revision': 'r1',
      'changes': {'notes': 'Keep this edit'},
    });
    server.records.remove(1);
    server.macEdit(2, {'notes': 'Bump server version'});
    await app.syncAll();
    expect(app.conflicts, hasLength(1));
    expect(app.serverRecord(1), isNull);
    expect(app.localRecord(1)!['notes'], 'Keep this edit');
    await app.resolve(app.conflicts.single['key'], useLocal: false);
    expect(app.localRecord(1), isNull);
    expect(app.exportLocalHistory(), contains('Keep this edit'));
  });

  test('parallel sync requests upload a queued mutation only once', () async {
    final server = CatalogueFixture();
    final app = catalogue(server, store());
    await app.catalogue();
    await app.mutate('PATCH', 1, {
      'revision': 'r1',
      'changes': {'notes': 'Only once'},
    });
    await Future.wait([app.syncAll(), app.syncAll()]);
    expect(
      server.requests.where((request) => request == 'PATCH /api/restaurants/1'),
      hasLength(1),
    );
    expect(app.pendingCount, 0);
    expect(app.hasChanges, false);
  });

  test(
    'an invalid snapshot cannot replace the last good SQLite copy',
    () async {
      final server = CatalogueFixture();
      final disk = store();
      final app = catalogue(server, disk);
      await app.catalogue();
      server.macEdit(1, {'rating': 'invalid numeric data'});
      await app.syncAll();
      expect(app.online, false);
      expect(app.serverRecord(1)!['revision'], 'r1');
      await disk.close();
      server.reachable = false;
      final reopened = catalogue(server, store());
      await reopened.catalogue();
      expect(reopened.localRecord(1)!['restaurant_name'], 'Bistro');
      expect(reopened.localRecord(1)!['revision'], 'r1');
    },
  );
}
