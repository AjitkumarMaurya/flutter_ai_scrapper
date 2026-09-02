import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TokenBudget Provider Derivation', () {
    test('derives token budget from small local provider capabilities', () {
      final localProvider = FakeAiProvider(
        capabilities: const AiCapabilities(
          maxContextTokens: 2048,
          maxOutputTokens: 512,
          isLocal: true,
        ),
      );

      final budget = TokenBudget.fromProvider(localProvider);
      expect(budget.maxContextTokens, 2048);
      expect(budget.reservedOutputTokens, 512);
      expect(budget.availableInputTokens, 1536);
    });

    test('derives token budget from large cloud provider capabilities', () {
      final cloudProvider = FakeAiProvider(
        capabilities: const AiCapabilities(
          maxContextTokens: 128000,
          maxOutputTokens: 4096,
          isLocal: false,
        ),
      );

      final budget = TokenBudget.fromProvider(cloudProvider);
      expect(budget.maxContextTokens, 128000);
      expect(budget.reservedOutputTokens, 4096);
      expect(budget.availableInputTokens, 123904);
    });
  });
}
