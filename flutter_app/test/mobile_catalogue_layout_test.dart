import 'package:beneede_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'mobile pairs location filters and keeps Add beside sorting',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const BeneEdeApp());
      await tester.pumpAndSettle();

      expect(
        (tester.getCenter(find.text('All countries')).dy -
                tester.getCenter(find.text('All cities')).dy)
            .abs(),
        lessThan(2),
      );
      final add = find.byTooltip('Add restaurant');
      final sort = find.text('Restaurant name');
      expect(
        (tester.getCenter(add).dy - tester.getCenter(sort).dy).abs(),
        lessThan(16),
      );
      expect(tester.getCenter(add).dx, greaterThan(tester.getCenter(sort).dx));
      expect(find.textContaining('Needs review only'), findsNothing);
      expect(find.text('Archived'), findsNothing);
      expect(tester.widget<Text>(find.text('+')).style!.color, Colors.white);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
