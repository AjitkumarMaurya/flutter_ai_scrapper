import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomProvider', () {
    test('completes extraction via a concise user-supplied callback', () async {
      // Acceptance test: a 20-line callback wired to an arbitrary endpoint completes extraction
      final provider = CustomProvider(
        id: 'enterprise-custom-gateway',
        onExtract: (schema, content) async {
          final payload = {
            'company': 'Acme Corp',
            'revenue': 5000000,
          };
          final validation = schema.validate(payload);
          return AiResult(
            providerId: 'enterprise-custom-gateway',
            data: validation.coerced ?? payload,
            rawText: payload.toString(),
            confidence: 1.0,
            usage: const TokenUsage(promptTokens: 80, completionTokens: 20),
          );
        },
      );

      final schema = Schema.object({
        'company': const Field.string(),
        'revenue': const Field.integer(),
      });

      final result = await provider.extract(schema, 'Report document');

      expect(result.isSuccessful, isTrue);
      expect(result.data['company'], 'Acme Corp');
      expect(result.data['revenue'], 5000000);
      expect(result.providerId, 'enterprise-custom-gateway');
    });

    test('supports custom completion and streaming handlers', () async {
      final provider = CustomProvider(
        id: 'custom-llm',
        onExtract: (s, c) async => AiResult.failure(providerId: 'x', error: 'err'),
        onComplete: (prompt) async => 'Echo: $prompt',
        onStream: (prompt) async* {
          yield 'Token 1';
          yield ' Token 2';
        },
      );

      expect(await provider.complete('Hello'), 'Echo: Hello');
      expect(await provider.stream('Hello').toList(), ['Token 1', ' Token 2']);
    });
  });
}
