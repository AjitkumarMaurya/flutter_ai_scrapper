import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecipeRunner', () {
    test('extracts list data with pure CSS selectors and zero AI', () {
      const html = '''
<html><body>
  <ul class="jobs">
    <li class="job-card"><span class="title">Flutter Engineer</span><a class="apply" href="/apply/1">Apply</a></li>
    <li class="job-card"><span class="title">Dart Specialist</span><a class="apply" href="/apply/2">Apply</a></li>
  </ul>
</body></html>
''';
      final doc = HtmlDocument.parse(html, url: 'https://jobs.example');

      final recipe = Recipe(
        id: 'job_recipe',
        host: 'jobs.example',
        schemaHash: 'job_hash',
        containerSelector: 'ul.jobs li.job-card',
        fields: {
          'title': const FieldSelector(selector: 'span.title'),
          'applyUrl': const FieldSelector(selector: 'a.apply', attribute: 'href'),
        },
      );

      final schema = Schema.list(
        Schema.object({
          'title': const Field.string(),
          'applyUrl': const Field.string(),
        }),
      );

      final runResult = RecipeRunner.run(recipe, doc, schema);

      expect(runResult.driftDetected, isFalse);
      expect(runResult.yieldCount, 2);

      final items = runResult.harvestResult.data['items'] as List;
      expect(items, hasLength(2));
      expect(items[0]['title'], 'Flutter Engineer');
      expect(items[0]['applyUrl'], '/apply/1');
      expect(items[1]['title'], 'Dart Specialist');
      expect(items[1]['applyUrl'], '/apply/2');
      expect(runResult.harvestResult.coverage.satisfiedFields['items'], ExtractionSource.recipe);
    });

    test('extracts single object data with regex parsing', () {
      const html = '''
<html><body>
  <div class="product">
    <h1 id="prod-name">Pro Laptop 16-inch</h1>
    <div class="meta">Price: \$1,999.00 USD (In Stock)</div>
  </div>
</body></html>
''';
      final doc = HtmlDocument.parse(html);

      final recipe = Recipe(
        id: 'prod_recipe',
        host: 'shop.example',
        schemaHash: 'prod_hash',
        fields: {
          'name': const FieldSelector(selector: 'h1#prod-name'),
          'price': const FieldSelector(
            selector: 'div.meta',
            regex: r'Price:\s*(\$[0-9,]+\.[0-9]{2})',
          ),
        },
      );

      final schema = Schema.object({
        'name': const Field.string(),
        'price': const Field.money(),
      });

      final runResult = RecipeRunner.run(recipe, doc, schema);

      expect(runResult.driftDetected, isFalse);
      expect(runResult.yieldCount, 2);
      expect(runResult.harvestResult.data['name'], 'Pro Laptop 16-inch');
      expect((runResult.harvestResult.data['price'] as Money).amount, 1999.00);
      expect(runResult.harvestResult.coverage.satisfiedFields['name'], ExtractionSource.recipe);
    });

    test('detects drift when container selector fails to match elements on mutated HTML', () {
      // Structure changed: list now uses div.items instead of ul.jobs
      const mutatedHtml = '''
<html><body>
  <div class="new-job-layout">
    <div class="card">Different Structure</div>
  </div>
</body></html>
''';
      final doc = HtmlDocument.parse(mutatedHtml);

      final recipe = Recipe(
        id: 'job_recipe',
        host: 'jobs.example',
        schemaHash: 'job_hash',
        containerSelector: 'ul.jobs li.job-card',
        fields: {'title': const FieldSelector(selector: 'span.title')},
      );

      final schema = Schema.list(Schema.object({'title': const Field.string()}));
      final runResult = RecipeRunner.run(recipe, doc, schema);

      expect(runResult.driftDetected, isTrue);
      expect(runResult.yieldCount, 0);
    });
  });
}
