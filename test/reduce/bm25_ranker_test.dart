import 'dart:io';

import 'package:flutter_ai_scrapper/src/dom/html_document.dart';
import 'package:flutter_ai_scrapper/src/reduce/bm25_ranker.dart';
import 'package:flutter_ai_scrapper/src/reduce/chunker.dart';
import 'package:flutter_ai_scrapper/src/reduce/markdown_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bm25Ranker', () {
    test('ranks chunk containing the target query in the top 3 across corpus fixtures', () {
      // Map of fixture name -> query and expected text needle that MUST be in top 3 ranked chunks
      const testCases = {
        'commerce_jsonld': {
          'query': 'warranty specifications material',
          'needle': '8z pellicle',
        },
        'commerce_microdata': {
          'query': 'features rapid boil',
          'needle': 'rapid boil',
        },
        'commerce_nested_grid': {
          'query': 'card alpha product',
          'needle': 'alpha',
        },
        'article_news': {
          'query': 'coastal shoreline sea defence',
          'needle': 'councils',
        },
        'article_entities': {
          'query': 'prices survey culture',
          'needle': 'prices',
        },
        'docs_reference': {
          'query': 'parameter configuration options timeout',
          'needle': 'timeout',
        },
        'jobs_listing': {
          'query': 'senior flutter engineer',
          'needle': 'berlin',
        },
        'jobs_table': {
          'query': 'department role location engineer',
          'needle': 'engineer',
        },
        'article_no_metadata': {
          'query': 'fallback chain gracefully',
          'needle': 'gracefully',
        },
        'malformed_soup': {
          'query': 'orphan cell unclosed',
          'needle': 'orphan',
        },
      };

      var top3Matches = 0;
      var totalEvaluated = 0;

      for (final entry in testCases.entries) {
        final fixtureName = entry.key;
        final query = entry.value['query']!;
        final needle = entry.value['needle']!.toLowerCase();

        final htmlFile = File('test/fixtures/$fixtureName/page.html');
        if (!htmlFile.existsSync()) continue;

        final html = htmlFile.readAsStringSync();
        final doc = HtmlDocument.parse(html);
        final md = MarkdownWriter.convert(doc);

        final chunks = Chunker.chunk(md, maxTokens: 100, overlapTokens: 20);
        if (chunks.isEmpty) continue;

        totalEvaluated++;
        final ranked = Bm25Ranker.rank(chunks, query);

        // Check if any of the top 3 chunks contain the needle
        final top3 = ranked.take(3);
        final found = top3.any((r) => r.chunk.text.toLowerCase().contains(needle));
        if (found) {
          top3Matches++;
        }
      }

      expect(totalEvaluated, greaterThanOrEqualTo(8));
      // Acceptance criterion: >= 8 / 10 fixtures rank target chunk in top 3
      expect(top3Matches, greaterThanOrEqualTo(8));
    });
  });
}
