import 'dart:io';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 2 Exit Gate — Token Reduction', () {
    test('measures reduction ratio across all 15 corpus fixtures', () {
      final fixturesDir = Directory('test/fixtures');
      final fixtures = fixturesDir
          .listSync()
          .whereType<Directory>()
          .where((d) => File('${d.path}/page.html').existsSync())
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      expect(fixtures.length, equals(15));

      var totalRawTokens = 0;
      var totalMdTokens = 0;
      var totalArticleTokens = 0;

      for (final dir in fixtures) {
        final html = File('${dir.path}/page.html').readAsStringSync();
        final doc = HtmlDocument.parse(html);
        final md = MarkdownWriter.convert(doc);
        final article = ReadabilityScorer.extractArticle(doc);

        final rawTokens = TokenEstimator.estimate(html);
        final mdTokens = TokenEstimator.estimate(md);
        final articleTokens = TokenEstimator.estimate(article.markdown);

        totalRawTokens += rawTokens;
        totalMdTokens += mdTokens;
        totalArticleTokens += articleTokens;
      }

      expect(totalMdTokens, lessThan(totalRawTokens));
      expect(totalArticleTokens, lessThanOrEqualTo(totalMdTokens));

      // Assert reduction ratio is significant
      final ratio = totalRawTokens / totalMdTokens;
      expect(ratio, greaterThan(1.5));
    });

    test('structured-data path alone satisfies product schema on majority of commerce fixtures', () {
      final fixturesDir = Directory('test/fixtures');
      final commerceFixtures = fixturesDir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.contains('commerce_') && File('${d.path}/page.html').existsSync())
          .toList();

      expect(commerceFixtures.length, greaterThanOrEqualTo(3));

      final productSchema = Schema.object({
        'name': const Field.string(),
        'price': const Field.money(),
      }, title: 'Product');

      var satisfiedCount = 0;

      for (final dir in commerceFixtures) {
        final html = File('${dir.path}/page.html').readAsStringSync();
        final page = AiScrapper.fromHtml(html, url: 'https://fixture.example/product');
        final result = page.extract(productSchema);

        if (!result.isPartial && result.coverage.isComplete) {
          satisfiedCount++;
        }
      }

      // 3 out of 4 commerce fixtures (commerce_jsonld, commerce_microdata, commerce_rdfa)
      // have structured data satisfying the schema completely (zero inference).
      // commerce_nested_grid is a raw HTML grid with no structured data.
      expect(satisfiedCount, greaterThanOrEqualTo(3));
      expect(satisfiedCount / commerceFixtures.length, greaterThan(0.5));
    });
  });
}
