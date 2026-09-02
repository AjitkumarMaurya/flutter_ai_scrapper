import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

class SampleProduct {
  SampleProduct({required this.title, required this.price});

  factory SampleProduct.fromJson(Map<String, dynamic> json) => SampleProduct(
        title: json['title'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
      );

  final String title;
  final double price;
}

void main() {
  group('DataCodecs & HarvestResultCodecs', () {
    final sampleHarvest = StructuredHarvestResult(
      data: {
        'title': 'Mechanical Keyboard',
        'price': 129.99,
        'author': {'name': 'John Doe', 'company': 'Keyboards Inc.'},
      },
      coverage: const ExtractionCoverage(
        satisfiedFields: {
          'title': ExtractionSource.jsonLd,
          'price': ExtractionSource.recipe,
        },
        missingFields: [],
      ),
      validation: const ValidationResult(isValid: true),
    );

    test('toJsonString serializes data with and without provenance', () {
      final withoutProv = sampleHarvest.toJsonString(includeProvenance: false);
      expect(withoutProv, contains('Mechanical Keyboard'));
      expect(withoutProv, isNot(contains('_provenance')));

      final withProv = sampleHarvest.toJsonString(includeProvenance: true);
      expect(withProv, contains('_provenance'));
      expect(withProv, contains('"jsonLd"'));
      expect(withProv, contains('"recipe"'));
    });

    test('toCsv exports RFC 4180 CSV with flattened fields and escaping', () {
      final csv = sampleHarvest.toCsv();
      final lines = csv.trim().split('\n');

      expect(lines, hasLength(2)); // Header + 1 row
      expect(lines[0], 'title,price,author.name,author.company');
      expect(lines[1], 'Mechanical Keyboard,129.99,John Doe,Keyboards Inc.');
    });

    test('toCsv correctly escapes commas, quotes, and newlines', () {
      final data = {
        'items': [
          {'desc': 'Item with, comma', 'note': 'Line 1\nLine 2', 'quote': 'Say "Hello"'},
        ]
      };
      final csv = DataCodecs.toCsv(data);

      expect(csv, contains('"Item with, comma"'));
      expect(csv, contains('"Line 1\nLine 2"'));
      expect(csv, contains('"Say ""Hello"""'));
    });

    test('toMarkdownTable formats data as clean GFM markdown table', () {
      final md = sampleHarvest.toMarkdownTable();

      expect(md, contains('| title | price | author.name | author.company |'));
      expect(md, contains('| --- | --- | --- | --- |'));
      expect(md, contains('| Mechanical Keyboard | 129.99 | John Doe | Keyboards Inc. |'));
    });

    test('toTyped deserializes harvest data into typed domain model', () {
      final product = sampleHarvest.toTyped<SampleProduct>(SampleProduct.fromJson);

      expect(product.title, 'Mechanical Keyboard');
      expect(product.price, 129.99);
    });
  });
}
