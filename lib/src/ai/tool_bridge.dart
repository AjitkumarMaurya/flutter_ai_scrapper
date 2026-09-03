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

CRITICAL INSTRUCTIONS:
- Do NOT output any <think> tags, internal monologue, reasoning, or explanation.
- Start your response immediately with "{" and end with "}".
- Output ONLY the JSON object.
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
    var trimmed = text.trim();

    // Strip thinking tags if present (e.g. Qwen3 / DeepSeek models)
    final thinkClose = trimmed.indexOf('</think>');
    if (thinkClose != -1) {
      trimmed = trimmed.substring(thinkClose + 8).trim();
    }

    // 1. Direct JSON parse
    final direct = _tryParseJson(trimmed);
    if (direct != null) return direct;

    // 2. Strip Markdown code fences ```json ... ```
    final codeBlockMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (codeBlockMatch != null) {
      final code = codeBlockMatch.group(1)!.trim();
      final parsed = _tryParseJson(code);
      if (parsed != null) return parsed;
    }

    // 3. Scan for first '{' and matching '}'
    final startIdx = trimmed.indexOf('{');
    final endIdx = trimmed.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      final substring = trimmed.substring(startIdx, endIdx + 1);
      final parsed = _tryParseJson(substring);
      if (parsed != null) return parsed;
    }

    // 4. Scan for array '[' and matching ']'
    final arrStart = trimmed.indexOf('[');
    final arrEnd = trimmed.lastIndexOf(']');
    if (arrStart != -1 && arrEnd != -1 && arrEnd > arrStart) {
      final substring = trimmed.substring(arrStart, arrEnd + 1);
      final parsed = _tryParseJson(substring);
      if (parsed != null) return parsed;
    }

    // 5. Unclosed bracket scan: '{' without matching '}'
    if (startIdx != -1 && (endIdx == -1 || endIdx <= startIdx)) {
      final unclosed = trimmed.substring(startIdx);
      final parsed = _tryParseJson('$unclosed}');
      if (parsed != null) return parsed;
    }

    // 6. Resilient key-value extraction fallback
    final kvRegex = RegExp(
      r'''["']?([a-zA-Z0-9_]+)["']?\s*(?::|as|is|=)\s*(?:["']([^"'\n\r]+)["']|(-?\d+(?:\.\d+)?)|(true|false|null))''',
    );
    final matches = kvRegex.allMatches(trimmed);
    if (matches.isNotEmpty) {
      final map = <String, dynamic>{};
      for (final m in matches) {
        final key = m.group(1)!;
        if (m.group(2) != null) {
          map[key] = m.group(2)!.trim();
        } else if (m.group(3) != null) {
          final numStr = m.group(3)!;
          map[key] = numStr.contains('.')
              ? double.tryParse(numStr)
              : int.tryParse(numStr);
        } else if (m.group(4) != null) {
          final b = m.group(4)!;
          map[key] = b == 'true' ? true : (b == 'false' ? false : null);
        }
      }
      if (map.isNotEmpty) {
        return map;
      }
    }

    // 7. Monetary extraction fallback from free-form monologue
    final moneyMatch = RegExp(r'([£$€])\s*(\d+(?:\.\d+)?)').firstMatch(text);
    if (moneyMatch != null) {
      final symbol = moneyMatch.group(1)!;
      final amt = double.tryParse(moneyMatch.group(2)!);
      if (amt != null) {
        final currency = symbol == '£' ? 'GBP' : (symbol == r'$' ? 'USD' : 'EUR');
        return {
          'price': {
            'amount': amt,
            'currency': currency,
          }
        };
      }
    }

    return null;
  }

  static dynamic _tryParseJson(String raw) {
    var candidate = raw.trim();
    try {
      return jsonDecode(candidate);
    } catch (_) {}

    // Trailing comma cleanup: {"a": 1,} -> {"a": 1}
    candidate = candidate.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    try {
      return jsonDecode(candidate);
    } catch (_) {}

    // Single quotes to double quotes
    final fixedQuotes = candidate.replaceAllMapped(
      RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'"),
      (m) => '"${m.group(1)}"',
    );
    try {
      return jsonDecode(fixedQuotes);
    } catch (_) {}

    return null;
  }

  static String _sanitizeToolName(String name) {
    final sanitized =
        name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();
    return sanitized.isEmpty ? 'extract_data' : sanitized;
  }
}
