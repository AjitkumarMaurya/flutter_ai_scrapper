/// Scripted, deterministic AI provider for CI and offline testing.
library;

import '../schema/schema.dart';
import 'ai_provider.dart';

/// Recorded call for introspection in tests.
class FakeCall {
  /// Creates a recorded call.
  const FakeCall({
    required this.schema,
    required this.content,
    required this.timestamp,
  });

  /// The schema requested.
  final Schema schema;

  /// The input content provided.
  final String content;

  /// Timestamp of the call.
  final DateTime timestamp;
}

/// A fake, deterministic [AiProvider] providing scripted responses for testing
/// and CI pipelines without requiring model weights.
class FakeAiProvider implements AiProvider {
  /// Creates a [FakeAiProvider].
  FakeAiProvider({
    this.id = 'fake-ai',
    this.capabilities = const AiCapabilities(
      supportsJsonSchema: true,
      supportsTools: true,
      maxContextTokens: 2048,
      maxOutputTokens: 512,
      isLocal: true,
    ),
    this.scriptedData,
    this.onExtract,
    this.onComplete,
    this.simulatedError,
    this.simulatedDelay,
  });

  @override
  final String id;

  @override
  final AiCapabilities capabilities;

  @override
  bool isReady = true;

  /// Static data returned for any [extract] request.
  final Map<String, dynamic>? scriptedData;

  /// Dynamic handler for extraction calls.
  final dynamic Function(Schema schema, String content)? onExtract;

  /// Dynamic handler for completion calls.
  final String Function(String prompt)? onComplete;

  /// Optional error to simulate failures.
  final String? simulatedError;

  /// Optional artificial delay to simulate latency.
  final Duration? simulatedDelay;

  final List<FakeCall> _calls = [];

  /// All recorded [extract] calls.
  List<FakeCall> get calls => List.unmodifiable(_calls);

  /// Clears recorded calls.
  void clearCalls() => _calls.clear();

  @override
  Future<AiResult> extract(Schema schema, String content) async {
    if (simulatedDelay != null) {
      await Future<void>.delayed(simulatedDelay!);
    }

    _calls.add(FakeCall(
      schema: schema,
      content: content,
      timestamp: DateTime.now(),
    ));

    if (simulatedError != null) {
      return AiResult.failure(
        providerId: id,
        error: simulatedError!,
        usage: const TokenUsage(promptTokens: 50, completionTokens: 0),
      );
    }

    final rawPayload = onExtract != null
        ? onExtract!(schema, content)
        : (scriptedData ?? <String, dynamic>{});

    // Validate and coerce against schema
    final validation = schema.validate(rawPayload);
    if (!validation.isValid) {
      return AiResult.failure(
        providerId: id,
        error: 'Validation failed: ${validation.errors.values.join(", ")}',
        usage: const TokenUsage(promptTokens: 100, completionTokens: 50),
      );
    }

    return AiResult(
      providerId: id,
      data: validation.coerced ?? rawPayload,
      rawText: rawPayload.toString(),
      confidence: 1.0,
      usage: const TokenUsage(promptTokens: 120, completionTokens: 40),
    );
  }

  @override
  Future<String> complete(String prompt) async {
    if (simulatedDelay != null) {
      await Future<void>.delayed(simulatedDelay!);
    }

    if (simulatedError != null) {
      throw StateError(simulatedError!);
    }

    return onComplete != null ? onComplete!(prompt) : 'Mock response for: $prompt';
  }

  @override
  Stream<String> stream(String prompt) async* {
    final text = await complete(prompt);
    for (final char in text.split('')) {
      yield char;
    }
  }

  @override
  Future<void> dispose() async {
    isReady = false;
  }
}
