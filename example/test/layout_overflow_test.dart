import 'package:example/viewmodels/scraper_viewmodel.dart';
import 'package:example/views/screens/scraper_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Regression tests for the RenderFlex overflow the results pane used to throw.
///
/// The trigger is a short viewport: a small phone, or a tall on-screen keyboard
/// shrinking the usable height. The empty state's fixed 64px icon plus two
/// lines of text had nowhere to go, and the form kept its full natural height
/// while squeezing the results pane below its own header.
Widget _app() => MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => ScraperViewModel(),
        child: const ScraperScreen(),
      ),
    );

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
}

void main() {
  group('no overflow at constrained heights', () {
    // Each entry is a real squeeze: a small phone, a small phone with the
    // keyboard up, and a deliberately extreme case.
    const sizes = <String, Size>{
      'small phone': Size(320, 568),
      'small phone with keyboard': Size(320, 320),
      'very short viewport': Size(360, 240),
      'tall phone': Size(412, 915),
    };

    for (final entry in sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pumpAt(tester, entry.value);

        // takeException() returns any assertion the render pass threw. An
        // overflow surfaces here rather than failing the pump outright.
        expect(
          tester.takeException(),
          isNull,
          reason: 'layout overflowed at ${entry.value}',
        );
      });
    }
  });

  group('empty state', () {
    testWidgets('renders its message when there is room', (tester) async {
      await _pumpAt(tester, const Size(412, 915));

      expect(find.text('No scraping performed yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a viewport too short to show it all', (tester) async {
      await _pumpAt(tester, const Size(320, 300));

      // The content scrolls rather than overflowing; the widget is still there.
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('results pane keeps a usable share of the height', () {
    testWidgets('the form never takes the whole screen', (tester) async {
      await _pumpAt(tester, const Size(360, 640));

      final results = tester.getSize(find.byType(Card).first);
      expect(results.height, greaterThan(100),
          reason: 'the results card must not be squeezed to nothing');
    });
  });
}
