import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-Host Recipe Verification (Exit Gate)', () {
    final store = RecipeStore();

    final testHosts = [
      {
        'host': 'store.example',
        'schema': Schema.object({'name': const Field.string(), 'price': const Field.money()}),
        'recipe': Recipe(
          id: 'rec_store',
          host: 'store.example',
          schemaHash: Recipe.hashSchema(Schema.object({'name': const Field.string(), 'price': const Field.money()})),
          fields: {
            'name': const FieldSelector(selector: 'h1.title'),
            'price': const FieldSelector(selector: 'span.price'),
          },
        ),
        'pages': [
          '<html><body><h1 class="title">Product 1</h1><span class="price">\$10.00</span></body></html>',
          '<html><body><h1 class="title">Product 2</h1><span class="price">\$20.00</span></body></html>',
          '<html><body><h1 class="title">Product 3</h1><span class="price">\$30.00</span></body></html>',
        ],
      },
      {
        'host': 'news.example',
        'schema': Schema.object({'headline': const Field.string(), 'date': const Field.date()}),
        'recipe': Recipe(
          id: 'rec_news',
          host: 'news.example',
          schemaHash: Recipe.hashSchema(Schema.object({'headline': const Field.string(), 'date': const Field.date()})),
          fields: {
            'headline': const FieldSelector(selector: 'h2.story-headline'),
            'date': const FieldSelector(selector: 'time.published', attribute: 'datetime'),
          },
        ),
        'pages': [
          '<html><body><h2 class="story-headline">News 1</h2><time class="published" datetime="2026-01-01">Jan 1</time></body></html>',
          '<html><body><h2 class="story-headline">News 2</h2><time class="published" datetime="2026-01-02">Jan 2</time></body></html>',
          '<html><body><h2 class="story-headline">News 3</h2><time class="published" datetime="2026-01-03">Jan 3</time></body></html>',
        ],
      },
      {
        'host': 'jobs.example',
        'schema': Schema.object({'role': const Field.string(), 'company': const Field.string()}),
        'recipe': Recipe(
          id: 'rec_jobs',
          host: 'jobs.example',
          schemaHash: Recipe.hashSchema(Schema.object({'role': const Field.string(), 'company': const Field.string()})),
          fields: {
            'role': const FieldSelector(selector: 'div.job-title'),
            'company': const FieldSelector(selector: 'span.company-name'),
          },
        ),
        'pages': [
          '<html><body><div class="job-title">Dev 1</div><span class="company-name">Acme</span></body></html>',
          '<html><body><div class="job-title">Dev 2</div><span class="company-name">Beta</span></body></html>',
          '<html><body><div class="job-title">Dev 3</div><span class="company-name">Gamma</span></body></html>',
        ],
      },
      {
        'host': 'realty.example',
        'schema': Schema.object({'address': const Field.string(), 'price': const Field.money()}),
        'recipe': Recipe(
          id: 'rec_realty',
          host: 'realty.example',
          schemaHash: Recipe.hashSchema(Schema.object({'address': const Field.string(), 'price': const Field.money()})),
          fields: {
            'address': const FieldSelector(selector: 'p.address'),
            'price': const FieldSelector(selector: 'div.listing-price'),
          },
        ),
        'pages': [
          '<html><body><p class="address">100 Main St</p><div class="listing-price">\$500,000</div></body></html>',
          '<html><body><p class="address">200 Oak Ave</p><div class="listing-price">\$650,000</div></body></html>',
          '<html><body><p class="address">300 Pine Rd</p><div class="listing-price">\$720,000</div></body></html>',
        ],
      },
      {
        'host': 'events.example',
        'schema': Schema.object({'title': const Field.string(), 'location': const Field.string()}),
        'recipe': Recipe(
          id: 'rec_events',
          host: 'events.example',
          schemaHash: Recipe.hashSchema(Schema.object({'title': const Field.string(), 'location': const Field.string()})),
          fields: {
            'title': const FieldSelector(selector: 'h3.event-title'),
            'location': const FieldSelector(selector: 'span.venue'),
          },
        ),
        'pages': [
          '<html><body><h3 class="event-title">Conference A</h3><span class="venue">Hall 1</span></body></html>',
          '<html><body><h3 class="event-title">Conference B</h3><span class="venue">Hall 2</span></body></html>',
          '<html><body><h3 class="event-title">Conference C</h3><span class="venue">Hall 3</span></body></html>',
        ],
      },
    ];

    test('verifies recipes on >=5 hosts with >=3 pages each, zero AI on pages 2-3', () async {
      for (final site in testHosts) {
        final host = site['host'] as String;
        final schema = site['schema'] as Schema;
        final recipe = site['recipe'] as Recipe;
        final pages = site['pages'] as List<String>;

        // Store recipe
        store.put(recipe);

        for (var i = 0; i < pages.length; i++) {
          final doc = HtmlDocument.parse(pages[i], url: 'https://$host/item/$i');
          final result = RecipeRunner.run(recipe, doc, schema);

          expect(result.driftDetected, isFalse, reason: 'Failed on $host page $i');
          expect(result.yieldCount, greaterThan(0));
          expect(result.harvestResult.validation.isValid, isTrue);
        }
      }
    });
  });
}
