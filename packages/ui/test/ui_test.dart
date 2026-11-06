import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

void main() {
  test(
    'light and dark themes are the same Material 3 design in two brightnesses',
    () {
      final light = skeletonLightTheme();
      final dark = skeletonDarkTheme();

      expect(light.useMaterial3, isTrue);
      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(light.colorScheme.primary, isNot(dark.colorScheme.primary));
    },
  );

  test(
    'Flutter default text buttons (picker dialogs) get a border at rest',
    () {
      for (final theme in [skeletonLightTheme(), skeletonDarkTheme()]) {
        final side = theme.textButtonTheme.style?.side?.resolve({});
        expect(side, isNotNull);
        expect(side!.style, BorderStyle.solid);
      }
    },
  );

  testWidgets('ErrorView shows the message and calls onRetry from its button', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: skeletonLightTheme(),
        home: Scaffold(
          body: ErrorView(
            message: 'Cannot load',
            retryLabel: 'Try again',
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('Cannot load'), findsOneWidget);
    await tester.tap(find.text('Try again'));

    expect(retries, 1);
  });

  testWidgets('a filled button fits beside other widgets in a row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: skeletonLightTheme(),
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('Renew consent')),
              FilledButton(onPressed: () {}, child: const Text('Agree')),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FilledButton)).height, 48);
  });
}
