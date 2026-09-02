import 'dart:io';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pipeline Benchmarks & Latency Profiling (7.2)', () {
    final fixtureFile = File('test/fixtures/commerce_jsonld/page.html');
    final rawHtml = fixtureFile.readAsStringSync();
    final rawBytes = rawHtml.length;

    // Benchmark 1: HTML DOM Parsing
    final swParse = Stopwatch()..start();
    const parseIterations = 50;
    for (var i = 0; i < parseIterations; i++) {
      HtmlDocument.parse(rawHtml, url: 'https://shop.example/prod');
    }
    swParse.stop();
    final parseAvgMs = swParse.elapsedMicroseconds / (parseIterations * 1000.0);

    // Benchmark 2: Readability Content Scoring
    final doc = HtmlDocument.parse(rawHtml, url: 'https://shop.example/prod');
    final swRead = Stopwatch()..start();
    const readIterations = 50;
    for (var i = 0; i < readIterations; i++) {
      ReadabilityScorer.extractArticle(doc);
    }
    swRead.stop();
    final readAvgMs = swRead.elapsedMicroseconds / (readIterations * 1000.0);

    // Benchmark 3: Deterministic Structured Metadata Harvest (JSON-LD)
    final schema = Schema.object({
      'name': const Field.string(),
      'price': const Field.money(),
    });
    final swMetadata = Stopwatch()..start();
    const metaIterations = 100;
    for (var i = 0; i < metaIterations; i++) {
      StructuredMapper.mapToSchema(doc, schema);
    }
    swMetadata.stop();
    final metaAvgMs = swMetadata.elapsedMicroseconds / (metaIterations * 1000.0);

    // Benchmark 4: Pure CSS Recipe Runner Execution
    final recipe = Recipe(
      id: 'bench_rec',
      host: 'shop.example',
      schemaHash: Recipe.hashSchema(schema),
      fields: {
        'name': const FieldSelector(selector: 'h1'),
        'price': const FieldSelector(selector: 'span.price'),
      },
    );
    final swRecipe = Stopwatch()..start();
    const recipeIterations = 200;
    for (var i = 0; i < recipeIterations; i++) {
      RecipeRunner.run(recipe, doc, schema);
    }
    swRecipe.stop();
    final recipeAvgMs = swRecipe.elapsedMicroseconds / (recipeIterations * 1000.0);

    // Benchmark 5: Token Reduction Ratio
    final markdown = MarkdownWriter.convert(doc);
    final markdownBytes = markdown.length;
    final reductionPct = (1.0 - (markdownBytes / rawBytes)) * 100;

    // Assert key performance invariants
    expect(recipeAvgMs, lessThan(2.0), reason: 'Recipe execution must be sub-2ms');
    expect(metaAvgMs, lessThan(5.0), reason: 'Deterministic JSON-LD mapping must be sub-5ms');
    expect(reductionPct, greaterThan(60.0), reason: 'Token reduction must exceed 60%');

    print('''
----------------------------------------------------
BENCHMARK RESULTS:
  1. DOM Parsing:                ${parseAvgMs.toStringAsFixed(2)} ms / page
  2. Readability Scoring:        ${readAvgMs.toStringAsFixed(2)} ms / page
  3. JSON-LD Harvest (Tier 1):   ${metaAvgMs.toStringAsFixed(3)} ms / page
  4. Recipe Pure-CSS (Tier 4):   ${recipeAvgMs.toStringAsFixed(3)} ms / page
  5. Context Token Reduction:    ${reductionPct.toStringAsFixed(1)}% savings
----------------------------------------------------
''');
  });
}
