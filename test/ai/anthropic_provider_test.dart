import 'dart:convert';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AnthropicProvider', () {
    test('extracts structured data using native tool_use block', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, endsWith('/v1/messages'));
        expect(request.headers['x-api-key'], 'anthropic-test-key');
        expect(request.headers['anthropic-version'], '2023-06-01');

        final reqJson = jsonDecode(request.body) as Map<String, dynamic>;
        expect(reqJson['tools'], isNotEmpty);
        expect(reqJson['tool_choice']?['type'], 'tool');

        final responseBody = {
          'id': 'msg_123',
          'type': 'message',
          'role': 'assistant',
          'content': [
            {
              'type': 'tool_use',
              'id': 'toolu_01',
              'name': 'extract_data',
              'input': {
                'title': 'Mechanical Keyboard',
                'price': '129.99',
              },
            },
          ],
          'usage': {'input_tokens': 200, 'output_tokens': 45},
        };

        return http.Response(jsonEncode(responseBody), 200);
      });

      final provider = AnthropicProvider(
        apiKey: 'anthropic-test-key',
        model: 'claude-3-5-haiku-20241022',
        client: mockClient,
      );

      final schema = Schema.object({
        'title': const Field.string(),
        'price': const Field.money(),
      });

      final result = await provider.extract(schema, 'Product text');

      expect(result.isSuccessful, isTrue);
      expect(result.data['title'], 'Mechanical Keyboard');
      expect((result.data['price'] as Money).amount, 129.99);
      expect(result.usage?.promptTokens, 200);
      expect(result.usage?.completionTokens, 45);
    });

    test('performs retry repair pass when validation initially fails', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          // Missing required field
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'type': 'tool_use',
                  'id': 'toolu_1',
                  'name': 'extract_data',
                  'input': {'title': 'Incomplete'},
                },
              ],
              'usage': {'input_tokens': 150, 'output_tokens': 20},
            }),
            200,
          );
        } else {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'type': 'tool_use',
                  'id': 'toolu_2',
                  'name': 'extract_data',
                  'input': {'title': 'Complete', 'price': '49.99'},
                },
              ],
              'usage': {'input_tokens': 180, 'output_tokens': 30},
            }),
            200,
          );
        }
      });

      final provider = AnthropicProvider(
        apiKey: 'key',
        client: mockClient,
      );

      final schema = Schema.object(
        {
          'title': const Field.string(),
          'price': const Field.money(),
        },
        required: ['title', 'price'],
      );

      final result = await provider.extract(schema, 'Content');

      expect(callCount, 2);
      expect(result.isSuccessful, isTrue);
      expect((result.data['price'] as Money).amount, 49.99);
    });

    test('streams tokens using content_block_delta SSE format', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        final sseData = [
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}\n\n',
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":" Claude"}}\n\n',
        ];

        final stream = Stream.fromIterable(
          sseData.map((s) => utf8.encode(s)),
        );

        return http.StreamedResponse(stream, 200);
      });

      final provider = AnthropicProvider(
        apiKey: 'key',
        client: mockClient,
      );

      final tokens = await provider.stream('Hello').toList();
      expect(tokens.join(''), 'Hello Claude');
    });

    test('throws HttpException on API error with status code', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Rate limit reached', 429);
      });

      final provider = AnthropicProvider(
        apiKey: 'key',
        client: mockClient,
      );

      final schema = Schema.object({'title': const Field.string()});

      expect(
        () => provider.extract(schema, 'Text'),
        throwsA(isA<HttpException>().having((e) => e.statusCode, 'statusCode', 429)),
      );
    });
  });
}
