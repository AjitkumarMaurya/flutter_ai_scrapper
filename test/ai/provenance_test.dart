import 'dart:io';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Extraction Provenance & Deterministic Precedence', () {
    test('short-circuits before inference when structured data satisfies schema completely', () async {
      final html = File('test/fixtures/commerce_jsonld/page.html').readAsStringSync();
      final page = AiScrapper.fromHtml(html, url: 'https://shop.example/products/aeron');

      final fakeProvider = FakeAiProvider(
        onExtract: (schema, content) {
          fail('AI provider should NEVER be called when structured data satisfies schema!');
        },
      );

      final productSchema = Schema.object({
        'name': const Field.string(),
        'sku': const Field.string(),
        'price': const Field.money(),
      });

      final result = await page.extractWithAi(productSchema, provider: fakeProvider);

      expect(result.coverage.isComplete, isTrue);
      expect(result.data['name'], contains('Aeron Chair'));
      expect(result.coverage.satisfiedFields['name'], ExtractionSource.jsonLd);
      expect(fakeProvider.calls, isEmpty);
    });

    test('deterministic sources always win over AI when merging fields', () async {
      final html = File('test/fixtures/commerce_jsonld/page.html').readAsStringSync();
      final page = AiScrapper.fromHtml(html, url: 'https://shop.example/products/aeron');

      final fakeProvider = FakeAiProvider(
        onExtract: (schema, content) {
          return {
            // Attempt to overwrite deterministic name and price with wrong AI guess
            'name': 'Fabricated Chair Name by AI',
            'price': '10.00',
            // Missing field that AI actually supplies
            'color': 'Mineral / Polished Aluminum',
          };
        },
      );

      final schema = Schema.object({
        'name': const Field.string(),
        'price': const Field.money(),
        'color': const Field.string(),
      });

      final result = await page.extractWithAi(schema, provider: fakeProvider);

      // Deterministic name & price from JSON-LD MUST win:
      expect(result.data['name'], contains('Aeron Chair'));
      expect((result.data['price'] as Money).amount, 1395.0);
      expect(result.coverage.satisfiedFields['name'], ExtractionSource.jsonLd);
      expect(result.coverage.satisfiedFields['price'], ExtractionSource.jsonLd);

      // Missing field is filled by AI:
      expect(result.data['color'], 'Mineral / Polished Aluminum');
      expect(result.coverage.satisfiedFields['color'], ExtractionSource.ai);
    });
  });
}
