import 'package:beneede_app/widgets/contact_tooltip.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mouse hover shows contact details on macOS', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ContactTooltip(
              message: '70 Wilton Road',
              child: IconButton(
                icon: const Icon(Icons.location_on),
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(find.byType(IconButton)));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('70 Wilton Road', findRichText: true), findsOneWidget);
    await mouse.removePointer();
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('phone click explicitly shows the number', (tester) async {
    final key = GlobalKey<TooltipState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ContactTooltip(
              tooltipKey: key,
              message: '+44 20 7828 8931',
              child: IconButton(
                icon: const Icon(Icons.phone),
                onPressed: () => key.currentState?.ensureTooltipVisible(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('+44 20 7828 8931', findRichText: true), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('website click still invokes the action', (tester) async {
    var clicks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ContactTooltip(
              message: 'https://example.com',
              child: IconButton(
                icon: const Icon(Icons.language),
                onPressed: () => clicks++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IconButton));
    expect(clicks, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));
}
