import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/scraper_exceptions.dart';
import '../ai_provider.dart';

class OpenAiProvider extends AiProvider {
  final String apiKey;
  final String model;
  final String baseUrl;
  final http.Client _client;

  OpenAiProvider({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    this.baseUrl =
        '[https://api.openai.com/v1/chat/completions](https://api.openai.com/v1/chat/completions)',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'openai:$model';

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userContent,
    bool jsonMode = false,
  }) async {
    final payload = <String, dynamic>{
      'model': model,
      'temperature': 0.1,
      if (jsonMode) 'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContent},
      ],
    };

    final response = await _client.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw AiExtractionException(
        'OpenAI API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const AiExtractionException('OpenAI returned empty choices');
    }

    return (choices.first['message']['content'] as String?) ?? '';
  }
}
