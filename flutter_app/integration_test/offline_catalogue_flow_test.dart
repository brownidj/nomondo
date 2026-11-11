import 'dart:convert';

import 'package:beneede_app/data/mobile_catalogue.dart';
import 'package:beneede_app/data/mobile_catalogue_store.dart';
import 'package:beneede_app/main.dart';
import 'package:beneede_app/services/catalogue_client.dart';
import 'package:beneede_app/services/device_pairing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/catalogue_fixture.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native SQLite: browse offline, edit, review, add, reopen, resolve conflict and delete',
    (tester) async {
      final fixture = CatalogueFixture()..reachable = false;
      var networkEligible = false;
      final path =
          '${await getDatabasesPath()}/beneede-integration-${DateTime.now().microsecondsSinceEpoch}.sqlite3';
      var store = SqliteCatalogueStore('isolated-integration', path: path);
      var catalogue = MobileCatalogue(
        remote: fixture.client(),
        baseUrl: catalogueBaseUrl,
        store: store,
        loadSeed: () async => {
          'version': '10',
          'restaurants': fixture.records.values.toList(),
          'reviews': {
            for (final row in fixture.records.values)
              row['id'].toString(): fixture.review(row),
          },
        },
        checkLocalNetwork: () async => networkEligible,
      );
      MobileCatalogue.active = catalogue;

      Future<void> showApp() async {
        await tester.pumpWidget(const BeneEdeApp());
        await tester.pumpAndSettle();
        // Exercise sync explicitly; no timer races during long UI assertions.
        catalogue.pause();
        catalogue.foreground = true;
      }

      Future<void> search(String text) async {
        await tester.enterText(find.byType(TextField).first, text);
        await tester.pumpAndSettle();
      }

      Future<void> enter(String label, String value) async {
        await tester.ensureVisible(field(label));
        await tester.enterText(field(label), value);
        await tester.pumpAndSettle();
      }

      Future<void> tapText(String text) async {
        final finder = find.text(text).last;
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> editFirst() async {
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();
      }

      try {
        await showApp();
        expect(fixture.requests, isEmpty);
        expect(find.byKey(const ValueKey('restaurant-card-1')), findsOneWidget);
        fixture.reachable = false;
        await search('Bistro');
        await tester.tap(find.text('French'));
        await tester.pumpAndSettle();
        expect(find.text('Cuisine — Bistro'), findsOneWidget);
        expect(find.text('Fixture notes'), findsOneWidget);
        await tapText('Close');

        await editFirst();
        await enter('Notes', 'Saved offline on the native device');
        await tapText('Save');
        expect(catalogue.pendingCount, 1);
        expect(catalogue.hasChanges, true);

        await tester.tap(find.text('80%'));
        await tester.pumpAndSettle();
        expect(find.text('Review — Bistro'), findsOneWidget);
        await tapText('Supporting evidence (1)');
        expect(find.text('Fixture source evidence'), findsOneWidget);
        await tapText('Pass');
        expect(catalogue.pendingCount, 2);
        expect(catalogue.localRecord(1)!['review_status'], 'passed');

        await tester.tap(find.byTooltip('Add restaurant'));
        await tester.pumpAndSettle();
        await enter('Restaurant name *', 'Offline venue');
        await enter('City *', 'Paris');
        await tapText('Add restaurant');
        expect(catalogue.pendingCount, 3);
        final added =
            jsonDecode((await catalogue.catalogue()).body)['restaurants']
                as List;
        final localId =
            added.singleWhere(
                  (row) => row['restaurant_name'] == 'Offline venue',
                )['id']
                as int;
        expect(localId, isNegative);

        // Destroy the UI/controller and close SQLite before opening a fresh handle.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        catalogue.dispose();
        await store.close();
        store = SqliteCatalogueStore('isolated-integration', path: path);
        catalogue = MobileCatalogue(
          remote: fixture.client(),
          baseUrl: catalogueBaseUrl,
          store: store,
          checkLocalNetwork: () async => networkEligible,
        );
        MobileCatalogue.active = catalogue;
        await showApp();
        expect(catalogue.pendingCount, 3);
        expect(
          catalogue.localRecord(1)!['notes'],
          'Saved offline on the native device',
        );
        await search('Offline venue');
        expect(
          find.byKey(ValueKey('restaurant-card-$localId')),
          findsOneWidget,
        );

        fixture.reachable = true;
        fixture.macEdit(1, {'notes': 'Another client changed the same record'});
        networkEligible = true;
        catalogue.networkChanged(true);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(catalogue.conflicts, hasLength(1));
        expect(
          fixture.records[1]!['notes'],
          'Another client changed the same record',
        );
        expect(
          catalogue.localRecord(1)!['notes'],
          'Saved offline on the native device',
        );
        expect(fixture.records[5]!['restaurant_name'], 'Offline venue');

        await tester.tap(find.textContaining('sync issue').first);
        await tester.pumpAndSettle();
        await tapText('Bistro');
        expect(
          find.text('Notes: Another client changed the same record'),
          findsOneWidget,
        );
        expect(
          find.text('Notes: Saved offline on the native device'),
          findsOneWidget,
        );
        await tapText('Apply my changes');
        await tapText('Confirm');
        await tester.pumpAndSettle();
        expect(catalogue.pendingCount, 0);
        expect(
          fixture.records[1]!['notes'],
          'Saved offline on the native device',
        );
        expect(fixture.records[1]!['review_status'], 'passed');
        await tapText('Close');

        await search('Offline venue');
        await editFirst();
        await tapText('Delete');
        await tapText('Delete');
        expect(catalogue.pendingCount, 1);
        await catalogue.syncAll();
        await tester.pumpAndSettle();
        expect(fixture.records.containsKey(5), false);
        expect(catalogue.hasChanges, false);
        final requestCount = fixture.requests.length;
        await catalogue.synchronizeIfChanged();
        expect(fixture.requests.length, requestCount);
        catalogue.resume();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        final idleRequestCount = fixture.requests.length;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 16)),
        );
        catalogue.pause();
        expect(fixture.requests.length, idleRequestCount);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        catalogue.dispose();
        MobileCatalogue.active = null;
        await store.close();
        await deleteDatabase(path);
      }
    },
  );

  testWidgets('pairing key survives a new native secure-store instance', (
    tester,
  ) async {
    final scope =
        'integration-keychain-${DateTime.now().microsecondsSinceEpoch}';
    final first = SecurePairingKeyStore(scope);
    try {
      await first.write('fixture-keychain-value-not-a-real-credential');
      final second = SecurePairingKeyStore(scope);
      expect(
        await second.read(),
        'fixture-keychain-value-not-a-real-credential',
      );
    } finally {
      await first.clear();
    }
  });
}
