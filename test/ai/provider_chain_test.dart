import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _egressTests();
  group('ProviderChain Resilience & Fallback Engine', () {
    final testSchema = Schema.object({
      'name': const Field.string(),
      'score': const Field.integer(),
    });

    test('row 1: skips unconfigured providers without throwing', () async {
      final unconfigured = FakeAiProvider(
        id: 'unconfigured-provider',
      )..isReady = false;

      final workingLocal = FakeAiProvider(
        id: 'working-local',
        scriptedData: {'name': 'Success Item', 'score': 100},
      );

      final chain = ProviderChain(
        providers: [unconfigured, workingLocal],
        allowCloudEgress: false,
      );

      final result = await chain.extract(testSchema, 'Doc');

      expect(result.isSuccessful, isTrue);
      expect(result.providerId, 'working-local');
      expect(result.data['name'], 'Success Item');
    });

    test('row 2: falls back to next provider on network exception', () async {
      final networkFailing = FakeAiProvider(
        id: 'failing-network',
        capabilities: const AiCapabilities(isLocal: false),
        onExtract: (s, c) => throw const HttpException('Connection refused', statusCode: 503),
      );

      final localFallback = FakeAiProvider(
        id: 'local-gemma-fallback',
        capabilities: const AiCapabilities(isLocal: true),
        scriptedData: {'name': 'Local Result', 'score': 90},
      );

      final chain = ProviderChain(
        providers: [networkFailing, localFallback],
        allowCloudEgress: true,
      );

      final result = await chain.extract(testSchema, 'Doc');

      expect(result.isSuccessful, isTrue);
      expect(result.providerId, 'local-gemma-fallback');
    });

    test('row 3: retries 429 rate limit before advancing to next in chain', () async {
      var attempts = 0;
      final rateLimitedProvider = FakeAiProvider(
        id: 'rate-limited-endpoint',
        capabilities: const AiCapabilities(isLocal: false),
        onExtract: (s, c) {
          attempts++;
          throw const HttpException('Too Many Requests', statusCode: 429);
        },
      );

      final nextProvider = FakeAiProvider(
        id: 'backup-provider',
        scriptedData: {'name': 'Backup', 'score': 85},
      );

      final chain = ProviderChain(
        providers: [rateLimitedProvider, nextProvider],
        allowCloudEgress: true,
      );

      final result = await chain.extract(testSchema, 'Doc');

      expect(attempts, 2); // 1 initial + 1 backoff retry
      expect(result.isSuccessful, isTrue);
      expect(result.providerId, 'backup-provider');
    });

    test('row 4: retries 5xx server error before advancing to next in chain', () async {
      var attempts = 0;
      final serverErrorProvider = FakeAiProvider(
        id: '500-endpoint',
        capabilities: const AiCapabilities(isLocal: false),
        onExtract: (s, c) {
          attempts++;
          throw const HttpException('Internal Server Error', statusCode: 500);
        },
      );

      final nextProvider = FakeAiProvider(
        id: 'backup-after-500',
        scriptedData: {'name': 'Recovered', 'score': 75},
      );

      final chain = ProviderChain(
        providers: [serverErrorProvider, nextProvider],
        allowCloudEgress: true,
      );

      final result = await chain.extract(testSchema, 'Doc');

      expect(attempts, 2);
      expect(result.isSuccessful, isTrue);
      expect(result.providerId, 'backup-after-500');
    });

    test('row 5: bad key (401/403) logs loud warning and falls back to Gemma', () async {
      final badKeyProvider = FakeAiProvider(
        id: 'bad-key-cloud',
        capabilities: const AiCapabilities(isLocal: false),
        onExtract: (s, c) => throw const HttpException('Invalid API Key', statusCode: 401),
      );

      final localGemma = FakeAiProvider(
        id: 'local-gemma',
        capabilities: const AiCapabilities(isLocal: true),
        scriptedData: {'name': 'Gemma Recovery', 'score': 88},
      );

      final chain = ProviderChain(
        providers: [badKeyProvider, localGemma],
        allowCloudEgress: true,
      );

      final result = await chain.extract(testSchema, 'Doc');

      expect(result.isSuccessful, isTrue);
      expect(result.providerId, 'local-gemma');
      expect(result.data['name'], 'Gemma Recovery');
    });

    test('row 7: throws NoProviderAvailableException when all providers exhausted', () async {
      final failing1 = FakeAiProvider(
        id: 'f1',
        onExtract: (s, c) => throw const HttpException('Down', statusCode: 502),
      );
      final failing2 = FakeAiProvider(
        id: 'f2',
        onExtract: (s, c) => throw const HttpException('Down', statusCode: 502),
      );

      final chain = ProviderChain(
        providers: [failing1, failing2],
        allowCloudEgress: true,
      );

      expect(
        () => chain.extract(testSchema, 'Doc'),
        throwsA(isA<NoProviderAvailableException>()),
      );
    });

    test('allowCloudEgress: false skips cloud providers and guarantees zero egress', () async {
      final cloudProvider = FakeAiProvider(
        id: 'cloud-openai',
        capabilities: const AiCapabilities(isLocal: false),
        scriptedData: {'name': 'Cloud Data', 'score': 100},
      );

      final localProvider = FakeAiProvider(
        id: 'on-device-gemma',
        capabilities: const AiCapabilities(isLocal: true),
        scriptedData: {'name': 'Local Safe Data', 'score': 99},
      );

      final chain = ProviderChain(
        providers: [cloudProvider, localProvider],
        allowCloudEgress: false, // Privacy default
      );

      final result = await chain.extract(testSchema, 'Doc');

      expect(result.isSuccessful, isTrue);
      expect(result.providerId, 'on-device-gemma');
      expect(result.data['name'], 'Local Safe Data');
      expect(cloudProvider.calls, isEmpty); // Cloud provider was never called!
    });

    test('preferLocal prioritizes on-device provider first', () async {
      final cloudProvider = FakeAiProvider(
        id: 'cloud-provider',
        capabilities: const AiCapabilities(isLocal: false),
        scriptedData: {'name': 'From Cloud', 'score': 90},
      );

      final localProvider = FakeAiProvider(
        id: 'local-provider',
        capabilities: const AiCapabilities(isLocal: true),
        scriptedData: {'name': 'From Local', 'score': 90},
      );

      final chain = ProviderChain(
        providers: [cloudProvider, localProvider],
        allowCloudEgress: true,
        preferLocal: true,
      );

      final result = await chain.extract(testSchema, 'Doc');

      expect(result.providerId, 'local-provider');
      expect(cloudProvider.calls, isEmpty);
    });

    test('KeySanitizer redacts API keys and bearer tokens from logs and error strings', () {
      const sensitive = 'Error talking to https://api.openai.com with Bearer sk-abc1234567890xyz and key sk-998877665544332211';
      final redacted = KeySanitizer.redact(sensitive);

      expect(redacted, isNot(contains('sk-abc1234567890xyz')));
      expect(redacted, isNot(contains('sk-998877665544332211')));
      expect(redacted, contains('Bearer [REDACTED]'));
      expect(redacted, contains('sk-9...[REDACTED]'));
    });
  });
}

// ---------------------------------------------------------------------------
// Egress gating — added after a device-testing review found `isLocal`
// defaulting to `true`, which silently exempted any provider whose author
// forgot to set it from the user's `allowCloudEgress: false` choice.
// ---------------------------------------------------------------------------

class _UndeclaredProvider implements AiProvider {
  @override
  String get id => 'undeclared';

  // Deliberately omits isLocal, exactly as a careless implementer would.
  @override
  AiCapabilities get capabilities => const AiCapabilities();

  @override
  bool get isReady => true;

  @override
  Future<AiResult> extract(Schema schema, String content, {String? prompt}) async =>
      throw StateError('must never be reached with egress disabled');

  @override
  Future<String> complete(String prompt) async =>
      throw StateError('must never be reached with egress disabled');

  @override
  Stream<String> stream(String prompt) =>
      throw StateError('must never be reached with egress disabled');

  @override
  Future<void> dispose() async {}
}

void _egressTests() {
  group('egress gating fails safe', () {
    test('a provider that does not declare isLocal is treated as remote', () {
      expect(
        const AiCapabilities().isLocal,
        isFalse,
        reason: 'defaulting to local would exempt it from the egress block',
      );
    });

    test('an undeclared provider is skipped when egress is disabled', () async {
      final chain = ProviderChain(
        providers: [_UndeclaredProvider()],
        allowCloudEgress: false,
      );

      // The provider throws if it is ever invoked, so reaching it fails loudly.
      await expectLater(
        chain.extract(Schema.object({'x': const Field.string()}), '<html></html>'),
        throwsA(isA<Exception>()),
      );
    });

    test('local providers use localProviderTimeout allowing longer inference times', () async {
      final slowLocal = FakeAiProvider(
        id: 'slow-local',
        capabilities: const AiCapabilities(isLocal: true),
        simulatedDelay: const Duration(milliseconds: 150),
        scriptedData: {'name': 'Done', 'score': 100},
      );

      final chain = ProviderChain(
        providers: [slowLocal],
        providerTimeout: const Duration(milliseconds: 50),
        localProviderTimeout: const Duration(milliseconds: 500),
      );

      final result = await chain.extract(
        Schema.object({'name': const Field.string(), 'score': const Field.integer()}),
        'Doc',
      );

      expect(result.isSuccessful, isTrue);
      expect(result.data['name'], 'Done');
    });
  });
}
