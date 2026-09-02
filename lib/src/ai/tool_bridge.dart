/// Schema-to-Tool bridging for function-calling LLM extraction.
library;

import 'dart:convert';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../schema/schema.dart';

/// Bridges [Schema] to flutter_gemma's [Tool] for function calling and parses responses.
abstract final class ToolBridge {
  /// Converts [schema] into a flutter_gemma [Tool] instance with Draft-07 parameters.
  static Tool schemaToTool(
    Schema schema, {
    String? name,
    String? description,
  }) {
    final effectiveName =
        name ?? _sanitizeToolName(schema.title ?? 'extract_data');
    final effectiveDesc = description ??
        schema.description ??
        'Extract structured data conforming to the schema from the provided document content.';

    return Tool(
      name: effectiveName,
      description: effectiveDesc,
      parameters: schema.toJsonSchema(),
    );
  }

  /// Extracts structured arguments from a flutter_gemma [ModelResponse].
  ///
  /// Merges parallel calls if [ParallelFunctionCallResponse] is returned.
  /// Returns `null` if the model produced text or reasoning without calling the tool.
  static Map<String, dynamic>? parseFunctionArgs(ModelResponse response) {
    if (response is FunctionCallResponse) {
      return response.args;
    }
    if (response is ParallelFunctionCallResponse) {
      final merged = <String, dynamic>{};
      for (final call in response.calls) {
        merged.addAll(call.args);
      }
      return merged;
    }
    return null;
  }

  /// Builds a fallback extraction prompt with JSON Schema constraints for models
  /// that do not support native function calling.
  static String buildJsonPrompt(Schema schema, String content) {
    final schemaStr = const JsonEncoder.withIndent('  ').convert(
      schema.toJsonSchema(),
    );
    return '''
You are a precise data extraction assistant.
Extract information from the document below and output ONLY a valid JSON object strictly matching this JSON Schema:

$schemaStr

Document:
$content

Output only the JSON object, with no explanation, markdown formatting, or preamble.
''';
  }

  /// Builds a retry feedback prompt including previous validation errors.
  static String buildRetryPrompt(
    Schema schema,
    String content,
    List<String> errors,
  ) {
    return '''
The previous extraction had validation errors:
- ${errors.join('\n- ')}

Please re-extract the data from the document below, correcting these errors:
$content
''';
  }

  /// Parses JSON from free-form text or Markdown code blocks as a fallback.
  static dynamic parseJsonFromProse(String text) {
    final trimmed = text.trim();

    // 1. Direct JSON parse
    try {
      return jsonDecode(trimmed);
    } catch (_) {}

    // 2. Strip Markdown code fences ```json ... ```
    final codeBlockMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (codeBlockMatch != null) {
      final code = codeBlockMatch.group(1)!.trim();
      try {
        return jsonDecode(code);
      } catch (_) {}
    }

    // 3. Scan for first '{' and matching '}'
    final startIdx = trimmed.indexOf('{');
    final endIdx = trimmed.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      final substring = trimmed.substring(startIdx, endIdx + 1);
      try {
        return jsonDecode(substring);
      } catch (_) {}
    }

    // 4. Scan for array '[' and matching ']'
    final arrStart = trimmed.indexOf('[');
    final arrEnd = trimmed.lastIndexOf(']');
    if (arrStart != -1 && arrEnd != -1 && arrEnd > arrStart) {
      final substring = trimmed.substring(arrStart, arrEnd + 1);
      try {
        return jsonDecode(substring);
      } catch (_) {}
    }

    return null;
  }

  static String _sanitizeToolName(String name) {
    final sanitized =
        name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();
    return sanitized.isEmpty ? 'extract_data' : sanitized;
  }
}
