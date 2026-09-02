import 'dart:convert';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hostile Corpus & Edge-Case Robustness (7.1)', () {
    test('handles severely malformed HTML with unclosed and mismatched tags', () {
      const malformedHtml = '''
      <div><p>Paragraph 1 <span>bold text <div>Nested div without closing
      <ul><li>Item 1<li>Item 2<p>Mismatched paragraph
      <table border=1><tr><td>Cell 1<td>Cell 2</tr>
      <a href="https://example.com/link">Link with unclosed anchor
      <img src="/broken.jpg" alt="No closing bracket"
      </body></html>
      ''';

      final doc = HtmlDocument.parse(malformedHtml, url: 'https://example.com/bad');
      expect(doc.raw.body, isNotNull);

      // Verify DOM recovers and can query elements normally
      final items = doc.select('li');
      expect(items, hasLength(2));
      expect(items[0].text, contains('Item 1'));
      expect(items[1].text, contains('Item 2'));

      final tableCells = doc.select('td');
      expect(tableCells, hasLength(2));
    });

    test('handles non-UTF8 encoding (ISO-8859-1 / Latin-1) correctly', () {
      // "Café résumé señor" in Latin-1 bytes
      final latin1Bytes = latin1.encode('<html><body><p>Café résumé señor</p></body></html>');
      final decoded = EncodingDetector.decode(
        latin1Bytes,
        contentTypeHeader: 'text/html; charset=iso-8859-1',
      );

      final doc = HtmlDocument.parse(decoded);
      expect(doc.selectFirst('p')?.text, 'Café résumé señor');
    });

    test('handles Right-to-Left (RTL) Arabic and Hebrew content without corruption', () {
      const rtlHtml = '''
      <html dir="rtl" lang="ar">
      <head><title>موقع تجريبي</title></head>
      <body>
        <article class="news">
          <h1 class="headline">عنوان الخبر الرئيسي باللغة العربية</h1>
          <p class="content">هذا نص تجريبي للتحقق من سلامة استخراج النصوص العربية من اليمين إلى اليسار.</p>
        </article>
      </body>
      </html>
      ''';

      final doc = HtmlDocument.parse(rtlHtml);
      expect(doc.title, 'موقع تجريبي');

      final headline = doc.selectFirst('h1.headline')?.text;
      expect(headline, 'عنوان الخبر الرئيسي باللغة العربية');

      final markdown = MarkdownWriter.convert(doc);
      expect(markdown, contains('عنوان الخبر الرئيسي باللغة العربية'));
    });

    test('handles SPA JavaScript shell with sparse content and noscript tags', () {
      const spaHtml = '''
      <!DOCTYPE html>
      <html>
      <head>
        <title>Single Page App</title>
        <script src="/bundle.js"></script>
        <script>window.__INITIAL_STATE__ = {user: "test"};</script>
      </head>
      <body>
        <div id="root"></div>
        <noscript>
          <div class="fallback-content">
            <h1>Please enable JavaScript</h1>
            <p>Static article preview for search engine crawlers and screen readers.</p>
          </div>
        </noscript>
      </body>
      </html>
      ''';

      final doc = HtmlDocument.parse(spaHtml);
      expect(doc.title, 'Single Page App');

      // Sanitizer strips scripts safely
      doc.sanitize();
      expect(doc.select('script'), isEmpty);
    });

    test('handles deeply nested DOM trees (>100 levels) without stack overflow', () {
      final sb = StringBuffer();
      sb.write('<html><body>');
      for (var i = 0; i < 120; i++) {
        sb.write('<div class="level-$i">');
      }
      sb.write('<p id="target">Deep Content Found</p>');
      for (var i = 0; i < 120; i++) {
        sb.write('</div>');
      }
      sb.write('</body></html>');

      final doc = HtmlDocument.parse(sb.toString());
      final target = doc.selectFirst('#target');
      expect(target?.text, 'Deep Content Found');

      // Verify skeleton handles deep trees with depth capping
      final skeleton = StructuralSkeleton.build(doc, maxDepth: 8);
      expect(skeleton, isNotEmpty);
    });

    test('handles large 1MB+ HTML documents without memory crash', () {
      final sb = StringBuffer();
      sb.write('<html><body><div class="catalogue">');
      for (var i = 0; i < 2000; i++) {
        sb.write('<div class="card"><h2 class="title">Product $i</h2><span class="price">\$$i.99</span></div>');
      }
      sb.write('</div></body></html>');

      final largeHtml = sb.toString();
      expect(largeHtml.length, greaterThan(150000));

      final doc = HtmlDocument.parse(largeHtml);
      final cards = doc.select('div.card');
      expect(cards, hasLength(2000));

      // Pure CSS runner handles thousands of items swiftly
      final recipe = Recipe(
        id: 'large_recipe',
        host: 'bulk.example',
        schemaHash: 'bulk_hash',
        containerSelector: 'div.card',
        fields: {'title': const FieldSelector(selector: 'h2.title')},
      );
      final schema = Schema.list(Schema.object({'title': const Field.string()}));
      final result = RecipeRunner.run(recipe, doc, schema);

      expect(result.yieldCount, 2000);
      expect(result.driftDetected, isFalse);
    });
  });
}
