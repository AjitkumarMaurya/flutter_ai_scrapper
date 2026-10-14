import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/scraper_exceptions.dart';
import '../ai_provider.dart';

class GeminiProvider extends AiProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  GeminiProvider({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'gemini:$model';

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userContent,
    bool jsonMode = false,
  }) async {
    final uri = Uri.parse(
      '[https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey](https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey)',
    );

    final payload = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userContent}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        if (jsonMode) 'responseMimeType': 'application/json',
      },
    };

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw AiExtractionException(
        'Gemini API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const AiExtractionException('Gemini returned empty candidates');
    }

    final parts = candidates.first['content']['parts'] as List<dynamic>;
    return (parts.first['text'] as String?) ?? '';
  }
}
