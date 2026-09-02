import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Natural-Language Planner', () {
    test('infers object schemas with appropriate field types', () async {
      final p1 = await Planner.plan('Extract product name and price');
      expect(p1.isList, isFalse);
      expect(p1.schema, isA<ObjectSchema>());
      final obj1 = p1.schema as ObjectSchema;
      expect(obj1.properties.containsKey('name'), isTrue);
      expect(obj1.properties['price'], isA<Field>());

      final p2 = await Planner.plan('Get the article title, author, and published date');
      expect(p2.isList, isFalse);
      final obj2 = p2.schema as ObjectSchema;
      expect(obj2.properties.containsKey('title'), isTrue);
      expect(obj2.properties.containsKey('author'), isTrue);
      expect(obj2.properties.containsKey('date'), isTrue);
    });

    test('infers list schemas with cardinality from query keywords', () async {
      final p1 = await Planner.plan('Extract all products with price and rating');
      expect(p1.isList, isTrue);
      expect(p1.schema, isA<ListSchema>());
      final list1 = p1.schema as ListSchema;
      expect(list1.itemSchema, isA<ObjectSchema>());
      final itemObj = list1.itemSchema as ObjectSchema;
      expect(itemObj.properties.containsKey('price'), isTrue);
      expect(itemObj.properties.containsKey('rating'), isTrue);

      final p2 = await Planner.plan('List of job openings with title and apply url');
      expect(p2.isList, isTrue);
      expect(p2.schema, isA<ListSchema>());
    });

    test('verifies 10 sample questions produce usable schemas with visible plan', () async {
      final queries = [
        'extract all products with price and rating',
        'get this article title and author',
        'list of jobs with title and link',
        'find the company revenue and description',
        'extract all events with date and title',
        'get the recipe title and cooking time',
        'extract product name, price, and sku',
        'find all reviews with rating and summary',
        'get the hotel room price and details',
        'list of news headlines with published date',
      ];

      for (final query in queries) {
        final plan = await Planner.plan(query);
        expect(plan.schema, isNotNull);
        expect(plan.intent, isNotEmpty);
        expect(plan.intent.length, greaterThan(10));
      }
    });
  });
}
