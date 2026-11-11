import 'dart:convert';

import 'package:beneede_app/data/mobile_catalogue.dart';
import 'package:beneede_app/data/mobile_catalogue_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/catalogue_fixture.dart';

class SeedStore implements CatalogueStore {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value == null
      ? null
      : jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  @override
  Future<void> write(Map<String, dynamic> state) async =>
      value = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
}

Map<String, dynamic> seed(CatalogueFixture server) => {
  'version': '10',
  'packaged_at': '2026-11-11T00:00:00Z',
  'restaurants': server.records.values.toList(),
  'reviews': {
    for (final row in server.records.values)
      row['id'].toString(): server.review(row),
  },
};

void main() {
  test('fresh installation starts with packaged records and evidence without a server', () async {
    final server = CatalogueFixture()..reachable = false;
    final store = SeedStore();
    final app = MobileCatalogue(
      remote: server.client(),
      baseUrl: 'http://fixture:8766',
      store: store,
      loadSeed: () async => seed(server),
    );
    expect(
      jsonDecode((await app.catalogue()).body)['restaurants'],
      hasLength(4),
    );
    expect(server.requests, isEmpty);
    expect(app.hasChanges, false);
    expect(store.value!['has_snapshot'], true);
    final review = jsonDecode((await app.review(1)).body);
    expect(review['sources'].single['raw_text'], 'Original fixture entry');
    expect(server.requests, isEmpty);
    app.dispose();
  });

  test('a newer application seed never overwrites an existing copy or pending edits', () async {
    final server = CatalogueFixture();
    final store = SeedStore();
    final first = MobileCatalogue(
      remote: server.client(),
      baseUrl: 'http://fixture:8766',
      store: store,
      loadSeed: () async => seed(server),
    );
    await first.catalogue();
    await first.mutate('PATCH', 1, {
      'revision': 'r1',
      'changes': {'notes': 'Keep offline edit'},
    });
    first.dispose();
    var seedReads = 0;
    final reopened = MobileCatalogue(
      remote: server.client(),
      baseUrl: 'http://fixture:8766',
      store: store,
      loadSeed: () async {
        seedReads++;
        return seed(server);
      },
    );
    await reopened.catalogue();
    expect(seedReads, 0);
    expect(reopened.localRecord(1)!['notes'], 'Keep offline edit');
    expect(reopened.pendingCount, 1);
    reopened.dispose();
  });

  testWidgets(
    'reconnection drains queued work and checks clean remote changes once',
    (tester) async {
      final server = CatalogueFixture();
      var wifi = false;
      final app = MobileCatalogue(
        remote: server.client(),
        baseUrl: 'http://fixture:8766',
        store: SeedStore(),
        loadSeed: () async => seed(server),
        checkLocalNetwork: () async => wifi,
      );
      await app.catalogue();
      await app.mutate('PATCH', 1, {
        'revision': 'r1',
        'changes': {'notes': 'Away from Mac'},
      });
      await app.synchronizeIfChanged();
      expect(server.requests, isEmpty);
      expect(app.pendingCount, 1);
      wifi = true;
      app.networkChanged(true);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(server.records[1]!['notes'], 'Away from Mac');
      expect(app.pendingCount, 0);
      expect(app.hasChanges, false);
      var count = server.requests.length;
      await app.synchronizeIfChanged();
      expect(server.requests.length, count);
      wifi = false;
      app.networkChanged(false);
      server.macEdit(1, {'notes': 'Mac edit while phone was away'});
      wifi = true;
      app.networkChanged(true);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(app.localRecord(1)!['notes'], 'Mac edit while phone was away');
      count = server.requests.length;
      await app.synchronizeIfChanged();
      expect(server.requests.length, count);
      app.dispose();
    },
  );
}
