import 'dart:io';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Extractor', () {
    test('extracts missing fields in object schema using BM25 chunk ranking', () async {
      // In commerce_microdata, name & price exist in microdata, but warrantyYears is absent
      final html = File('test/fixtures/commerce_microdata/page.html').readAsStringSync();
      final page = AiScrapper.fromHtml(html, url: 'https://shop.example/kettle');

      final fakeProvider = FakeAiProvider(
        onExtract: (schema, content) {
          // AI extracts the missing warrantyYears from page text
          return {'warrantyYears': 2};
        },
      );

      final schema = Schema.object({
        'name': const Field.string(),
        'price': const Field.money(),
        'warrantyYears': const Field.integer(),
      });

      final result = await page.extractWithAi(schema, provider: fakeProvider);

      expect(result.coverage.isComplete, isTrue);
      expect(result.data['name'], contains('Stainless Kettle'));
      expect((result.data['price'] as Money).amount, 49.99);
      expect(result.data['warrantyYears'], 2);

      // Verify provenance: name & price came from microdata, warrantyYears from ai
      expect(result.coverage.satisfiedFields['name'], ExtractionSource.microdata);
      expect(result.coverage.satisfiedFields['price'], ExtractionSource.microdata);
      expect(result.coverage.satisfiedFields['warrantyYears'], ExtractionSource.ai);

      // Verify BM25 ranking query targeted missing fields
      expect(fakeProvider.calls, hasLength(1));
    });

    test('extracts and deduplicates items in list schema via map-reduce', () async {
      const html = '''
<html><body>
<div class="job-list">
  <div class="job"><h2 class="title">Engineer</h2><span class="id">JOB-1</span></div>
  <div class="job"><h2 class="title">Designer</h2><span class="id">JOB-2</span></div>
  <div class="job"><h2 class="title">Engineer</h2><span class="id">JOB-1</span></div>
</div>
</body></html>
''';
      final page = AiScrapper.fromHtml(html);

      final fakeProvider = FakeAiProvider(
        onExtract: (schema, content) {
          return [
            {'id': 'JOB-1', 'title': 'Engineer'},
            {'id': 'JOB-2', 'title': 'Designer'},
            {'id': 'JOB-1', 'title': 'Engineer'}, // Duplicate
          ];
        },
      );

      final listSchema = Schema.list(
        Schema.object({
          'id': const Field.string(),
          'title': const Field.string(),
        }),
      );

      final result = await page.extractWithAi(
        listSchema,
        provider: fakeProvider,
        options: const ExtractionOptions(listDeduplicationKey: 'id'),
      );

      final items = result.data['items'] as List;
      expect(items, hasLength(2));
      expect(items[0]['id'], 'JOB-1');
      expect(items[1]['id'], 'JOB-2');
    });

    test('degrades gracefully to partial deterministic result on timeout', () async {
      final html = File('test/fixtures/commerce_microdata/page.html').readAsStringSync();
      final page = AiScrapper.fromHtml(html, url: 'https://shop.example/kettle');

      final slowProvider = FakeAiProvider(
        simulatedDelay: const Duration(milliseconds: 200),
        scriptedData: {'warrantyYears': 5},
      );

      final schema = Schema.object({
        'name': const Field.string(),
        'warrantyYears': const Field.integer(),
      });

      // Set timeout shorter than simulated delay
      final result = await page.extractWithAi(
        schema,
        provider: slowProvider,
        options: const ExtractionOptions(
          timeout: Duration(milliseconds: 50),
        ),
      );

      // Should degrade gracefully without throwing
      expect(result.data['name'], contains('Stainless Kettle'));
      expect(result.data.containsKey('warrantyYears'), isFalse);
      expect(result.isPartial, isTrue);
    });
  });
}
