import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test for the demo app.
///
/// Replaces the counter test `flutter create` generates, which tested a
/// widget this app does not contain.
void main() {
  testWidgets('the demo app starts and shows its scraping controls',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Tag-based Scraping'), findsOneWidget);
    expect(find.text('Regex-based Scraping'), findsOneWidget);
    expect(find.text('No scraping performed yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the URL field is prefilled with a working example',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final urlField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.labelText ?? '').toLowerCase().contains('url'),
      ),
    );

    expect(urlField.controller?.text, startsWith('https://'));
  });
}
