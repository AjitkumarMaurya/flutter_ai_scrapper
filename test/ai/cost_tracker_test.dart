import 'package:flutter_ai_scrapper/src/ai/ai_provider.dart';
import 'package:flutter_ai_scrapper/src/ai/cost_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cost & Usage Accounting', () {
    test('calculates accurate dollar cost from token usage and model rates', () {
      const usage = TokenUsage(promptTokens: 1000, completionTokens: 500);

      final gpt4oCost = ModelPricing.gpt4o.estimateCost(usage);
      // (1000 / 1e6 * 2.50) + (500 / 1e6 * 10.00) = 0.0025 + 0.0050 = 0.0075
      expect(gpt4oCost, closeTo(0.0075, 0.0001));

      final miniCost = ModelPricing.gpt4oMini.estimateCost(usage);
      // (1000 / 1e6 * 0.15) + (500 / 1e6 * 0.60) = 0.00015 + 0.00030 = 0.00045
      expect(miniCost, closeTo(0.00045, 0.00001));

      final zeroCost = ModelPricing.zero.estimateCost(usage);
      expect(zeroCost, equals(0.0));
    });

    test('resolves pricing for known models', () {
      expect(ModelPricing.forModel('gpt-4o-mini').costPerMTokIn, 0.15);
      expect(ModelPricing.forModel('claude-3-5-sonnet-20241022').costPerMTokIn, 3.00);
      expect(ModelPricing.forModel('deepseek-chat').costPerMTokIn, 0.14);
      expect(ModelPricing.forModel('gemma-3-1b').costPerMTokIn, 0.0);
    });

    test('UsageSession tracks aggregate spend and invocations', () {
      var callbackTriggered = false;
      final session = UsageSession(
        onUsage: (delta, cost) {
          callbackTriggered = true;
          expect(delta.promptTokens, 500);
        },
      );

      session.recordUsage(
        const TokenUsage(promptTokens: 500, completionTokens: 100),
        pricing: ModelPricing.gpt4o,
      );

      expect(session.callsCount, 1);
      expect(session.promptTokens, 500);
      expect(session.completionTokens, 100);
      expect(session.totalTokens, 600);
      expect(session.estimatedTotalCost, greaterThan(0.0));
      expect(callbackTriggered, isTrue);
    });

    test('UsageSession tracks savings from short-circuiting', () {
      final session = UsageSession();

      session.recordShortCircuit(estimatedTokens: 600);
      session.recordShortCircuit(estimatedTokens: 400);

      expect(session.shortCircuitCount, 2);
      expect(session.savedTokens, 1000);
      expect(session.savedCost, greaterThan(0.0));
    });
  });
}
