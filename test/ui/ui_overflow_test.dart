import 'package:flutter/material.dart';
import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Overflow regression tests for the shipped UI widgets.
///
/// These are library widgets, so a layout bug here reaches every consumer.
/// The extraction console overflowed by 21px on a 360dp device once its status
/// chip grew from "Idle" to "Complete" — caught on a real phone, not by any
/// test, which is why these exist.
///
/// 320dp is the narrowest viewport worth supporting (iPhone SE, small Android);
/// 360dp is the most common Android width by a wide margin.
const _widths = <double>[320, 360, 412];

Widget _host(Widget child, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: mode,
      home: Scaffold(body: child),
    );

Future<void> _pumpAt(
  WidgetTester tester,
  Widget child,
  double width, {
  double height = 800,
  ThemeMode mode = ThemeMode.light,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_host(child, mode: mode));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('ExtractionConsole', () {
    for (final width in _widths) {
      testWidgets('does not overflow at ${width.toInt()}dp', (tester) async {
        await _pumpAt(
          tester,
          ExtractionConsole(provider: FakeAiProvider()),
          width,
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'ExtractionConsole overflowed at ${width}dp',
        );
      });
    }

    testWidgets('renders in dark mode without overflowing', (tester) async {
      await _pumpAt(
        tester,
        ExtractionConsole(provider: FakeAiProvider()),
        360,
        mode: ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
    });

    for (final h in [480.0, 540.0, 600.0]) {
      testWidgets('does not overflow at height ${h.toInt()}dp', (tester) async {
        await _pumpAt(
          tester,
          ExtractionConsole(provider: FakeAiProvider()),
          360,
          height: h,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('shows the token and cost counter', (tester) async {
      await _pumpAt(
        tester,
        ExtractionConsole(provider: FakeAiProvider()),
        412,
      );

      expect(find.textContaining('Tokens:'), findsOneWidget);
      expect(find.text('Extract'), findsOneWidget);
    });
  });

  group('ResultViewer', () {
    const result = StructuredHarvestResult(
      data: {
        'name': 'A product with a deliberately long name to stress the layout',
        'price': {'amount': 149.99, 'currency': 'USD'},
      },
      coverage: ExtractionCoverage(
        satisfiedFields: {
          'name': ExtractionSource.jsonLd,
          'price': ExtractionSource.jsonLd,
        },
        missingFields: [],
      ),
      validation: ValidationResult(isValid: true),
    );

    for (final width in _widths) {
      testWidgets('does not overflow at ${width.toInt()}dp', (tester) async {
        await _pumpAt(tester, ResultViewer(result: result), width);

        expect(
          tester.takeException(),
          isNull,
          reason: 'ResultViewer overflowed at ${width}dp',
        );
      });
    }

    for (final h in [150.0, 200.0, 300.0]) {
      testWidgets('does not overflow at height ${h.toInt()}dp', (tester) async {
        await _pumpAt(tester, ResultViewer(result: result), 360, height: h);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('shows provenance for every field', (tester) async {
      await _pumpAt(tester, ResultViewer(result: result), 412);

      // Provenance is what makes an extraction trustworthy — a value with no
      // stated source is a value the caller cannot weigh.
      expect(find.textContaining('JSON-LD'), findsWidgets);
    });
  });

  group('ModelManagerSheet', () {
    for (final width in _widths) {
      testWidgets('model rows do not overflow at ${width.toInt()}dp',
          (tester) async {
        await _pumpAt(
          tester,
          ModelManagerSheet(manager: ModelManager()),
          width,
        );
        await tester.pump(const Duration(milliseconds: 500));

        // Every row pairs a model name with its download size and an Install
        // button. On a real 360dp phone these overflowed by up to 105px, and
        // the size is precisely the figure a user needs before committing to
        // a 550MB download.
        expect(
          tester.takeException(),
          isNull,
          reason: 'ModelManagerSheet overflowed at ${width}dp',
        );
      });
    }

    testWidgets('lists the model catalogue with sizes', (tester) async {
      await _pumpAt(tester, ModelManagerSheet(manager: ModelManager()), 412);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Gemma 3 1B'), findsOneWidget);
      expect(find.textContaining('MB'), findsWidgets);
    });
  });

  group('ProviderSettingsSheet', () {
    for (final width in _widths) {
      testWidgets('does not overflow at ${width.toInt()}dp', (tester) async {
        await _pumpAt(
          tester,
          ProviderSettingsSheet(
            chain: ProviderChain(providers: [FakeAiProvider()]),
          ),
          width,
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          tester.takeException(),
          isNull,
          reason: 'ProviderSettingsSheet overflowed at ${width}dp',
        );
      });
    }
  });

  group('StreamingTextView', () {
    for (final width in _widths) {
      testWidgets('does not overflow at ${width.toInt()}dp', (tester) async {
        await _pumpAt(
          tester,
          const StreamingTextView(stream: Stream<String>.empty()),
          width,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
