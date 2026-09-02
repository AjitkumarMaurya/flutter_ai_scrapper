import 'package:flutter_ai_scrapper/src/ai/tool_bridge.dart';
import 'package:flutter_ai_scrapper/src/schema/field.dart';
import 'package:flutter_ai_scrapper/src/schema/schema.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolBridge', () {
    test('converts Schema to Tool with Draft-07 JSON Schema parameters', () {
      final schema = Schema.object({
        'name': const Field.string(description: 'Product name'),
        'price': const Field.number(description: 'Price in USD'),
      }, title: 'ProductInfo', description: 'Extract product attributes');

      final tool = ToolBridge.schemaToTool(schema);

      expect(tool.name, 'productinfo');
      expect(tool.description, 'Extract product attributes');
      expect(tool.parameters['type'], 'object');
      expect(tool.parameters['properties'], contains('name'));
      expect(tool.parameters['properties'], contains('price'));
    });

    test('parses arguments from FunctionCallResponse', () {
      const response = FunctionCallResponse(
        name: 'productinfo',
        args: {'name': 'Ergonomic Desk', 'price': 399.0},
      );

      final parsed = ToolBridge.parseFunctionArgs(response);

      expect(parsed, isNotNull);
      expect(parsed!['name'], 'Ergonomic Desk');
      expect(parsed['price'], 399.0);
    });

    test('merges arguments from ParallelFunctionCallResponse', () {
      const response = ParallelFunctionCallResponse(calls: [
        FunctionCallResponse(name: 'part1', args: {'title': 'Guide'}),
        FunctionCallResponse(name: 'part2', args: {'rating': 4.8}),
      ]);

      final parsed = ToolBridge.parseFunctionArgs(response);

      expect(parsed, isNotNull);
      expect(parsed!['title'], 'Guide');
      expect(parsed['rating'], 4.8);
    });

    test('parses JSON from markdown code fence fallback', () {
      const prose = '''
Here is the extracted information you requested:
```json
{
  "title": "Clean Code",
  "pages": 464
}
```
Let me know if you need anything else!
''';

      final parsed = ToolBridge.parseJsonFromProse(prose);

      expect(parsed, isNotNull);
      expect(parsed['title'], 'Clean Code');
      expect(parsed['pages'], 464);
    });

    test('parses raw bracketed JSON from conversational prose', () {
      const prose =
          'I found this item: {"sku": "A123", "available": true}. Hope this helps.';

      final parsed = ToolBridge.parseJsonFromProse(prose);

      expect(parsed, isNotNull);
      expect(parsed['sku'], 'A123');
      expect(parsed['available'], true);
    });
  });
}
