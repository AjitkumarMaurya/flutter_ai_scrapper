import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('page.ask() & Lifecycle Recipes in a Loop', () {
    const page1Html = '''
<html><body>
  <div class="product">
    <h1 class="item-name">Wireless Headphones Pro</h1>
    <span class="item-price">\$199.99</span>
  </div>
</body></html>
''';

    const page2Html = '''
<html><body>
  <div class="product">
    <h1 class="item-name">Studio Monitor Speakers</h1>
    <span class="item-price">\$249.99</span>
  </div>
</body></html>
''';

    test('page 1 synthesizes recipe, page 2 runs with 0 AI tokens, page 3 detects drift', () async {
      final recipeStore = RecipeStore();

      var aiCalls = 0;
      final provider = FakeAiProvider(
        onExtract: (schema, content) {
          aiCalls++;
          if (schema.title == 'synthesize_recipe') {
            return {
              'containerSelector': '',
              'fields': {
                'name': {'selector': 'h1.item-name', 'attribute': 'text'},
                'price': {'selector': 'span.item-price', 'attribute': 'text'},
              },
            };
          }
          // Normal extraction for page 1
          return {
            'name': 'Wireless Headphones Pro',
            'price': '199.99',
          };
        },
      );

      // --- PAGE 1: First visit to shop.example ---
      final page1 = AiScrapper.fromHtml(page1Html, url: 'https://shop.example/headphones');
      final askResult1 = await page1.ask(
        'extract product name and price',
        provider: provider,
        recipeStore: recipeStore,
      );

      expect(askResult1.data['name'], 'Wireless Headphones Pro');
      expect((askResult1.data['price'] as Money).amount, 199.99);
      expect(askResult1.planned.schema, isA<ObjectSchema>());
      expect(aiCalls, greaterThan(0)); // AI was used on page 1

      // Recipe is now cached in store!
      expect(recipeStore.count, 1);

      // --- PAGE 2: Second visit to same host ---
      final aiCallsBeforePage2 = aiCalls;
      final page2 = AiScrapper.fromHtml(page2Html, url: 'https://shop.example/speakers');

      final askResult2 = await page2.ask(
        'extract product name and price',
        provider: provider,
        recipeStore: recipeStore,
      );

      // Successfully extracted from page 2!
      expect(askResult2.data['name'], 'Studio Monitor Speakers');
      expect((askResult2.data['price'] as Money).amount, 249.99);
      expect(askResult2.harvestResult.coverage.satisfiedFields['name'], ExtractionSource.recipe);

      // ZERO AI calls were made for page 2! Pure CSS execution!
      expect(aiCalls, equals(aiCallsBeforePage2));

      // --- PAGE 3: Mutated layout on same host ---
      const page3MutatedHtml = '''
<html><body>
  <section class="redesigned-product">
    <div class="header">New Layout</div>
  </section>
</body></html>
''';
      final page3 = AiScrapper.fromHtml(page3MutatedHtml, url: 'https://shop.example/webcam');

      // The cached recipe will fail on page 3 and drift will trigger AI fallback
      final askResult3 = await page3.ask(
        'extract product name and price',
        provider: provider,
        recipeStore: recipeStore,
      );

      expect(askResult3, isNotNull);
    });
  });
}
