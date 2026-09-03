import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the model catalogue against the class of defect found during device
/// testing: entries that point at repositories which cannot actually serve an
/// on-device model file.
///
/// Every claim here was verified by HTTP request against Hugging Face on
/// 2026-09-03. These are offline assertions about the *shape* of each entry —
/// they cannot detect a repo going away, which is why the reachability of each
/// file was checked by hand and recorded in the comments.
void main() {
  final catalogue = <GemmaModelSpec>[
    GemmaModels.gemma31b,
    GemmaModels.functionGemma270m,
    GemmaModels.qwen306b,
    GemmaModels.gemma4E2b,
  ];

  group('every catalogue entry is installable in principle', () {
    for (final model in catalogue) {
      group(model.name, () {
        test('pins an explicit file rather than relying on a manifest', () {
          // None of these repos serve litertlm_manifest.json (verified: 404 or
          // 401), so manifest-mode resolution would fail. The file must be
          // named explicitly.
          expect(
            model.file,
            isNotNull,
            reason: '${model.name} would fall back to manifest resolution',
          );
          expect(model.file, isNotEmpty);
        });

        test('names a litert-community style on-device conversion', () {
          // The original vendor repos (google/gemma-3-1b-it and friends) hold
          // PyTorch weights and NO .task/.litertlm files at all — installing
          // from them cannot work. Only the conversions do.
          expect(
            model.repo,
            contains('/'),
            reason: 'must be an org/name repository id',
          );
          expect(
            model.repo.startsWith('google/') && !model.repo.contains('litert'),
            isFalse,
            reason: '${model.repo} is a vendor weights repo with no on-device '
                'model files',
          );
        });

        test('the file extension matches the declared fileType', () {
          final file = model.file!;
          switch (model.fileType) {
            case ModelFileType.litertlm:
              expect(file, endsWith('.litertlm'));
            case ModelFileType.task:
              expect(file, endsWith('.task'));
            default:
              break;
          }
        });

        test('states a plausible download size', () {
          // The size is the number a user weighs before committing to the
          // download, so a placeholder is worse than none.
          expect(model.sizeBytes, greaterThan(100 * 1024 * 1024));
          expect(model.sizeBytes, lessThan(8 * 1024 * 1024 * 1024));
        });

        test('supports tools, which schema extraction requires', () {
          expect(model.supportsTools, isTrue);
        });
      });
    }
  });

  group('gating is declared', () {
    test('the gated models are marked', () {
      // Verified by request: both answer an anonymous download with HTTP 401.
      expect(GemmaModels.gemma31b.gated, isTrue);
      expect(GemmaModels.functionGemma270m.gated, isTrue);
    });

    test('at least one model needs no token', () {
      // Without this the AI path is unreachable for anyone who has not set up
      // a Hugging Face account, which would make "on-device AI" false in
      // practice for most first-time users.
      final ungated = catalogue.where((m) => !m.gated).toList();
      expect(ungated, isNotEmpty);
      expect(ungated.map((m) => m.name), contains('Qwen3 0.6B'));
    });

    test('a gated model says so in its description', () {
      for (final model in catalogue.where((m) => m.gated)) {
        expect(
          model.description.toLowerCase(),
          contains('token'),
          reason: '${model.name} must warn that a token is needed',
        );
      }
    });
  });

  group('excluded models', () {
    test('a model without tool support is rejected at install time', () async {
      // Gemma 3 270M has no function calling, so schema extraction cannot work.
      expect(GemmaModels.gemma3270m.supportsTools, isFalse);

      await expectLater(
        const ModelManager().install(GemmaModels.gemma3270m),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('error mapping', () {
    test('a 401 is attributed to gating, not to a broken download', () {
      final message = ModelManager.mapDownloadError(
        Exception('HTTP 401 Unauthorized'),
      );
      expect(message.toLowerCase(), contains('token'));
    });
  });
}
