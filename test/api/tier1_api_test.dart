import 'dart:io';

import 'package:flutter_ai_scrapper/src/api/ai_scrapper.dart';
import 'package:flutter_ai_scrapper/src/schema/field.dart';
import 'package:flutter_ai_scrapper/src/schema/schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiScrapper Tier-1 Public API', () {
    test('ScrapedPage article, markdown, plainText, metadata, links, images, tables', () {
      final html = File('test/fixtures/commerce_jsonld/page.html').readAsStringSync();
      final page = AiScrapper.fromHtml(html, url: 'https://shop.example/products/aeron');

      expect(page.url, 'https://shop.example/products/aeron');
      expect(page.statusCode, 200);

      // 1. Article
      final article = page.article();
      expect(article.title, contains('Aeron Chair'));
      expect(article.markdown, isNotEmpty);
      expect(article.text, contains('Specifications'));

      // 2. Markdown & PlainText
      expect(page.markdown, contains('# Aeron Chair'));
      expect(page.plainText, contains('Aeron Chair'));

      // 3. Metadata
      final meta = page.metadata;
      expect(meta['jsonLd'], isNotEmpty);
      expect(meta['openGraph'], isNotEmpty);

      // 4. Links & Images
      expect(page.links, contains('https://shop.example/chairs'));
      expect(page.images, contains('https://shop.example/img/aeron-front.jpg'));

      // 5. Tables
      expect(page.tables, hasLength(1));
      expect(page.tables.first.headers, ['Attribute', 'Value']);
    });

    test('page.extract(schema) returns complete extraction on structured data', () {
      final html = File('test/fixtures/commerce_jsonld/page.html').readAsStringSync();
      final page = AiScrapper.fromHtml(html, url: 'https://shop.example/products/aeron');

      final productSchema = Schema.object({
        'name': const Field.string(),
        'sku': const Field.string(),
        'price': const Field.money(),
      }, title: 'Product');

      final result = page.extract(productSchema);

      expect(result.isPartial, isFalse);
      expect(result.coverage.isComplete, isTrue);
      expect(result.data['name'], contains('Aeron Chair'));
      expect(result.data['sku'], 'ERG-AER-2024');
      final money = result.data['price'] as Money;
      expect(money.amount, 1395.0);
      expect(money.currency, 'GBP');
    });

    test('page.extract(schema) returns partial: true when fields are missing from structured data', () {
      final html = File('test/fixtures/commerce_microdata/page.html').readAsStringSync();
      final page = AiScrapper.fromHtml(html, url: 'https://shop.example/products/kettle');

      final detailedSchema = Schema.object({
        'name': const Field.string(),
        'price': const Field.money(),
        'warrantyYears': const Field.integer(description: 'Not present in microdata'),
      });

      final result = page.extract(detailedSchema);

      expect(result.isPartial, isTrue);
      expect(result.coverage.isComplete, isFalse);
      expect(result.coverage.missingFields, contains('warrantyYears'));
      expect(result.coverage.satisfiedFields, contains('name'));
      expect(result.coverage.satisfiedFields, contains('price'));
    });
  });
}
