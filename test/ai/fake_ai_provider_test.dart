import 'package:flutter_ai_scrapper/src/ai/fake_ai_provider.dart';
import 'package:flutter_ai_scrapper/src/schema/field.dart';
import 'package:flutter_ai_scrapper/src/schema/schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAiProvider', () {
    test('extracts scripted data conforming to schema', () async {
      final provider = FakeAiProvider(
        scriptedData: {
          'title': 'Test Item',
          'score': 95,
        },
      );

      final schema = Schema.object({
        'title': const Field.string(),
        'score': const Field.integer(),
      });

      final result = await provider.extract(schema, 'Some input document');

      expect(result.isSuccessful, isTrue);
      expect(result.data['title'], 'Test Item');
      expect(result.data['score'], 95);
      expect(result.confidence, 1.0);
      expect(provider.calls, hasLength(1));
      expect(provider.calls.first.content, 'Some input document');
    });

    test('returns failure when scripted data violates schema', () async {
      final provider = FakeAiProvider(
        scriptedData: {
          'title': 'Test Item',
          // Missing required field 'score'
        },
      );

      final schema = Schema.object(
        {
          'title': const Field.string(),
          'score': const Field.integer(),
        },
        required: ['title', 'score'],
      );

      final result = await provider.extract(schema, 'Doc');

      expect(result.isSuccessful, isFalse);
      expect(result.error, contains('Validation failed'));
    });

    test('supports dynamic onExtract handler and records multiple calls', () async {
      final provider = FakeAiProvider(
        onExtract: (schema, content) {
          if (content.contains('Alpha')) {
            return {'name': 'Alpha Product', 'price': '19.99'};
          }
          return {'name': 'Beta Product', 'price': '29.99'};
        },
      );

      final schema = Schema.object({
        'name': const Field.string(),
        'price': const Field.money(),
      });

      final res1 = await provider.extract(schema, 'Document about Alpha');
      final res2 = await provider.extract(schema, 'Document about Beta');

      expect((res1.data['price'] as Money).amount, 19.99);
      expect((res2.data['price'] as Money).amount, 29.99);
      expect(provider.calls, hasLength(2));
    });

    test('simulates errors gracefully', () async {
      final provider = FakeAiProvider(
        simulatedError: 'Context length exceeded',
      );

      final schema = Schema.object({'test': const Field.string()});
      final result = await provider.extract(schema, 'Input');

      expect(result.isSuccessful, isFalse);
      expect(result.error, 'Context length exceeded');
    });
  });
}
