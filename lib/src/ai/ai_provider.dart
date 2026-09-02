/// Core AI provider abstraction and capability definitions.
library;

import '../schema/schema.dart';

/// Provider execution metrics for tracking token consumption and cost.
class TokenUsage {
  /// Creates token usage metrics.
  const TokenUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    int? totalTokens,
  }) : totalTokens = totalTokens ?? (promptTokens + completionTokens);

  /// Number of tokens in the input prompt.
  final int promptTokens;

  /// Number of tokens generated in the response.
  final int completionTokens;

  /// Total tokens processed.
  final int totalTokens;

  @override
  String toString() =>
      'TokenUsage(prompt: $promptTokens, completion: $completionTokens, total: $totalTokens)';
}

/// Capabilities and constraints of an [AiProvider].
class AiCapabilities {
  /// Creates provider capabilities.
  const AiCapabilities({
    this.supportsJsonSchema = true,
    this.supportsTools = true,
    this.maxContextTokens = 2048,
    this.maxOutputTokens = 512,
    this.supportsStreaming = true,
    this.supportsVision = false,
    this.supportsThinking = false,
    this.isLocal = false,
    this.costPerMTokIn,
    this.costPerMTokOut,
  });

  /// Whether the provider natively constrains output to a JSON Schema.
  final bool supportsJsonSchema;

  /// Whether the provider supports tool / function calling.
  final bool supportsTools;

  /// Context window capacity in tokens (input + output headroom).
  final int maxContextTokens;

  /// Default generation limit in tokens.
  final int maxOutputTokens;

  /// Whether output streaming is supported.
  final bool supportsStreaming;

  /// Whether multimodal image inputs are supported.
  final bool supportsVision;

  /// Whether the model surfaces reasoning / thinking traces.
  final bool supportsThinking;

  /// Whether using this provider keeps data on the device.
  ///
  /// **Defaults to `false`, and deliberately so.** `ProviderChain` uses this
  /// flag to enforce `allowCloudEgress`: a provider reporting `true` is exempt
  /// from that block. Defaulting to `true` would mean a provider whose author
  /// simply forgot to set it silently bypasses the user's privacy choice and
  /// ships their scraped content off-device. A security control has to fail
  /// safe, so anything that has not declared itself local is treated as remote.
  final bool isLocal;

  /// Cost in USD per million input tokens (null for local/free models).
  final double? costPerMTokIn;

  /// Cost in USD per million output tokens (null for local/free models).
  final double? costPerMTokOut;
}

/// The result of an AI inference or extraction request.
class AiResult {
  /// Creates an [AiResult].
  const AiResult({
    required this.providerId,
    this.data,
    this.rawText,
    this.usage,
    this.estimatedCost,
    this.confidence,
    this.error,
  });

  /// Creates a failed [AiResult].
  factory AiResult.failure({
    required String providerId,
    required String error,
    TokenUsage? usage,
  }) =>
      AiResult(
        providerId: providerId,
        error: error,
        usage: usage,
        confidence: 0.0,
      );

  /// The identifier of the provider that produced this result.
  final String providerId;

  /// Coerced, validated data matching the requested schema.
  final dynamic data;

  /// Raw text or serialization from the model.
  final String? rawText;

  /// Token usage metrics for the call.
  final TokenUsage? usage;

  /// Estimated cost of this inference in USD.
  final double? estimatedCost;

  /// Confidence score between 0.0 and 1.0.
  final double? confidence;

  /// Error message if the operation failed.
  final String? error;

  /// Whether the result completed successfully.
  bool get isSuccessful => error == null;
}

/// Abstract contract for language model providers.
///
/// Notice: [extract] is the primary abstraction seam, NOT [complete]. Each
/// provider is free to use its native constrained-output mechanism (native tool
/// calling, grammar constraints, or JSON Schema mode) rather than reducing everything
/// to arbitrary prose generation followed by text regex parsing.
abstract class AiProvider {
  /// Unique identifier of this provider (e.g. `'gemma-3-1b'`, `'fake-ai'`, `'openai'`).
  String get id;

  /// The static capabilities and limits of this provider.
  AiCapabilities get capabilities;

  /// Whether the provider is initialized, has its weights loaded, and is ready for inference.
  bool get isReady;

  /// Extracts structured data conforming to [schema] from the given [content].
  ///
  /// This is the core engine seam: providers use native function/tool calling or
  /// schema-guided decoders whenever supported.
  Future<AiResult> extract(Schema schema, String content);

  /// Generates a free-form completion for [prompt].
  Future<String> complete(String prompt);

  /// Streams completion tokens for [prompt].
  Stream<String> stream(String prompt);

  /// Releases model weights, native sessions, or network connections.
  Future<void> dispose();
}
