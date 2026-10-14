import 'dart:convert';
import '../core/scraper_exceptions.dart';

abstract class AiProvider {
  String get name;

  /// Sends prompt and scraped context to the AI model and returns the raw text response.
  Future<String> complete({
    required String systemPrompt,
    required String userContent,
    bool jsonMode = false,
  });

  /// Extracts structured JSON map from scraped content using the AI provider.
  Future<Map<String, dynamic>> extractJson({
    required String instruction,
    required String content,
    Map<String, String>? schemaFields,
  }) async {
    final schemaDesc = schemaFields != null && schemaFields.isNotEmpty
        ? '\nRequired JSON keys and types:\n${schemaFields.entries.map((e) => '- "${e.key}": ${e.value}').join('\n')}'
        : '';

    final systemPrompt =
        'You are a precise web data extraction engine. Extract the requested information from the provided webpage content and return ONLY valid JSON.$schemaDesc';

    final response = await complete(
      systemPrompt: systemPrompt,
      userContent: 'Instruction: $instruction\n\nWebpage Content:\n$content',
      jsonMode: true,
    );

    return parseJsonResponse(response);
  }

  static Map<String, dynamic> parseJsonResponse(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } catch (e) {
      // Attempt to locate first '{' and last '}'
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        try {
          final sub = jsonDecode(cleaned.substring(start, end + 1));
          if (sub is Map<String, dynamic>) return sub;
        } catch (_) {}
      }
      throw AiExtractionException(
        'Failed to parse AI response as valid JSON: $raw',
        e,
      );
    }
  }
}
