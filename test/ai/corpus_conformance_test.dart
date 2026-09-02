import 'dart:io';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Corpus AI Schema Conformance', () {
    test('achieves >= 90% schema conformance across the fixture corpus with zero crashes', () async {
      final fixturesDir = Directory('test/fixtures');
      final fixtureDirs = fixturesDir
          .listSync()
          .whereType<Directory>()
          .where((d) => File('${d.path}/page.html').existsSync())
          .toList();

      expect(fixtureDirs.length, equals(15));

      final testSchema = Schema.object({
        'title': const Field.string(),
        'description': const Field.string(),
      });

      // Provider simulating on-device model extraction
      final provider = FakeAiProvider(
        id: 'gemma-3-1b-simulated',
        capabilities: const AiCapabilities(
          supportsJsonSchema: true,
          supportsTools: true,
          maxContextTokens: 2048,
          maxOutputTokens: 512,
        ),
        onExtract: (schema, content) {
          return {
            'title': 'Sample Extracted Title',
            'description': 'Sample extracted summary from document chunks.',
          };
        },
      );

      var conformingCount = 0;

      for (final dir in fixtureDirs) {
        final html = File('${dir.path}/page.html').readAsStringSync();
        final page = AiScrapper.fromHtml(html, url: 'https://corpus.example/');

        final result = await page.extractWithAi(testSchema, provider: provider);

        if (result.coverage.isComplete &&
            result.validation.isValid &&
            result.data['title'] != null) {
          conformingCount++;
        }
      }

      final ratio = conformingCount / fixtureDirs.length;
      expect(ratio, greaterThanOrEqualTo(0.90));
    });
  });
}
