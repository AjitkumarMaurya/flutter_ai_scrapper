import 'dart:convert';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenAiProvider', () {
    test('extracts structured data using json_schema mode', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, endsWith('/chat/completions'));
        expect(request.headers['authorization'], 'Bearer test-api-key');

        final reqJson = jsonDecode(request.body) as Map<String, dynamic>;
        expect(reqJson['response_format']?['type'], 'json_schema');

        final responseBody = {
          'id': 'chatcmpl-123',
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': jsonEncode({
                  'name': 'Ergonomic Desk',
                  'price': '349.99',
                }),
              },
            },
          ],
          'usage': {'prompt_tokens': 120, 'completion_tokens': 35},
        };

        return http.Response(jsonEncode(responseBody), 200);
      });

      final provider = OpenAiProvider(
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        apiKey: 'test-api-key',
        mode: OpenAiStructuredMode.jsonSchema,
        client: mockClient,
      );

      final schema = Schema.object({
        'name': const Field.string(),
        'price': const Field.money(),
      });

      final result = await provider.extract(schema, 'Document text about desk');

      expect(result.isSuccessful, isTrue);
      expect(result.data['name'], 'Ergonomic Desk');
      expect((result.data['price'] as Money).amount, 349.99);
      expect(result.usage?.promptTokens, 120);
      expect(result.usage?.completionTokens, 35);
    });

    test('extracts structured data using tools function calling mode', () async {
      final mockClient = MockClient((request) async {
        final reqJson = jsonDecode(request.body) as Map<String, dynamic>;
        expect(reqJson['tools'], isNotEmpty);
        expect(reqJson['tool_choice']?['type'], 'function');

        final responseBody = {
          'id': 'chatcmpl-456',
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'tool_calls': [
                  {
                    'id': 'call_1',
                    'type': 'function',
                    'function': {
                      'name': 'extract_data',
                      'arguments': jsonEncode({'title': 'Widget Pro', 'rating': 4.9}),
                    },
                  },
                ],
              },
            },
          ],
          'usage': {'prompt_tokens': 150, 'completion_tokens': 40},
        };

        return http.Response(jsonEncode(responseBody), 200);
      });

      final provider = OpenAiProvider(
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o',
        apiKey: 'test-api-key',
        mode: OpenAiStructuredMode.tools,
        client: mockClient,
      );

      final schema = Schema.object({
        'title': const Field.string(),
        'rating': const Field.number(),
      });

      final result = await provider.extract(schema, 'Doc text');

      expect(result.isSuccessful, isTrue);
      expect(result.data['title'], 'Widget Pro');
      expect(result.data['rating'], 4.9);
    });

    test('performs retry repair pass on validation failure', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          // First attempt returns invalid data (price is missing)
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({'name': 'Test Item'}),
                  },
                },
              ],
              'usage': {'prompt_tokens': 100, 'completion_tokens': 20},
            }),
            200,
          );
        } else {
          // Retry repair attempt returns corrected data with price
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({'name': 'Test Item', 'price': '19.99'}),
                  },
                },
              ],
              'usage': {'prompt_tokens': 150, 'completion_tokens': 25},
            }),
            200,
          );
        }
      });

      final provider = OpenAiProvider(
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        apiKey: 'key',
        mode: OpenAiStructuredMode.jsonSchema,
        client: mockClient,
      );

      final schema = Schema.object(
        {
          'name': const Field.string(),
          'price': const Field.money(),
        },
        required: ['name', 'price'],
      );

      final result = await provider.extract(schema, 'Text');

      expect(callCount, 2);
      expect(result.isSuccessful, isTrue);
      expect((result.data['price'] as Money).amount, 19.99);
    });

    test('streams tokens using Server-Sent Events', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        final sseData = [
          'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n',
          'data: {"choices":[{"delta":{"content":" world"}}]}\n\n',
          'data: [DONE]\n\n',
        ];

        final stream = Stream.fromIterable(
          sseData.map((s) => utf8.encode(s)),
        );

        return http.StreamedResponse(stream, 200);
      });

      final provider = OpenAiProvider(
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        apiKey: 'key',
        client: mockClient,
      );

      final chunks = await provider.stream('Say hello').toList();
      expect(chunks.join(''), 'Hello world');
    });

    test('handles HTTP errors properly with status code', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized API Key', 401);
      });

      final provider = OpenAiProvider(
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o',
        apiKey: 'bad-key',
        client: mockClient,
      );

      final schema = Schema.object({'title': const Field.string()});

      expect(
        () => provider.extract(schema, 'Doc'),
        throwsA(isA<HttpException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('identifies local Ollama baseUrl correctly', () {
      final ollamaProvider = OpenAiProvider(
        baseUrl: 'http://localhost:11434/v1',
        model: 'llama3',
      );
      expect(ollamaProvider.capabilities.isLocal, isTrue);
    });
  });
}
