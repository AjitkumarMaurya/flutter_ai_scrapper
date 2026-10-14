import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/scraper_exceptions.dart';
import '../ai_provider.dart';

class AnthropicProvider extends AiProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  AnthropicProvider({
    required this.apiKey,
    this.model = 'claude-3-5-haiku-latest',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'anthropic:$model';

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userContent,
    bool jsonMode = false,
  }) async {
    final response = await _client.post(
      Uri.parse(
          '[https://api.anthropic.com/v1/messages](https://api.anthropic.com/v1/messages)'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 4096,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userContent},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw AiExtractionException(
        'Anthropic API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final contentList = decoded['content'] as List<dynamic>?;
    if (contentList == null || contentList.isEmpty) {
      throw const AiExtractionException('Anthropic returned empty content');
    }

    return (contentList.first['text'] as String?) ?? '';
  }
}
