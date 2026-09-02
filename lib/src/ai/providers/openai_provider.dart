/// OpenAI-compatible provider adapter supporting cloud APIs and local inference servers.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../schema/schema.dart';
import '../ai_provider.dart';
import '../cost_tracker.dart';
import '../tool_bridge.dart';

/// Structured output execution strategy for OpenAI-compatible endpoints.
enum OpenAiStructuredMode {
  /// True constrained decoding via `response_format: {type: "json_schema"}`.
  jsonSchema,

  /// Forced function call via `tools` + `tool_choice`.
  tools,

  /// Conversational JSON prompting with regex repair fallback.
  promptedJson,

  /// Automatically selects `jsonSchema`, falling back to `tools` if unsupported.
  auto,
}

/// Adapter targeting OpenAI-compatible endpoints (`POST {baseUrl}/chat/completions`).
///
/// Compatible with OpenAI, Azure OpenAI, Groq, Together, Fireworks, OpenRouter,
/// DeepSeek, Mistral, xAI, and local servers Ollama, LM Studio, and vLLM.
class OpenAiProvider implements AiProvider {
  /// Creates an [OpenAiProvider].
  OpenAiProvider({
    required this.baseUrl,
    required this.model,
    this.apiKey,
    String? id,
    this.mode = OpenAiStructuredMode.auto,
    this.headers,
    AiCapabilities? capabilities,
    http.Client? client,
  })  : id = id ?? 'openai-$model',
        _client = client ?? http.Client(),
        capabilities = capabilities ??
            AiCapabilities(
              supportsJsonSchema: true,
              supportsTools: true,
              maxContextTokens: 128000,
              maxOutputTokens: 4096,
              supportsStreaming: true,
              supportsVision: false,
              isLocal: _isLocalUrl(baseUrl),
              costPerMTokIn: ModelPricing.forModel(model).costPerMTokIn,
              costPerMTokOut: ModelPricing.forModel(model).costPerMTokOut,
            );

  /// Target base URL, e.g. `https://api.openai.com/v1` or `http://localhost:11434/v1`.
  final String baseUrl;

  /// Model identifier, e.g. `gpt-4o-mini`, `deepseek-chat`, `llama3`.
  final String model;

  /// Optional API key or bearer token (omitted for unauthenticated local servers).
  final String? apiKey;

  /// Preferred structured output mode.
  final OpenAiStructuredMode mode;

  /// Custom headers (e.g. Azure `api-key`, OpenRouter `HTTP-Referer`).
  final Map<String, String>? headers;

  @override
  final String id;

  @override
  final AiCapabilities capabilities;

  @override
  bool isReady = true;

  final http.Client _client;
  final bool _ownsClient = false;

  // Cache probe results per endpoint and model to avoid repeated 400 probes
  static final Map<String, OpenAiStructuredMode> _probedModes = {};

  static bool _isLocalUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('localhost') ||
        lower.contains('127.0.0.1') ||
        lower.contains('0.0.0.0') ||
        lower.contains('10.0.2.2');
  }

  Uri get _completionsUri {
    final clean = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (clean.endsWith('/chat/completions')) {
      return Uri.parse(clean);
    }
    return Uri.parse('$clean/chat/completions');
  }

  Map<String, String> _buildHeaders() {
    final h = <String, String>{
      'Content-Type': 'application/json',
    };

    if (apiKey != null && apiKey!.isNotEmpty) {
      if (headers == null || !headers!.containsKey('api-key')) {
        h['Authorization'] = 'Bearer $apiKey';
      }
    }

    if (headers != null) {
      h.addAll(headers!);
    }

    return h;
  }

  OpenAiStructuredMode get _effectiveMode {
    if (mode != OpenAiStructuredMode.auto) return mode;
    return _probedModes['$baseUrl:$model'] ?? OpenAiStructuredMode.jsonSchema;
  }

  @override
  Future<AiResult> extract(Schema schema, String content) async {
    final activeMode = _effectiveMode;

    try {
      return await _executeExtract(schema, content, activeMode);
    } on http.ClientException {
      rethrow;
    } catch (e) {
      // If auto-mode failed in jsonSchema mode due to lack of endpoint support, try tools
      if (mode == OpenAiStructuredMode.auto &&
          activeMode == OpenAiStructuredMode.jsonSchema) {
        _probedModes['$baseUrl:$model'] = OpenAiStructuredMode.tools;
        return _executeExtract(schema, content, OpenAiStructuredMode.tools);
      }
      rethrow;
    }
  }

  Future<AiResult> _executeExtract(
    Schema schema,
    String content,
    OpenAiStructuredMode activeMode,
  ) async {
    final prompt =
        'Extract data conforming to the schema from this document:\n\n$content';

    Map<String, dynamic> requestBody;

    switch (activeMode) {
      case OpenAiStructuredMode.jsonSchema:
        requestBody = {
          'model': model,
          'temperature': 0.1,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a precise data extraction assistant.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'response_format': {
            'type': 'json_schema',
            'json_schema': {
              'name': 'extract_data',
              'strict': true,
              'schema': schema.toJsonSchema(isRoot: false),
            },
          },
        };
      case OpenAiStructuredMode.tools:
        requestBody = {
          'model': model,
          'temperature': 0.1,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a precise data extraction assistant.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'tools': [
            {
              'type': 'function',
              'function': {
                'name': 'extract_data',
                'description': 'Extract structured data conforming to schema',
                'parameters': schema.toJsonSchema(),
              },
            },
          ],
          'tool_choice': {
            'type': 'function',
            'function': {'name': 'extract_data'},
          },
        };
      case OpenAiStructuredMode.promptedJson:
      case OpenAiStructuredMode.auto:
        final jsonPrompt = ToolBridge.buildJsonPrompt(schema, content);
        requestBody = {
          'model': model,
          'temperature': 0.1,
          'messages': [
            {'role': 'user', 'content': jsonPrompt},
          ],
        };
    }

    final response = await _client.post(
      _completionsUri,
      headers: _buildHeaders(),
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'OpenAI endpoint error (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final jsonResp = jsonDecode(response.body) as Map<String, dynamic>;
    final usage = _parseUsage(jsonResp['usage']);
    final rawArgs = _extractPayload(jsonResp, activeMode);

    if (rawArgs == null) {
      return AiResult.failure(
        providerId: id,
        error: 'Failed to extract valid data from response.',
        usage: usage,
      );
    }

    // Validate against schema
    final validation = schema.validate(rawArgs);
    if (validation.isValid) {
      return AiResult(
        providerId: id,
        data: validation.coerced ?? rawArgs,
        rawText: jsonEncode(rawArgs),
        confidence: 0.98,
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
    return _repairExtract(schema, content, validation.errors.values.toList(), usage);
  }

  Future<AiResult> _repairExtract(
    Schema schema,
    String content,
    List<String> errors,
    TokenUsage initialUsage,
  ) async {
    final retryPrompt = ToolBridge.buildRetryPrompt(schema, content, errors);

    final requestBody = {
      'model': model,
      'temperature': 0.1,
      'messages': [
        {
          'role': 'system',
          'content': 'You are a precise data extraction assistant.',
        },
        {'role': 'user', 'content': retryPrompt},
      ],
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'extract_data',
          'strict': true,
          'schema': schema.toJsonSchema(isRoot: false),
        },
      },
    };

    final response = await _client.post(
      _completionsUri,
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

      final payload = _extractPayload(jsonResp, OpenAiStructuredMode.jsonSchema);
      if (payload != null) {
        final validation = schema.validate(payload);
        if (validation.isValid) {
          return AiResult(
            providerId: id,
            data: validation.coerced ?? payload,
            rawText: jsonEncode(payload),
            confidence: 0.88,
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

  dynamic _extractPayload(
    Map<String, dynamic> response,
    OpenAiStructuredMode activeMode,
  ) {
    final choices = response['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;

    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>?;
    if (message == null) return null;

    if (activeMode == OpenAiStructuredMode.tools) {
      final toolCalls = message['tool_calls'] as List?;
      if (toolCalls != null && toolCalls.isNotEmpty) {
        final call = toolCalls.first as Map<String, dynamic>;
        final fn = call['function'] as Map<String, dynamic>?;
        final argsStr = fn?['arguments']?.toString();
        if (argsStr != null) {
          return ToolBridge.parseJsonFromProse(argsStr);
        }
      }
    }

    final content = message['content']?.toString();
    if (content != null) {
      return ToolBridge.parseJsonFromProse(content);
    }

    return null;
  }

  TokenUsage _parseUsage(dynamic usage) {
    if (usage is Map) {
      return TokenUsage(
        promptTokens: (usage['prompt_tokens'] as num?)?.toInt() ?? 0,
        completionTokens: (usage['completion_tokens'] as num?)?.toInt() ?? 0,
        totalTokens: (usage['total_tokens'] as num?)?.toInt(),
      );
    }
    return const TokenUsage(promptTokens: 0, completionTokens: 0);
  }

  @override
  Future<String> complete(String prompt) async {
    final requestBody = {
      'model': model,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    };

    final response = await _client.post(
      _completionsUri,
      headers: _buildHeaders(),
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'OpenAI completion error (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final jsonResp = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = jsonResp['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    final first = choices.first as Map<String, dynamic>?;
    final message = first?['message'] as Map<String, dynamic>?;
    return message?['content']?.toString() ?? '';
  }

  @override
  Stream<String> stream(String prompt) async* {
    final requestBody = {
      'model': model,
      'stream': true,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    };

    final request = http.Request('POST', _completionsUri)
      ..headers.addAll(_buildHeaders())
      ..body = jsonEncode(requestBody);

    final streamedResponse = await _client.send(request);
    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw HttpException(
        'OpenAI stream error (${streamedResponse.statusCode}): $body',
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
      if (dataContent == '[DONE]') break;

      try {
        final parsed = jsonDecode(dataContent) as Map<String, dynamic>;
        final choices = parsed['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final first = choices.first as Map<String, dynamic>?;
          final delta = first?['delta'] as Map<String, dynamic>?;
          final token = delta?['content']?.toString();
          if (token != null && token.isNotEmpty) {
            yield token;
          }
        }
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    isReady = false;
    if (_ownsClient) {
      _client.close();
    }
  }
}

/// HTTP exception carrying status code.
class HttpException implements Exception {
  /// Creates an [HttpException].
  const HttpException(this.message, {this.statusCode});

  /// The error message.
  final String message;

  /// HTTP response status code if available.
  final int? statusCode;

  @override
  String toString() => 'HttpException($statusCode): $message';
}
