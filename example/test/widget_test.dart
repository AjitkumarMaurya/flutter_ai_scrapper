import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test for the demo app.
///
/// Replaces the counter test `flutter create` generates, which tested a widget
/// this app does not contain.
void main() {
  testWidgets('the demo app starts on the quick-scrape tier', (tester) async {
    await tester.pumpWidget(const ScrapperDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('AI Scrapper 2.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all four API tiers are reachable', (tester) async {
    await tester.pumpWidget(const ScrapperDemoApp());
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);

    final destinations =
        tester.widget<NavigationBar>(navBar).destinations.length;
    expect(destinations, 4, reason: 'one destination per API tier');
  });

  testWidgets('the model manager and provider settings are reachable',
      (tester) async {
    await tester.pumpWidget(const ScrapperDemoApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('On-Device Models'), findsOneWidget);
    expect(find.byTooltip('Provider Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
