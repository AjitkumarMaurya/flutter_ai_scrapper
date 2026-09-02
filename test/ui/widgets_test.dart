import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResultViewer Widget Tests', () {
    final sampleHarvest = StructuredHarvestResult(
      data: {'title': 'Gaming Laptop', 'price': 1499.00},
      coverage: const ExtractionCoverage(
        satisfiedFields: {
          'title': ExtractionSource.jsonLd,
          'price': ExtractionSource.recipe,
        },
        missingFields: [],
      ),
      validation: const ValidationResult(isValid: true),
    );

    testWidgets('renders table and provenance badges in light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
          home: Scaffold(
            body: ResultViewer(result: sampleHarvest),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Table'), findsOneWidget);
      expect(find.text('JSON'), findsOneWidget);
      expect(find.text('Markdown'), findsOneWidget);
      expect(find.text('Raw'), findsOneWidget);

      // Verify field data
      expect(find.text('Gaming Laptop'), findsOneWidget);
      expect(find.text('1499.0'), findsOneWidget);

      // Verify provenance badges
      expect(find.text('JSON-LD'), findsOneWidget);
      expect(find.text('Recipe'), findsOneWidget);

      // Tap JSON tab
      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"Gaming Laptop"'), findsOneWidget);
    });

    testWidgets('renders in dark mode without visual errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
          home: Scaffold(
            body: ResultViewer(result: sampleHarvest),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gaming Laptop'), findsOneWidget);
      expect(find.text('JSON-LD'), findsOneWidget);
    });
  });

  group('StreamingTextView Widget Tests', () {
    testWidgets('renders token stream with collapsible thinking reasoning block', (tester) async {
      final controller = StreamController<String>.broadcast(sync: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: StreamingTextView(stream: controller.stream),
          ),
        ),
      );

      // Initially empty
      expect(find.text('Waiting for tokens...'), findsOneWidget);

      // Stream thinking tokens
      controller.add('<think>Analyzing DOM skeleton</think>');
      await tester.pump();

      expect(find.textContaining('Model Reasoning'), findsOneWidget);
      expect(find.textContaining('Analyzing DOM skeleton'), findsOneWidget);

      // Stream content tokens
      controller.add('Here is the extracted product title.');
      await tester.pump();

      expect(find.textContaining('Here is the extracted product title.'), findsOneWidget);

      await controller.close();
    });
  });

  group('ProviderSettingsSheet Widget Tests', () {
    testWidgets('renders allowCloudEgress toggle and configured providers', (tester) async {
      final chain = ProviderChain(
        providers: [
          FakeAiProvider(id: 'local-gemma', capabilities: const AiCapabilities(isLocal: true)),
          FakeAiProvider(id: 'cloud-openai', capabilities: const AiCapabilities(isLocal: false)),
        ],
        allowCloudEgress: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: ProviderSettingsSheet(chain: chain),
          ),
        ),
      );

      expect(find.text('AI Provider Settings'), findsOneWidget);
      expect(find.text('Allow Cloud Egress'), findsOneWidget);
      expect(find.text('local-gemma'), findsOneWidget);
      expect(find.text('cloud-openai'), findsOneWidget);
      expect(find.text('Test Chain Connection'), findsOneWidget);
    });
  });
}
