import 'package:flutter_ai_scrapper/src/schema/field.dart';
import 'package:flutter_ai_scrapper/src/schema/schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Field types and coercion', () {
    test('string coercion and validation', () {
      const field = Field.string(minLength: 3, maxLength: 10, pattern: r'^[A-Z]+$');
      expect(field.coerce('  HELLO  '), 'HELLO');
      expect(field.validate('HELLO'), isNull);
      expect(field.validate('HI'), contains('less than minimum'));
      expect(field.validate('TOOLONGSTRING'), contains('exceeds maximum'));
      expect(field.validate('hello'), contains('does not match required pattern'));
    });

    test('number and integer coercion and validation', () {
      const numField = Field.number(minimum: 0, maximum: 100);
      expect(numField.coerce('12.99'), 12.99);
      expect(numField.coerce('1,395.50'), 1395.50);
      expect(numField.validate('50'), isNull);
      expect(numField.validate('-1'), contains('less than minimum'));
      expect(numField.validate('150'), contains('exceeds maximum'));

      const intField = Field.integer(minimum: 1, maximum: 10);
      expect(intField.coerce('5'), 5);
      expect(intField.coerce(5.7), 5);
      expect(intField.validate(5), isNull);
      expect(intField.validate(15), contains('exceeds maximum'));
    });

    test('money coercion preserves real symbols and currencies', () {
      const moneyField = Field.money(defaultCurrency: 'USD');
      final gbp = moneyField.coerce('£1,395.00') as Money?;
      expect(gbp, isNotNull);
      expect(gbp!.amount, 1395.0);
      expect(gbp.currency, 'GBP');

      final eur = moneyField.coerce('€49,99') as Money?;
      expect(eur, isNotNull);
      expect(eur!.amount, 49.99);
      expect(eur.currency, 'EUR');

      final jpy = moneyField.coerce('¥1500') as Money?;
      expect(jpy, isNotNull);
      expect(jpy!.amount, 1500);
      expect(jpy.currency, 'JPY');

      final plain = moneyField.coerce(99.5) as Money?;
      expect(plain, isNotNull);
      expect(plain!.amount, 99.5);
      expect(plain.currency, 'USD');
    });

    test('date coercion parses ISO strings', () {
      const dateField = Field.date();
      final dt = dateField.coerce('2024-01-15T12:00:00Z') as DateTime?;
      expect(dt, isNotNull);
      expect(dt!.year, 2024);
      expect(dt.month, 1);
      expect(dt.day, 15);
    });

    test('bool coercion parses truthy and falsy strings', () {
      const boolField = Field.bool_();
      expect(boolField.coerce('true'), isTrue);
      expect(boolField.coerce('1'), isTrue);
      expect(boolField.coerce('yes'), isTrue);
      expect(boolField.coerce('false'), isFalse);
      expect(boolField.coerce('0'), isFalse);
      expect(boolField.coerce('no'), isFalse);
    });

    test('enum coercion validates allowed choices', () {
      const enumField = Field.enum_(['red', 'green', 'blue']);
      expect(enumField.coerce('green'), 'green');
      expect(enumField.coerce('yellow'), isNull);
      expect(enumField.validate('red'), isNull);
      expect(enumField.validate('purple'), contains('not one of allowed values'));
    });
  });

  group('Schema definition & Draft-07 export', () {
    test('Schema.object produces Draft-07 schema', () {
      final productSchema = Schema.object({
        'name': const Field.string(description: 'Product name'),
        'price': const Field.money(description: 'Product price'),
        'inStock': const Field.bool_(description: 'Availability'),
        'tags': const Schema.list(
          Field.string(),
          description: 'Product tags',
        ),
      }, title: 'Product', description: 'E-commerce product specification');

      final jsonSchema = productSchema.toJsonSchema();
      expect(jsonSchema[r'$schema'], 'http://json-schema.org/draft-07/schema#');
      expect(jsonSchema['type'], 'object');
      expect(jsonSchema['title'], 'Product');
      expect(jsonSchema['description'], 'E-commerce product specification');
      expect(jsonSchema['required'], containsAll(['name', 'price', 'inStock', 'tags']));

      final properties = jsonSchema['properties'] as Map<String, dynamic>;
      expect(properties['name']['type'], 'string');
      expect(properties['price']['type'], 'object');
      expect(properties['price']['properties']['amount']['type'], 'number');
      expect(properties['price']['properties']['currency']['type'], 'string');
      expect(properties['inStock']['type'], 'boolean');
      expect(properties['tags']['type'], 'array');
      expect(properties['tags']['items']['type'], 'string');
      // Subschemas do not duplicate the top-level $schema header
      expect(properties['tags'].containsKey(r'$schema'), isFalse);
    });

    test('Schema.validate validates and coerces valid object payload', () {
      final schema = Schema.object({
        'title': const Field.string(),
        'price': const Field.number(),
        'available': const Field.bool_(),
      });

      final result = schema.validate({
        'title': 'Widget',
        'price': '29.99',
        'available': 'true',
      });

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.coerced, {
        'title': 'Widget',
        'price': 29.99,
        'available': true,
      });
    });

    test('Schema.validate catches missing required fields and type errors', () {
      final schema = Schema.object({
        'title': const Field.string(),
        'count': const Field.integer(),
      });

      final result = schema.validate({
        'title': 'Widget',
        // 'count' missing
      });

      expect(result.isValid, isFalse);
      expect(result.errors['count'], contains('missing'));
    });

    test('Schema.list validates list of objects with nesting', () {
      final schema = Schema.list(
        Schema.object({
          'id': const Field.integer(),
          'name': const Field.string(),
        }),
      );

      final validResult = schema.validate([
        {'id': '1', 'name': 'Alpha'},
        {'id': 2, 'name': 'Beta'},
      ]);

      expect(validResult.isValid, isTrue);
      expect(validResult.coerced, [
        {'id': 1, 'name': 'Alpha'},
        {'id': 2, 'name': 'Beta'},
      ]);

      final invalidResult = schema.validate([
        {'id': 'not-an-int', 'name': 'Gamma'},
      ]);
      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.errors['[0].id'], contains('Cannot coerce'));
    });
  });
}
