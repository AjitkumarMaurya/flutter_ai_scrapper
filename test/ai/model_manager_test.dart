import 'package:flutter_ai_scrapper/src/ai/model_manager.dart';
import 'package:flutter_gemma/core/domain/download_error.dart';
import 'package:flutter_gemma/core/domain/download_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelManager & GemmaModels Catalogue', () {
    test('verifies catalogue specifications and tool-support constraints', () {
      expect(GemmaModels.gemma31b.isDefault, isTrue);
      expect(GemmaModels.gemma31b.supportsTools, isTrue);
      expect(GemmaModels.gemma31b.sizeMb, closeTo(550, 10));

      expect(GemmaModels.functionGemma270m.supportsTools, isTrue);
      expect(GemmaModels.functionGemma270m.sizeMb, closeTo(300, 10));

      expect(GemmaModels.qwen306b.supportsTools, isTrue);
      expect(GemmaModels.gemma4E2b.supportsTools, isTrue);

      // Gemma 3 270M must be excluded from extraction because it lacks function calling
      expect(GemmaModels.gemma3270m.supportsTools, isFalse);
      expect(GemmaModels.supported, isNot(contains(GemmaModels.gemma3270m)));
    });

    test('maps 401 Unauthorized to gated Hugging Face repository explanation', () {
      const exception = DownloadException(UnauthorizedError());
      final message = ModelManager.mapDownloadError(exception);

      expect(message, contains('Gated or private Hugging Face repository'));
      expect(message, contains('HTTP 401'));
      expect(message, contains('huggingFaceToken'));
    });

    test('maps 403 Forbidden to gated access permission explanation', () {
      const exception = DownloadException(ForbiddenError());
      final message = ModelManager.mapDownloadError(exception);

      expect(message, contains('Gated Hugging Face repository access forbidden'));
      expect(message, contains('HTTP 403'));
      expect(message, contains('requested access'));
    });

    test('maps 404 NotFound to repository identifier check', () {
      const exception = DownloadException(NotFoundError());
      final message = ModelManager.mapDownloadError(exception);

      expect(message, contains('Model not found'));
      expect(message, contains('HTTP 404'));
    });
  });
}
