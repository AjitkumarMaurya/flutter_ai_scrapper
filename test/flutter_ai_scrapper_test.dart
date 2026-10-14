import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:test/test.dart';

class _MockAiProvider extends AiProvider {
  @override
  String get name => 'mock';

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userContent,
    bool jsonMode = false,
  }) async {
    return '```json\n{"product": "Super Widget", "price": 49.99}\n```';
  }
}

void main() {
  group('HtmlDocumentParser (Isolate Execution)', () {
    test('extracts title, markdown, links, JSON-LD, OpenGraph, and selectors',
        () async {
      const sampleHtml = '''
      <!DOCTYPE html>
      <html>
        <head>
          <title>Test Product Page</title>
          <meta property="og:title" content="OG Product Title" />
          <meta name="description" content="Best widget in 2026" />
          <script type="application/ld+json">
            {"@context": "[https://schema.org](https://schema.org)", "@type": "Product", "name": "Super Widget"}
          </script>
          <script>console.log("noise that must be stripped");</script>
        </head>
        <body>
          <nav>Menu link that should be stripped</nav>
          <main>
            <h1>Super Widget</h1>
            <p class="price">\$49.99</p>
            <p>High-efficiency widget built for speed.</p>
            <a href="/specs">View Specs</a>
          </main>
          <footer>Copyright 2026</footer>
        </body>
      </html>
      ''';

      final scrapper = AiScrapper(aiProvider: _MockAiProvider());
      final result = await scrapper.scrapeHtml(
        sampleHtml,
        baseUrl:
            '[https://example.com/shop/item](https://example.com/shop/item)',
        selectors: ['.price', 'h1'],
        aiInstruction: 'Extract product and price',
      );

      expect(result.title, equals('Test Product Page'));
      expect(result.cleanText, isNot(contains('console.log')));
      expect(result.cleanText, isNot(contains('Menu link')));
      expect(result.markdown, contains('# Super Widget'));
      expect(result.selectorMatches['.price'], equals(['\$49.99']));
      expect(result.links,
          contains('[https://example.com/specs](https://example.com/specs)'));
      expect(result.structuredData['openGraph']['title'],
          equals('OG Product Title'));
      expect(result.structuredData['jsonLd'].first['name'],
          equals('Super Widget'));
      expect(result.aiExtractedData?['product'], equals('Super Widget'));
      expect(result.aiExtractedData?['price'], equals(49.99));
    });
  });

  group('Chunker & BM25 Relevance Ranking', () {
    test('splits long text within token budget and ranks relevant chunks first',
        () {
      final para1 = 'Introduction to gardening and flowers. ' * 40;
      final para2 =
          'Pricing details: Enterprise plan costs \$299 per month. ' * 40;
      final para3 = 'Company history and team bios. ' * 40;
      final combined = '$para1\n\n$para2\n\n$para3';

      final chunks = Chunker.chunkText(combined, maxTokensPerChunk: 250);
      expect(chunks.length, greaterThanOrEqualTo(3));

      final ranked =
          Chunker.rankChunksByQuery(chunks, 'pricing enterprise cost', topK: 1);
      expect(ranked.first, contains('Enterprise plan costs'));
    });
  });

  group('CacheStore LRU & TTL', () {
    test('evicts oldest entry when maxEntries is reached and respects TTL',
        () async {
      final cache = CacheStore<String>(
        maxEntries: 2,
        defaultTtl: const Duration(milliseconds: 50),
      );

      cache.set('k1', 'v1');
      cache.set('k2', 'v2');
      // Access k1 so k2 becomes least recently used
      expect(cache.get('k1'), equals('v1'));

      cache.set('k3', 'v3');
      expect(cache.get('k2'), isNull);
      expect(cache.get('k1'), equals('v1'));
      expect(cache.get('k3'), equals('v3'));

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(cache.get('k1'), isNull);
    });
  });
}
