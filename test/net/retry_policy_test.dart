import 'dart:math' as math;

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BUG-4 — backoff must be exponential, not linear', () {
    // Deterministic: jitter off, so the curve itself is under test.
    const policy = RetryPolicy(
      initialDelay: Duration(seconds: 1),
      multiplier: 2.0,
      maxDelay: Duration(minutes: 1),
      jitterFactor: 0,
    );

    test('doubles each attempt', () {
      expect(policy.delayForAttempt(1).inMilliseconds, 1000);
      expect(policy.delayForAttempt(2).inMilliseconds, 2000);
      expect(policy.delayForAttempt(3).inMilliseconds, 4000);
      expect(policy.delayForAttempt(4).inMilliseconds, 8000);
    });

    test('is not the linear curve 1.x produced', () {
      // 1.x computed initialDelay * (multiplier * attempt) — 2s, 4s, 6s —
      // while documenting exponential backoff. Attempt 4 is where the two
      // curves separate unmistakably: linear gives 8s, exponential 8s... so
      // check attempt 5: linear 10s, exponential 16s.
      final linear5 = 1000 * (2.0 * 5); // what 1.x would have produced
      expect(policy.delayForAttempt(5).inMilliseconds, 16000);
      expect(policy.delayForAttempt(5).inMilliseconds,
          isNot(closeTo(linear5, 1)));
    });

    test('attempt 0 and below wait not at all', () {
      expect(policy.delayForAttempt(0), Duration.zero);
      expect(policy.delayForAttempt(-1), Duration.zero);
    });

    test('never exceeds maxDelay', () {
      const capped = RetryPolicy(
        initialDelay: Duration(seconds: 1),
        multiplier: 2.0,
        maxDelay: Duration(seconds: 5),
        jitterFactor: 0,
      );
      for (var attempt = 1; attempt <= 20; attempt++) {
        expect(capped.delayForAttempt(attempt).inSeconds, lessThanOrEqualTo(5));
      }
    });
  });

  group('jitter', () {
    test('spreads delays around the computed value', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 10),
        multiplier: 1.0,
        jitterFactor: 0.25,
      );

      final observed = <int>{};
      for (var i = 0; i < 200; i++) {
        final ms = policy.delayForAttempt(1, random: math.Random(i)).inMilliseconds;
        // Within ±25% of 10s.
        expect(ms, inInclusiveRange(7500, 12500));
        observed.add(ms);
      }

      // Without jitter every client backs off in lockstep and hits a
      // recovering server simultaneously. Many distinct values proves spread.
      expect(observed.length, greaterThan(50));
    });

    test('jitterFactor 0 is exactly deterministic', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 2),
        multiplier: 2.0,
        jitterFactor: 0,
      );
      final values = List.generate(20, (_) => policy.delayForAttempt(3));
      expect(values.toSet().length, 1);
    });

    test('jittered delay still respects maxDelay', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 10),
        multiplier: 2.0,
        maxDelay: Duration(seconds: 12),
        jitterFactor: 1.0,
      );
      for (var i = 0; i < 100; i++) {
        final ms = policy.delayForAttempt(9, random: math.Random(i)).inMilliseconds;
        expect(ms, lessThanOrEqualTo(12000));
      }
    });
  });

  group('retryable statuses', () {
    const policy = RetryPolicy();

    test('transient failures retry', () {
      for (final code in const [408, 425, 429, 500, 502, 503, 504]) {
        expect(policy.shouldRetryStatus(code), isTrue, reason: '$code');
      }
    });

    test('permanent failures do not', () {
      for (final code in const [400, 401, 403, 404, 410, 422]) {
        expect(policy.shouldRetryStatus(code), isFalse, reason: '$code');
      }
    });
  });

  group('RetryPolicy.none', () {
    test('is a single attempt with retries off', () {
      expect(RetryPolicy.none.enabled, isFalse);
      expect(RetryPolicy.none.maxAttempts, 1);
    });
  });
}
