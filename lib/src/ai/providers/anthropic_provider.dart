/// Anthropic Claude provider adapter supporting native tool use and streaming.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../schema/schema.dart';
import '../ai_provider.dart';
import '../cost_tracker.dart';
import '../tool_bridge.dart';
import 'openai_provider.dart';

/// Adapter targeting the Anthropic Messages API (`POST /v1/messages`).
class AnthropicProvider implements AiProvider {
  /// Creates an [AnthropicProvider].
  AnthropicProvider({
    required this.apiKey,
    this.model = 'claude-3-5-haiku-20241022',
    this.baseUrl = 'https://api.anthropic.com',
    this.anthropicVersion = '2023-06-01',
    String? id,
    this.headers,
    AiCapabilities? capabilities,
    http.Client? client,
  })  : id = id ?? 'anthropic-$model',
        _client = client ?? http.Client(),
        capabilities = capabilities ??
            AiCapabilities(
              supportsJsonSchema: true,
              supportsTools: true,
              maxContextTokens: 200000,
              maxOutputTokens: 4096,
              supportsStreaming: true,
              supportsVision: true,
              supportsThinking: true,
              isLocal: false,
              costPerMTokIn: ModelPricing.forModel(model).costPerMTokIn,
              costPerMTokOut: ModelPricing.forModel(model).costPerMTokOut,
            );

  /// Anthropic API key.
  final String apiKey;

  /// Model identifier, e.g. `claude-3-5-sonnet-20241022`, `claude-3-5-haiku-20241022`.
  final String model;

  /// Base URL (defaults to `https://api.anthropic.com`).
  final String baseUrl;

  /// API version header (defaults to `2023-06-01`).
  final String anthropicVersion;

  /// Custom request headers.
  final Map<String, String>? headers;

  @override
  final String id;

  @override
  final AiCapabilities capabilities;

  @override
  bool isReady = true;

  final http.Client _client;

  Uri get _messagesUri {
    final clean = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (clean.endsWith('/v1/messages')) {
      return Uri.parse(clean);
    }
    return Uri.parse('$clean/v1/messages');
  }

  Map<String, String> _buildHeaders() {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': anthropicVersion,
    };

    if (headers != null) {
      h.addAll(headers!);
    }

    return h;
  }

  @override
  Future<AiResult> extract(Schema schema, String content) async {
    final toolName = 'extract_data';
    final requestBody = {
      'model': model,
      'max_tokens': capabilities.maxOutputTokens,
      'temperature': 0.1,
      'messages': [
        {
          'role': 'user',
          'content':
              'Extract structured data conforming to the schema from this document:\n\n$content',
        },
      ],
      'tools': [
        {
          'name': toolName,
          'description': 'Extract structured data conforming to schema',
          'input_schema': schema.toJsonSchema(isRoot: false),
        },
      ],
      'tool_choice': {
        'type': 'tool',
        'name': toolName,
      },
    };

    final response = await _client.post(
      _messagesUri,
      headers: _buildHeaders(),
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Anthropic endpoint error (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final jsonResp = jsonDecode(response.body) as Map<String, dynamic>;
    final usage = _parseUsage(jsonResp['usage']);
    final rawPayload = _extractToolPayload(jsonResp, toolName);

    if (rawPayload == null) {
      return AiResult.failure(
        providerId: id,
        error: 'Anthropic model did not return a tool_use block.',
        usage: usage,
      );
    }

    final validation = schema.validate(rawPayload);
    if (validation.isValid) {
      return AiResult(
        providerId: id,
        data: validation.coerced ?? rawPayload,
        rawText: jsonEncode(rawPayload),
        confidence: 0.99,
        usage: usage,
        estimatedCost: capabilities.costPerMTokIn != null
            ? ModelPricing(
                costPerMTokIn: capabilities.costPerMTokIn!,
                costPerMTokOut: capabilities.costPerMTokOut!,
              ).estimateCost(usage)
            : null,
      );
    }

    // Attempt single repair pass
    return _repairExtract(
      schema,
      content,
      validation.errors.values.toList(),
      usage,
    );
  }

  Future<AiResult> _repairExtract(
    Schema schema,
    String content,
    List<String> errors,
    TokenUsage initialUsage,
  ) async {
    const toolName = 'extract_data';
    final retryPrompt = ToolBridge.buildRetryPrompt(schema, content, errors);

    final requestBody = {
      'model': model,
      'max_tokens': capabilities.maxOutputTokens,
      'temperature': 0.1,
      'messages': [
        {'role': 'user', 'content': retryPrompt},
      ],
      'tools': [
        {
          'name': toolName,
          'description': 'Extract structured data conforming to schema',
          'input_schema': schema.toJsonSchema(isRoot: false),
        },
      ],
      'tool_choice': {
        'type': 'tool',
        'name': toolName,
      },
    };

    final response = await _client.post(
      _messagesUri,
      headers: _buildHeaders(),
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final jsonResp = jsonDecode(response.body) as Map<String, dynamic>;
      final retryUsage = _parseUsage(jsonResp['usage']);
      final totalUsage = TokenUsage(
        promptTokens: initialUsage.promptTokens + retryUsage.promptTokens,
        completionTokens:
            initialUsage.completionTokens + retryUsage.completionTokens,
      );

      final payload = _extractToolPayload(jsonResp, toolName);
      if (payload != null) {
        final validation = schema.validate(payload);
        if (validation.isValid) {
          return AiResult(
            providerId: id,
            data: validation.coerced ?? payload,
            rawText: jsonEncode(payload),
            confidence: 0.89,
            usage: totalUsage,
          );
        }
      }
    }

    return AiResult.failure(
      providerId: id,
      error: 'Extracted data failed validation: ${errors.join(", ")}',
      usage: initialUsage,
    );
  }

  dynamic _extractToolPayload(Map<String, dynamic> response, String toolName) {
    final contentBlocks = response['content'] as List?;
    if (contentBlocks == null) return null;

    for (final block in contentBlocks) {
      if (block is Map<String, dynamic>) {
        if (block['type'] == 'tool_use' && block['name'] == toolName) {
          return block['input'];
        }
      }
    }

    return null;
  }

  TokenUsage _parseUsage(dynamic usage) {
    if (usage is Map) {
      return TokenUsage(
        promptTokens: (usage['input_tokens'] as num?)?.toInt() ?? 0,
        completionTokens: (usage['output_tokens'] as num?)?.toInt() ?? 0,
        totalTokens: ((usage['input_tokens'] as num?)?.toInt() ?? 0) +
            ((usage['output_tokens'] as num?)?.toInt() ?? 0),
      );
    }
    return const TokenUsage(promptTokens: 0, completionTokens: 0);
  }

  @override
  Future<String> complete(String prompt) async {
    final requestBody = {
      'model': model,
      'max_tokens': capabilities.maxOutputTokens,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    };

    final response = await _client.post(
      _messagesUri,
      headers: _buildHeaders(),
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Anthropic completion error (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final jsonResp = jsonDecode(response.body) as Map<String, dynamic>;
    final blocks = jsonResp['content'] as List?;
    if (blocks != null) {
      for (final block in blocks) {
        if (block is Map && block['type'] == 'text') {
          return block['text']?.toString() ?? '';
        }
      }
    }
    return '';
  }

  @override
  Stream<String> stream(String prompt) async* {
    final requestBody = {
      'model': model,
      'stream': true,
      'max_tokens': capabilities.maxOutputTokens,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    };

    final request = http.Request('POST', _messagesUri)
      ..headers.addAll(_buildHeaders())
      ..body = jsonEncode(requestBody);

    final streamedResponse = await _client.send(request);
    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw HttpException(
        'Anthropic stream error (${streamedResponse.statusCode}): $body',
        statusCode: streamedResponse.statusCode,
      );
    }

    final lines = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;

      final dataContent = trimmed.substring(5).trim();
      if (dataContent.isEmpty) continue;

      try {
        final parsed = jsonDecode(dataContent) as Map<String, dynamic>;
        final type = parsed['type']?.toString();

        if (type == 'content_block_delta') {
          final delta = parsed['delta'] as Map<String, dynamic>?;
          final text = delta?['text']?.toString();
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        }
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    isReady = false;
  }
}
