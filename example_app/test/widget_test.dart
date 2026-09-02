// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example_app/main.dart';

void main() {
  testWidgets('Flutter Scrapper Demo loads correctly',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FlutterScrapperDemo());

    // Verify that the app loads with the correct title
    expect(find.text('🚀 Flutter Scrapper Demo'), findsOneWidget);

    // Verify that the URL input field is present
    expect(find.byType(TextField), findsOneWidget);

    // Verify that the scrape button is present
    expect(find.text('🚀 Start Scraping'), findsOneWidget);

    // Verify welcome message is shown initially
    expect(
        find.text(
            '👋 Welcome to Flutter Scrapper!\n\nEnter a URL and tap "Start Scraping" to see the magic ✨'),
        findsOneWidget);
  });
}
