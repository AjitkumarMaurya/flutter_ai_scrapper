import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecipeSynthesizer', () {
    const html = '''
<html><body>
  <div class="product-view">
    <h1 class="product-title">Ergonomic Office Chair</h1>
    <span class="price-val">\$299.99</span>
  </div>
</body></html>
''';

    final schema = Schema.object({
      'name': const Field.string(),
      'price': const Field.money(),
    });

    test('synthesizes and self-verifies a valid recipe', () async {
      final doc = HtmlDocument.parse(html, url: 'https://furniture.example/chair');

      final fakeProvider = FakeAiProvider(
        onExtract: (metaSchema, skeleton) {
          return {
            'containerSelector': '',
            'fields': {
              'name': {'selector': 'h1.product-title', 'attribute': 'text'},
              'price': {'selector': 'span.price-val', 'attribute': 'text'},
            },
          };
        },
      );

      final recipe = await RecipeSynthesizer.synthesize(
        doc,
        schema,
        provider: fakeProvider,
      );

      expect(recipe, isNotNull);
      expect(recipe!.host, 'furniture.example');
      expect(recipe.fields['name']?.selector, 'h1.product-title');

      // Verify recipe actually works
      final run = RecipeRunner.run(recipe, doc, schema);
      expect(run.driftDetected, isFalse);
      expect(run.harvestResult.data['name'], 'Ergonomic Office Chair');
      expect((run.harvestResult.data['price'] as Money).amount, 299.99);
    });

    test('rejects candidate recipe that fails self-verification on source page', () async {
      final doc = HtmlDocument.parse(html, url: 'https://furniture.example/chair');

      final faultyProvider = FakeAiProvider(
        onExtract: (metaSchema, skeleton) {
          return {
            'containerSelector': '',
            'fields': {
              // Non-existent selectors that will match 0 elements
              'name': {'selector': 'div.non-existent-header', 'attribute': 'text'},
              'price': {'selector': 'span.wrong-price', 'attribute': 'text'},
            },
          };
        },
      );

      final recipe = await RecipeSynthesizer.synthesize(
        doc,
        schema,
        provider: faultyProvider,
      );

      // Must reject invalid recipe!
      expect(recipe, isNull);
    });
  });
}
