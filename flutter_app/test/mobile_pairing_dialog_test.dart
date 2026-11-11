import 'dart:convert';

import 'package:beneede_app/data/mobile_catalogue.dart';
import 'package:beneede_app/data/mobile_catalogue_store.dart';
import 'package:beneede_app/widgets/mobile_sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/catalogue_fixture.dart';

class PairDialogStore implements CatalogueStore {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> state) async {
    value = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
  }
}

void main() {
  testWidgets(
    'sync details stays open on failure and closes after automatic sync',
    (tester) async {
      final server = CatalogueFixture();
      final app = MobileCatalogue(
        remote: server.client(),
        baseUrl: 'http://fixture:8766',
        store: PairDialogStore(),
      );
      await app.catalogue();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MobileSyncStatus(catalogue: app)),
        ),
      );
      await tester.tap(find.byType(TextButton).first);
      await tester.pumpAndSettle();
      expect(find.text('Local storage and sync'), findsOneWidget);
      server.reachable = false;
      await tester.tap(find.text('Sync now'));
      await tester.pumpAndSettle();
      expect(find.text('Local storage and sync'), findsOneWidget);
      server.reachable = true;
      await app.syncAll();
      await tester.pumpAndSettle();
      expect(find.text('Local storage and sync'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );

  testWidgets(
    'pairing dialog retains errors and then closes after successful pairing',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final server = CatalogueFixture();
      String? paired;
      final app = MobileCatalogue(
        remote: server.client(),
        baseUrl: 'http://fixture:8766',
        store: PairDialogStore(),
        pairWithServer: (key) async {
          if (key != 'correct-test-key') {
            throw const FormatException('Wrong pairing key');
          }
          paired = key;
        },
      );
      await app.catalogue();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MobileSyncStatus(catalogue: app)),
        ),
      );
      await tester.tap(find.textContaining('Saved on this device'));
      await tester.pumpAndSettle();
      final pairButton = find.widgetWithText(TextButton, 'Pair with Mac');
      await tester.ensureVisible(pairButton);
      await tester.pumpAndSettle();
      await tester.tap(pairButton);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'wrong-test-key');
      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong pairing key'), findsOneWidget);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': '  correct-test-key\n'}
            : null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      await tester.tap(find.text('Paste key'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong pairing key'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Show key'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'correct-test-key',
      );
      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();
      expect(paired, 'correct-test-key');
      expect(find.text('Mac pairing key'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
}
