/// On-device Gemma AI provider implementation.
library;

import 'package:flutter_gemma/flutter_gemma.dart';

import '../../schema/schema.dart';
import '../ai_provider.dart';
import '../tool_bridge.dart';

/// Real on-device provider utilizing `flutter_gemma`.
class GemmaProvider implements AiProvider {
  /// Creates a [GemmaProvider].
  GemmaProvider({
    this.id = 'gemma-on-device',
    this.model,
    this.capabilities = const AiCapabilities(
      supportsJsonSchema: true,
      supportsTools: true,
      maxContextTokens: 2048,
      maxOutputTokens: 512,
      supportsStreaming: true,
      supportsVision: false,
      supportsThinking: false,
      isLocal: true,
      costPerMTokIn: 0.0,
      costPerMTokOut: 0.0,
    ),
  });

  @override
  final String id;

  @override
  final AiCapabilities capabilities;

  /// Underlying loaded model instance, or null before [init].
  InferenceModel? model;

  @override
  bool get isReady => model != null;

  /// Initializes the provider by loading the active model from `FlutterGemma`.
  Future<void> init() async {
    model ??= await FlutterGemma.getActiveModel(
      maxTokens: capabilities.maxContextTokens,
    );
  }

  @override
  Future<AiResult> extract(Schema schema, String content) async {
    await init();
    final activeModel = model;
    if (activeModel == null) {
      return AiResult.failure(
        providerId: id,
        error: 'No active Gemma model loaded.',
      );
    }

    if (capabilities.supportsTools) {
      return _extractWithTools(schema, content, activeModel);
    } else {
      return _extractWithJsonPrompt(schema, content, activeModel);
    }
  }

  Future<AiResult> _extractWithTools(
    Schema schema,
    String content,
    InferenceModel activeModel,
  ) async {
    final tool = ToolBridge.schemaToTool(schema);

    // Extraction is a deterministic task: low temperature, greedy top-k
    final session = await activeModel.createSession(
      temperature: 0.1,
      topK: 1,
      tools: [tool],
      maxOutputTokens: capabilities.maxOutputTokens,
    );

    final chat = InferenceChat(
      sessionCreator: () => activeModel.createSession(
        temperature: 0.1,
        topK: 1,
        tools: [tool],
        maxOutputTokens: capabilities.maxOutputTokens,
      ),
      maxTokens: capabilities.maxContextTokens,
      supportsFunctionCalls: true,
      toolChoice: ToolChoice.required,
      modelType: ModelType.gemmaIt,
      fileType: activeModel.fileType,
    );
    chat.session = session;

    final prompt =
        'Extract information conforming to the schema from this document:\n\n$content';
    await chat.addQuery(Message(text: prompt, isUser: true));

    final response = await chat.generateChatResponse();
    final args = ToolBridge.parseFunctionArgs(response);

    if (args != null) {
      final validation = schema.validate(args);
      if (validation.isValid) {
        return AiResult(
          providerId: id,
          data: validation.coerced ?? args,
          rawText: args.toString(),
          confidence: 0.95,
          usage: const TokenUsage(promptTokens: 200, completionTokens: 50),
        );
      }

      // Retry once feeding validation errors back
      final retryPrompt = ToolBridge.buildRetryPrompt(
        schema,
        content,
        validation.errors.values.toList(),
      );
      await chat.addQuery(Message(text: retryPrompt, isUser: true));
      final retryResponse = await chat.generateChatResponse();
      final retryArgs = ToolBridge.parseFunctionArgs(retryResponse);

      if (retryArgs != null) {
        final retryValidation = schema.validate(retryArgs);
        if (retryValidation.isValid) {
          return AiResult(
            providerId: id,
            data: retryValidation.coerced ?? retryArgs,
            rawText: retryArgs.toString(),
            confidence: 0.85,
            usage: const TokenUsage(promptTokens: 350, completionTokens: 90),
          );
        }
      }
    }

    // Fall back to JSON prompt mode if tool call was empty or failed validation
    return _extractWithJsonPrompt(schema, content, activeModel);
  }

  Future<AiResult> _extractWithJsonPrompt(
    Schema schema,
    String content,
    InferenceModel activeModel,
  ) async {
    final prompt = ToolBridge.buildJsonPrompt(schema, content);
    final session = await activeModel.createSession(
      temperature: 0.1,
      topK: 1,
      maxOutputTokens: capabilities.maxOutputTokens,
    );

    await session.addQueryChunk(Message(text: prompt, isUser: true));
    final rawResponse = await session.getResponse();
    await session.close();

    final parsed = ToolBridge.parseJsonFromProse(rawResponse);
    if (parsed == null) {
      return AiResult.failure(
        providerId: id,
        error: 'Failed to parse JSON response from model prose.',
      );
    }

    final validation = schema.validate(parsed);
    if (!validation.isValid) {
      return AiResult.failure(
        providerId: id,
        error:
            'Extracted JSON failed schema validation: ${validation.errors.values.join(", ")}',
      );
    }

    return AiResult(
      providerId: id,
      data: validation.coerced ?? parsed,
      rawText: rawResponse,
      confidence: 0.8,
      usage: const TokenUsage(promptTokens: 250, completionTokens: 60),
    );
  }

  @override
  Future<String> complete(String prompt) async {
    await init();
    final activeModel = model;
    if (activeModel == null) {
      throw StateError('No active Gemma model loaded.');
    }

    final session = await activeModel.createSession(
      temperature: 0.7,
      maxOutputTokens: capabilities.maxOutputTokens,
    );
    await session.addQueryChunk(Message(text: prompt, isUser: true));
    final response = await session.getResponse();
    await session.close();
    return response;
  }

  @override
  Stream<String> stream(String prompt) async* {
    await init();
    final activeModel = model;
    if (activeModel == null) {
      throw StateError('No active Gemma model loaded.');
    }

    final session = await activeModel.createSession(
      temperature: 0.7,
      maxOutputTokens: capabilities.maxOutputTokens,
    );
    await session.addQueryChunk(Message(text: prompt, isUser: true));

    await for (final token in session.getResponseAsync()) {
      yield token;
    }
    await session.close();
  }

  @override
  Future<void> dispose() async {
    model = null;
  }
}
