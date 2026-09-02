import 'dart:io';

import 'package:flutter_ai_scrapper/src/dom/html_document.dart';
import 'package:flutter_ai_scrapper/src/schema/field.dart';
import 'package:flutter_ai_scrapper/src/schema/schema.dart';
import 'package:flutter_ai_scrapper/src/structured/json_ld.dart';
import 'package:flutter_ai_scrapper/src/structured/mapper.dart';
import 'package:flutter_ai_scrapper/src/structured/microdata.dart';
import 'package:flutter_ai_scrapper/src/structured/open_graph.dart';
import 'package:flutter_ai_scrapper/src/structured/rdfa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsonLdHarvester', () {
    test('harvests JSON-LD and flattens @graph', () {
      const html = '''
      <!DOCTYPE html>
      <html><head>
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@graph": [
          {"@type": "Organization", "name": "Acme Corp"},
          {"@type": "Product", "name": "Anvil", "offers": {"@type": "Offer", "price": "49.99"}}
        ]
      }
      </script>
      </head><body></body></html>
      ''';
      final doc = HtmlDocument.parse(html);
      final items = JsonLdHarvester.extract(doc);

      expect(items, hasLength(2));
      expect(items[0]['@type'], 'Organization');
      expect(items[1]['@type'], 'Product');
      expect(items[1]['name'], 'Anvil');
    });

    test('ignores malformed JSON-LD without throwing', () {
      const html = '''
      <html><head>
      <script type="application/ld+json">NOT VALID JSON {</script>
      <script type="application/ld+json">{"@type": "Book", "name": "Valid"}</script>
      </head><body></body></html>
      ''';
      final doc = HtmlDocument.parse(html);
      final items = JsonLdHarvester.extract(doc);

      expect(items, hasLength(1));
      expect(items.first['name'], 'Valid');
    });
  });

  group('MicrodataHarvester', () {
    test('harvests microdata items with nested scopes and attributes', () {
      const html = '''
      <div itemscope itemtype="https://schema.org/Product">
        <h1 itemprop="name">Hammer</h1>
        <div itemprop="offers" itemscope itemtype="https://schema.org/Offer">
          <span itemprop="price">15.00</span>
          <meta itemprop="priceCurrency" content="USD">
        </div>
      </div>
      ''';
      final doc = HtmlDocument.parse(html);
      final items = MicrodataHarvester.extract(doc);

      expect(items, hasLength(1));
      final product = items.first;
      expect(product['@type'], 'Product');
      expect(product['name'], 'Hammer');
      final offers = product['offers'] as Map<String, dynamic>;
      expect(offers['price'], '15.00');
      expect(offers['priceCurrency'], 'USD');
    });
  });

  group('RdfaHarvester', () {
    test('harvests RDFa Lite properties', () {
      const html = '''
      <div vocab="https://schema.org/" typeof="Product">
        <h1 property="name">Super Screwdriver</h1>
        <span property="sku">SCREW-123</span>
        <div property="offers" typeof="Offer">
          <span property="price">9.99</span>
          <meta property="priceCurrency" content="EUR">
        </div>
      </div>
      ''';
      final doc = HtmlDocument.parse(html);
      final items = RdfaHarvester.extract(doc);

      expect(items, hasLength(1));
      final product = items.first;
      expect(product['@type'], 'Product');
      expect(product['name'], 'Super Screwdriver');
      expect(product['sku'], 'SCREW-123');
      final offers = product['offers'] as Map<String, dynamic>;
      expect(offers['price'], '9.99');
      expect(offers['priceCurrency'], 'EUR');
    });
  });

  group('OpenGraphHarvester', () {
    test('harvests OpenGraph, Twitter and canonical tags', () {
      const html = '''
      <head>
        <meta property="og:title" content="OG Title">
        <meta property="og:image" content="/img/cover.jpg">
        <meta name="twitter:card" content="summary_large_image">
        <link rel="canonical" href="https://example.com/page">
      </head>
      ''';
      final doc = HtmlDocument.parse(html, url: 'https://example.com/sub/index.html');
      final meta = OpenGraphHarvester.extract(doc);

      expect(meta['og:title'], 'OG Title');
      expect(meta['og:image'], 'https://example.com/img/cover.jpg');
      expect(meta['twitter:card'], 'summary_large_image');
      expect(meta['canonical'], 'https://example.com/page');
    });
  });

  group('StructuredMapper on commerce fixtures', () {
    test('satisfies standard product schema on commerce_jsonld fixture with zero AI', () {
      final html = File('test/fixtures/commerce_jsonld/page.html').readAsStringSync();
      final doc = HtmlDocument.parse(html, url: 'https://shop.example/products/aeron-remastered');

      final productSchema = Schema.object({
        'name': const Field.string(description: 'Product name'),
        'sku': const Field.string(description: 'Product SKU'),
        'price': const Field.money(description: 'Product price and currency'),
      }, title: 'Product');

      final result = StructuredMapper.mapToSchema(doc, productSchema);

      expect(result.coverage.isComplete, isTrue);
      expect(result.isPartial, isFalse);
      expect(result.data['name'], contains('Aeron Chair'));
      expect(result.data['sku'], 'ERG-AER-2024');
      final price = result.data['price'] as Money;
      expect(price.amount, 1395.0);
      expect(price.currency, 'GBP');
      expect(result.coverage.satisfiedFields['name'], ExtractionSource.jsonLd);
      expect(result.coverage.satisfiedFields['price'], ExtractionSource.jsonLd);
    });

    test('satisfies standard product schema on commerce_microdata fixture with zero AI', () {
      final html = File('test/fixtures/commerce_microdata/page.html').readAsStringSync();
      final doc = HtmlDocument.parse(html, url: 'https://shop.example/products/kettle');

      final productSchema = Schema.object({
        'name': const Field.string(description: 'Product name'),
        'sku': const Field.string(description: 'Product SKU'),
        'price': const Field.money(description: 'Product price and currency'),
      }, title: 'Product');

      final result = StructuredMapper.mapToSchema(doc, productSchema);

      expect(result.coverage.isComplete, isTrue);
      expect(result.isPartial, isFalse);
      expect(result.data['name'], 'Stainless Kettle 1.7L');
      expect(result.data['sku'], 'KTL-17-SS');
      final price = result.data['price'] as Money;
      expect(price.amount, 49.99);
      expect(price.currency, 'EUR');
      expect(result.coverage.satisfiedFields['price'], ExtractionSource.microdata);
    });
  });
}
