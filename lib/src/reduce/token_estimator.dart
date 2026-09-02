/// Heuristic token estimator for context window budgeting.
library;

/// Heuristic token estimator based on character length.
///
/// English text and structured markdown in models like Gemma, LLaMA and GPT
/// average roughly 3.5 to 4.2 characters per token. This estimator uses a
/// 4.0 chars/token rule of thumb.
///
/// Error bar: ±15–20% depending on whitespace, formatting, numbers and
/// multilingual content. For token-tight boundaries, always reserve output
/// headroom via `TokenBudget`.
abstract final class TokenEstimator {
  /// Estimated average characters per token.
  static const double charsPerToken = 4.0;

  /// Estimates the number of tokens in [text].
  static int estimate(String text) {
    if (text.isEmpty) return 0;
    return (text.length / charsPerToken).ceil();
  }

  /// Estimates tokens from character count [charCount].
  static int estimateFromCharCount(int charCount) {
    if (charCount <= 0) return 0;
    return (charCount / charsPerToken).ceil();
  }
}
