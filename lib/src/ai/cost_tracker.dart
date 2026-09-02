/// Cost tracking, usage metrics aggregation, and savings calculation.
library;

import 'ai_provider.dart';

/// Pricing specification for a language model per million tokens.
class ModelPricing {
  /// Creates a [ModelPricing] spec.
  const ModelPricing({
    required this.costPerMTokIn,
    required this.costPerMTokOut,
  });

  /// Cost in USD per million prompt tokens.
  final double costPerMTokIn;

  /// Cost in USD per million completion tokens.
  final double costPerMTokOut;

  /// Estimates dollar cost for the provided [usage].
  double estimateCost(TokenUsage usage) {
    final inCost = (usage.promptTokens / 1000000.0) * costPerMTokIn;
    final outCost = (usage.completionTokens / 1000000.0) * costPerMTokOut;
    return inCost + outCost;
  }

  /// GPT-4o pricing (~$2.50 / $10.00 per MTok).
  static const gpt4o = ModelPricing(costPerMTokIn: 2.50, costPerMTokOut: 10.00);

  /// GPT-4o-mini pricing (~$0.15 / $0.60 per MTok).
  static const gpt4oMini =
      ModelPricing(costPerMTokIn: 0.15, costPerMTokOut: 0.60);

  /// Claude 3.5 Sonnet pricing (~$3.00 / $15.00 per MTok).
  static const claude35Sonnet =
      ModelPricing(costPerMTokIn: 3.00, costPerMTokOut: 15.00);

  /// Claude 3.5 Haiku pricing (~$0.80 / $4.00 per MTok).
  static const claude35Haiku =
      ModelPricing(costPerMTokIn: 0.80, costPerMTokOut: 4.00);

  /// DeepSeek-V3 pricing (~$0.14 / $0.28 per MTok).
  static const deepseekV3 =
      ModelPricing(costPerMTokIn: 0.14, costPerMTokOut: 0.28);

  /// Local on-device model pricing (0.0 USD).
  static const zero = ModelPricing(costPerMTokIn: 0.0, costPerMTokOut: 0.0);

  /// Resolves pricing from known model identifiers or provider capability rates.
  static ModelPricing forModel(String model, {AiCapabilities? capabilities}) {
    final lower = model.toLowerCase();
    if (lower.contains('mini')) return gpt4oMini;
    if (lower.contains('gpt-4o')) return gpt4o;
    if (lower.contains('haiku')) return claude35Haiku;
    if (lower.contains('sonnet')) return claude35Sonnet;
    if (lower.contains('deepseek')) return deepseekV3;

    if (capabilities != null &&
        capabilities.costPerMTokIn != null &&
        capabilities.costPerMTokOut != null) {
      return ModelPricing(
        costPerMTokIn: capabilities.costPerMTokIn!,
        costPerMTokOut: capabilities.costPerMTokOut!,
      );
    }

    return zero;
  }
}

/// Aggregates token usage and estimated spend across scraping sessions.
class UsageSession {
  /// Creates a [UsageSession].
  UsageSession({this.onUsage});

  /// Optional callback triggered on every recorded provider usage event.
  final void Function(TokenUsage delta, double deltaCost)? onUsage;

  int _promptTokens = 0;
  int _completionTokens = 0;
  double _estimatedTotalCost = 0.0;
  int _callsCount = 0;

  int _shortCircuitCount = 0;
  int _savedTokens = 0;
  double _savedCost = 0.0;

  /// Total prompt tokens consumed.
  int get promptTokens => _promptTokens;

  /// Total completion tokens consumed.
  int get completionTokens => _completionTokens;

  /// Total tokens consumed.
  int get totalTokens => _promptTokens + _completionTokens;

  /// Total estimated cost in USD.
  double get estimatedTotalCost => _estimatedTotalCost;

  /// Number of model extraction calls executed.
  int get callsCount => _callsCount;

  /// Number of pages where structured harvesting or recipes avoided model inference.
  int get shortCircuitCount => _shortCircuitCount;

  /// Estimated tokens saved by short-circuiting before calling an AI provider.
  int get savedTokens => _savedTokens;

  /// Estimated dollar cost saved by short-circuiting.
  double get savedCost => _savedCost;

  /// Records usage from a single provider call.
  void recordUsage(
    TokenUsage usage, {
    ModelPricing pricing = ModelPricing.zero,
  }) {
    _promptTokens += usage.promptTokens;
    _completionTokens += usage.completionTokens;
    _callsCount++;

    final cost = pricing.estimateCost(usage);
    _estimatedTotalCost += cost;

    onUsage?.call(usage, cost);
  }

  /// Records a short-circuit where deterministic structured data satisfied the schema
  /// without requiring an LLM inference call.
  void recordShortCircuit({
    int estimatedTokens = 450,
    ModelPricing benchmarkPricing = ModelPricing.gpt4oMini,
  }) {
    _shortCircuitCount++;
    _savedTokens += estimatedTokens;
    final saved = benchmarkPricing.estimateCost(
      TokenUsage(promptTokens: estimatedTokens, completionTokens: 50),
    );
    _savedCost += saved;
  }

  /// Resets session counters.
  void reset() {
    _promptTokens = 0;
    _completionTokens = 0;
    _estimatedTotalCost = 0.0;
    _callsCount = 0;
    _shortCircuitCount = 0;
    _savedTokens = 0;
    _savedCost = 0.0;
  }
}
