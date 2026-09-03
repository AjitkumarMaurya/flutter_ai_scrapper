import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the defect that made on-device AI unusable.
///
/// Measured on a mid-range Android phone, a 0.6B model spent 38.6 seconds on
/// prefill alone. The extraction budget was a fixed 30 seconds, so the AI stage
/// timed out on *every* run, silently returned the deterministic result, and
/// looked exactly like "the model contributed nothing".
class _SlowProvider implements AiProvider {
  _SlowProvider(this.delay, {required bool local}) : _local = local;

  final Duration delay;
  final bool _local;

  @override
  String get id => _local ? 'slow-local' : 'slow-remote';

  @override
  AiCapabilities get capabilities => AiCapabilities(isLocal: _local);

  @override
  bool get isReady => true;

  @override
  Future<AiResult> extract(Schema schema, String content, {String? prompt}) async {
    await Future<void>.delayed(delay);
    return AiResult(
      providerId: id,
      data: const {'price': '51.77'},
      usage: const TokenUsage(promptTokens: 120, completionTokens: 8),
    );
  }

  @override
  Future<String> complete(String prompt) async => '';

  @override
  Stream<String> stream(String prompt) => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

void main() {
  group('budget is derived from the provider, not a constant', () {
    test('a local provider gets minutes, not seconds', () {
      const options = ExtractionOptions();
      final local = _SlowProvider(Duration.zero, local: true);

      expect(options.budgetFor(local), ExtractionOptions.localBudget);
      expect(
        options.budgetFor(local).inSeconds,
        greaterThan(60),
        reason: 'a 0.6B model measured 38.6s on prefill alone; a 30s budget '
            'meant on-device extraction could never finish',
      );
    });

    test('a network provider gets a tighter budget', () {
      const options = ExtractionOptions();
      final remote = _SlowProvider(Duration.zero, local: false);

      expect(options.budgetFor(remote), ExtractionOptions.remoteBudget);
      expect(
        options.budgetFor(remote) < options.budgetFor(
          _SlowProvider(Duration.zero, local: true),
        ),
        isTrue,
      );
    });

    test('an explicit timeout always wins', () {
      const options = ExtractionOptions(timeout: Duration(seconds: 7));
      expect(
        options.budgetFor(_SlowProvider(Duration.zero, local: true)),
        const Duration(seconds: 7),
      );
    });
  });

  group('a timed-out AI stage is reported, not swallowed', () {
    const html = '''
      <html><head><meta property="og:title" content="A Light in the Attic">
      </head><body><p>Price shown elsewhere.</p></body></html>
    ''';

    final schema = Schema.object({
      'title': const Field.string(),
      'price': const Field.string(),
    });

    test('the result says the stage timed out and names the budget', () async {
      final page = AiScrapper.fromHtml(html, url: 'https://books.example/x');

      final result = await page.extractWithAi(
        schema,
        provider: _SlowProvider(const Duration(seconds: 2), local: true),
        options: const ExtractionOptions(timeout: Duration(milliseconds: 150)),
      );

      // Deterministic data still comes back — a failed model must never fail
      // the whole extraction.
      expect(result.data['title'], isNotNull);

      // But the reason is no longer thrown away.
      expect(result.aiOutcome, isNotNull);
      expect(result.aiOutcome!.status, AiStatus.timedOut);
      expect(result.aiOutcome!.message, contains('budget'));
    });

    test('a completed stage reports success and its token usage', () async {
      final page = AiScrapper.fromHtml(html, url: 'https://books.example/x');

      final result = await page.extractWithAi(
        schema,
        provider: _SlowProvider(Duration.zero, local: true),
      );

      expect(result.aiOutcome?.status, AiStatus.succeeded);
      expect(
        result.aiOutcome?.usage?.totalTokens,
        greaterThan(0),
        reason: 'usage must reach the caller, or a token counter cannot be '
            'anything but zero',
      );
    });

    test('no AI stage at all leaves the outcome null', () {
      // Deterministic data satisfied everything, so nothing was inferred.
      final page = AiScrapper.fromHtml(html, url: 'https://books.example/x');
      final result = page.extract(Schema.object({'title': const Field.string()}));

      expect(result.aiOutcome, isNull);
    });
  });
}
