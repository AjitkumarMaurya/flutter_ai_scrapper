/// Model lifecycle management, Hugging Face gated repo handling, and model catalogue.
library;

import 'package:flutter_gemma/flutter_gemma.dart';

/// Specification for an on-device language model.
class GemmaModelSpec {
  /// Creates a model specification.
  const GemmaModelSpec({
    required this.name,
    required this.repo,
    required this.modelType,
    required this.fileType,
    required this.sizeBytes,
    required this.supportsTools,
    required this.description,
    this.isDefault = false,
  });

  /// Human-readable model name.
  final String name;

  /// Hugging Face repository identifier.
  final String repo;

  /// Supported model family architecture.
  final ModelType modelType;

  /// Underlying file format.
  final ModelFileType fileType;

  /// Approximate download and storage size in bytes.
  final int sizeBytes;

  /// Whether the model architecture supports function / tool calling.
  ///
  /// Required for high-accuracy schema extraction.
  final bool supportsTools;

  /// Summary description.
  final String description;

  /// Whether this is the recommended default model.
  final bool isDefault;

  /// Size in megabytes.
  double get sizeMb => sizeBytes / (1024 * 1024);
}

/// Curated catalogue of verified on-device models for extraction.
abstract final class GemmaModels {
  /// Gemma 3 1B — the recommended default extraction model.
  static const gemma31b = GemmaModelSpec(
    name: 'Gemma 3 1B',
    repo: 'google/gemma-3-1b-it',
    modelType: ModelType.gemmaIt,
    fileType: ModelFileType.litertlm,
    sizeBytes: 550 * 1024 * 1024,
    supportsTools: true,
    description: 'Default on-device extraction model (~550 MB)',
    isDefault: true,
  );

  /// FunctionGemma 270M — lightest viable model with native function calling.
  static const functionGemma270m = GemmaModelSpec(
    name: 'FunctionGemma 270M',
    repo: 'google/function-gemma-270m-it',
    modelType: ModelType.functionGemma,
    fileType: ModelFileType.litertlm,
    sizeBytes: 300 * 1024 * 1024,
    supportsTools: true,
    description: 'Lightest viable function-calling model (~300 MB, single-turn)',
  );

  /// Qwen3 0.6B — optimized for low-RAM mobile devices.
  static const qwen306b = GemmaModelSpec(
    name: 'Qwen3 0.6B',
    repo: 'Qwen/Qwen2.5-0.5B-Instruct',
    modelType: ModelType.qwen3,
    fileType: ModelFileType.litertlm,
    sizeBytes: 400 * 1024 * 1024,
    supportsTools: true,
    description: 'Compact model for low-memory devices (~400 MB)',
  );

  /// Gemma 4 E2B — quality tier model with native function-calling tokens.
  static const gemma4E2b = GemmaModelSpec(
    name: 'Gemma 4 E2B',
    repo: 'google/gemma-4-e2b-it',
    modelType: ModelType.gemma4,
    fileType: ModelFileType.litertlm,
    sizeBytes: 2400 * 1024 * 1024,
    supportsTools: true,
    description: 'High-quality extraction model (~2.4 GB, Wi-Fi recommended)',
  );

  /// Gemma 3 270M — excluded from extraction because it lacks tools support.
  static const gemma3270m = GemmaModelSpec(
    name: 'Gemma 3 270M (Excluded)',
    repo: 'google/gemma-3-270m-it',
    modelType: ModelType.gemmaIt,
    fileType: ModelFileType.litertlm,
    sizeBytes: 200 * 1024 * 1024,
    supportsTools: false,
    description: 'Excluded: lacks function-calling support needed for schema extraction',
  );

  /// All supported extraction models.
  static const List<GemmaModelSpec> supported = [
    gemma31b,
    functionGemma270m,
    qwen306b,
    gemma4E2b,
  ];
}

/// Lifecycle management for local Gemma models.
class ModelManager {
  /// Creates a [ModelManager].
  const ModelManager();

  /// Installs a curated [spec] from Hugging Face with progress callbacks.
  Future<void> install(
    GemmaModelSpec spec, {
    String? token,
    void Function(double progress)? onProgress,
  }) async {
    if (!spec.supportsTools) {
      throw UnsupportedError(
        'Model "${spec.name}" does not support tools/function-calling. '
        'Schema extraction requires tool support.',
      );
    }

    try {
      await FlutterGemma.installModel(
        modelType: spec.modelType,
        fileType: spec.fileType,
      )
          .fromHuggingFace(spec.repo)
          .withProgress((progress) => onProgress?.call(progress / 100.0))
          .install();
    } catch (e) {
      throw StateError(mapDownloadError(e));
    }
  }

  /// Installs an arbitrary model from a Hugging Face repository.
  Future<void> installFromHuggingFace(
    String repo, {
    ModelType modelType = ModelType.gemmaIt,
    ModelFileType fileType = ModelFileType.litertlm,
    String? token,
    void Function(double progress)? onProgress,
  }) async {
    try {
      await FlutterGemma.installModel(
        modelType: modelType,
        fileType: fileType,
      )
          .fromHuggingFace(repo)
          .withProgress((progress) => onProgress?.call(progress / 100.0))
          .install();
    } catch (e) {
      throw StateError(mapDownloadError(e));
    }
  }

  /// Installs a model from a direct HTTP/HTTPS URL.
  Future<void> installFromNetwork(
    String url, {
    ModelType modelType = ModelType.gemmaIt,
    ModelFileType fileType = ModelFileType.task,
    String? token,
    void Function(double progress)? onProgress,
  }) async {
    try {
      await FlutterGemma.installModel(
        modelType: modelType,
        fileType: fileType,
      )
          .fromNetwork(url, token: token)
          .withProgress((progress) => onProgress?.call(progress / 100.0))
          .install();
    } catch (e) {
      throw StateError(mapDownloadError(e));
    }
  }

  /// Installs a model from bundled Flutter assets.
  Future<void> installFromAsset(
    String assetPath, {
    ModelType modelType = ModelType.gemmaIt,
    ModelFileType fileType = ModelFileType.task,
  }) async {
    try {
      await FlutterGemma.installModel(
        modelType: modelType,
        fileType: fileType,
      ).fromAsset(assetPath).install();
    } catch (e) {
      throw StateError(mapDownloadError(e));
    }
  }

  /// Checks if a model file or identifier is installed on device.
  Future<bool> isModelInstalled(String modelId) =>
      FlutterGemma.isModelInstalled(modelId);

  /// Lists all currently installed model IDs.
  Future<List<String>> listInstalledModels() =>
      FlutterGemma.listInstalledModels();

  /// Uninstalls a model from device storage.
  Future<void> uninstallModel(String modelId) =>
      FlutterGemma.uninstallModel(modelId);

  /// Retrieves storage statistics (used bytes, free bytes, model sizes).
  Future<StorageStats> getStorageInfo() => FlutterGemma.getStorageInfo();

  /// Maps internal download exceptions to actionable, user-friendly explanations.
  ///
  /// In particular, 401/403 errors are clearly attributed to gated Hugging Face repositories.
  static String mapDownloadError(Object error) {
    if (error is DownloadException) {
      final downloadError = error.error;
      if (downloadError is UnauthorizedError) {
        return 'Gated or private Hugging Face repository (HTTP 401).\n'
            'Please supply a Hugging Face user access token via FlutterGemma.initialize(huggingFaceToken: "hf_...").';
      }
      if (downloadError is ForbiddenError) {
        return 'Gated Hugging Face repository access forbidden (HTTP 403).\n'
            'Ensure you have agreed to the license and requested access to the gated model at https://huggingface.co, '
            'and that your token has read permissions.';
      }
      if (downloadError is NotFoundError) {
        return 'Model not found on Hugging Face (HTTP 404). Check the repository identifier.';
      }
      if (downloadError is RateLimitedError) {
        return 'Hugging Face rate limit exceeded (HTTP 429). Please wait before trying again.';
      }
      return downloadError.toUserMessage();
    }
    return error.toString();
  }
}
