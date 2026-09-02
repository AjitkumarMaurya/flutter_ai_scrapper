import 'dart:io';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StructuralSkeleton', () {
    test('collapses repeated siblings and elides text content', () {
      const html = '''
<html>
  <body>
    <div class="header"><h1>Main Store</h1></div>
    <div class="product-grid">
      <div class="item"><span class="title">Product 1</span><span class="price">\$10</span></div>
      <div class="item"><span class="title">Product 2</span><span class="price">\$20</span></div>
      <div class="item"><span class="title">Product 3</span><span class="price">\$30</span></div>
      <div class="item"><span class="title">Product 4</span><span class="price">\$40</span></div>
      <div class="item"><span class="title">Product 5</span><span class="price">\$50</span></div>
    </div>
    <script>console.log('secret');</script>
  </body>
</html>
''';
      final doc = HtmlDocument.parse(html);
      final skeleton = StructuralSkeleton.build(doc);

      // Repeated siblings collapsed
      expect(skeleton, contains('count="5"'));
      expect(skeleton, contains('repeated 5 times'));
      // Text elided
      expect(skeleton, isNot(contains('Product 1')));
      expect(skeleton, isNot(contains('Main Store')));
      expect(skeleton, contains('_text_'));
      // Script stripped
      expect(skeleton, isNot(contains('console.log')));
    });

    test('produces skeleton under 1,500 tokens on large catalogue fixture', () {
      final html = File('test/fixtures/commerce_jsonld/page.html').readAsStringSync();
      final doc = HtmlDocument.parse(html);

      final skeleton = StructuralSkeleton.build(doc, maxTokens: 1500);
      final tokens = TokenEstimator.estimate(skeleton);

      expect(tokens, lessThan(1500));
    });
  });
}
