import 'dart:math' as math;

/// How failed requests are retried.
///
/// The 1.x implementation computed `initialDelay * (multiplier * attempt)`,
/// which is **linear** — 2s, 4s, 6s — despite documenting exponential backoff.
/// It also had no jitter, so every client retrying a struggling host did so in
/// lockstep and hit it again simultaneously. Both are fixed here.
class RetryPolicy {
  /// Creates a retry policy.
  const RetryPolicy({
    this.enabled = true,
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.jitterFactor = 0.25,
    this.retryableStatusCodes = const {408, 425, 429, 500, 502, 503, 504},
  })  : assert(maxAttempts >= 1, 'maxAttempts must be at least 1'),
        assert(multiplier >= 1.0, 'multiplier must be at least 1.0'),
        assert(
          jitterFactor >= 0.0 && jitterFactor <= 1.0,
          'jitterFactor must be between 0.0 and 1.0',
        );

  /// A policy that never retries.
  static const RetryPolicy none = RetryPolicy(enabled: false, maxAttempts: 1);

  /// Whether retries happen at all.
  final bool enabled;

  /// Total attempts, including the first. `3` means one try plus two retries.
  final int maxAttempts;

  /// Delay before the first retry.
  final Duration initialDelay;

  /// Growth factor per attempt. `2.0` doubles the wait each time.
  final double multiplier;

  /// Ceiling on any single delay.
  final Duration maxDelay;

  /// Random spread applied to each delay, as a fraction of it.
  ///
  /// `0.25` means the actual wait lands anywhere in ±25% of the computed
  /// delay. Without this, many clients backing off from the same outage
  /// synchronise and hammer the recovering server in waves.
  final double jitterFactor;

  /// Status codes worth retrying.
  final Set<int> retryableStatusCodes;

  /// The delay before retry number [attempt] (1-based).
  ///
  /// Genuinely exponential: `initialDelay * multiplier^(attempt-1)`, capped at
  /// [maxDelay], then spread by [jitterFactor]. Pass [random] to make the
  /// jitter deterministic in tests.
  Duration delayForAttempt(int attempt, {math.Random? random}) {
    if (attempt <= 0) return Duration.zero;

    final growth = math.pow(multiplier, attempt - 1).toDouble();
    final baseMs = initialDelay.inMilliseconds * growth;
    final cappedMs = math.min(baseMs, maxDelay.inMilliseconds.toDouble());

    if (jitterFactor == 0) return Duration(milliseconds: cappedMs.round());

    // Spread across [1 - jitterFactor, 1 + jitterFactor].
    final rng = random ?? math.Random();
    final spread = 1.0 + (rng.nextDouble() * 2 - 1) * jitterFactor;
    final jittered = (cappedMs * spread).round().clamp(0, maxDelay.inMilliseconds);

    return Duration(milliseconds: jittered);
  }

  /// Whether [statusCode] is worth another attempt.
  bool shouldRetryStatus(int statusCode) =>
      retryableStatusCodes.contains(statusCode);

  /// Copies this policy with the given overrides.
  RetryPolicy copyWith({
    bool? enabled,
    int? maxAttempts,
    Duration? initialDelay,
    double? multiplier,
    Duration? maxDelay,
    double? jitterFactor,
    Set<int>? retryableStatusCodes,
  }) =>
      RetryPolicy(
        enabled: enabled ?? this.enabled,
        maxAttempts: maxAttempts ?? this.maxAttempts,
        initialDelay: initialDelay ?? this.initialDelay,
        multiplier: multiplier ?? this.multiplier,
        maxDelay: maxDelay ?? this.maxDelay,
        jitterFactor: jitterFactor ?? this.jitterFactor,
        retryableStatusCodes: retryableStatusCodes ?? this.retryableStatusCodes,
      );

  @override
  String toString() => 'RetryPolicy(enabled: $enabled, maxAttempts: '
      '$maxAttempts, initialDelay: $initialDelay, multiplier: $multiplier)';
}
