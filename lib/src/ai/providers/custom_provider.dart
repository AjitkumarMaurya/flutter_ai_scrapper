/// Custom adapter allowing arbitrary functions and enterprise gateways to act as an [AiProvider].
library;

import '../../schema/schema.dart';
import '../ai_provider.dart';

/// Function signature for custom extraction handler.
typedef CustomExtractCallback = Future<AiResult> Function(
  Schema schema,
  String content,
);

/// Function signature for custom text completion handler.
typedef CustomCompleteCallback = Future<String> Function(String prompt);

/// Function signature for custom streaming handler.
typedef CustomStreamCallback = Stream<String> Function(String prompt);

/// Escape-hatch adapter enabling arbitrary gateways, proprietary endpoints,
/// or custom models to function as an [AiProvider].
class CustomProvider implements AiProvider {
  /// Creates a [CustomProvider].
  CustomProvider({
    required this.id,
    required this.onExtract,
    this.onComplete,
    this.onStream,
    this.capabilities = const AiCapabilities(
      supportsJsonSchema: true,
      supportsTools: true,
      maxContextTokens: 32000,
      maxOutputTokens: 2048,
      isLocal: false,
    ),
  });

  @override
  final String id;

  @override
  final AiCapabilities capabilities;

  @override
  bool isReady = true;

  /// Custom extraction implementation.
  final CustomExtractCallback onExtract;

  /// Optional completion implementation.
  final CustomCompleteCallback? onComplete;

  /// Optional token streaming implementation.
  final CustomStreamCallback? onStream;

  @override
  Future<AiResult> extract(Schema schema, String content) =>
      onExtract(schema, content);

  @override
  Future<String> complete(String prompt) {
    if (onComplete != null) {
      return onComplete!(prompt);
    }
    throw UnsupportedError('Completion is not implemented on this CustomProvider.');
  }

  @override
  Stream<String> stream(String prompt) {
    if (onStream != null) {
      return onStream!(prompt);
    }
    throw UnsupportedError('Streaming is not implemented on this CustomProvider.');
  }

  @override
  Future<void> dispose() async {
    isReady = false;
  }
}
