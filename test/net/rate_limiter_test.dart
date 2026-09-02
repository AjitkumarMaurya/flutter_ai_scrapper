import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('per-host pacing', () {
    test('spaces consecutive requests to one host', () async {
      final limiter = RateLimiter(minInterval: const Duration(milliseconds: 120));
      final url = Uri.parse('https://example.com/a');

      final started = DateTime.now();
      await limiter.run(url, () async {});
      await limiter.run(url, () async {});
      final elapsed = DateTime.now().difference(started);

      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(110));
    });

    test('does not delay a different host', () async {
      final limiter = RateLimiter(minInterval: const Duration(milliseconds: 300));

      final started = DateTime.now();
      await limiter.run(Uri.parse('https://a.example/x'), () async {});
      await limiter.run(Uri.parse('https://b.example/x'), () async {});
      final elapsed = DateTime.now().difference(started);

      expect(elapsed.inMilliseconds, lessThan(250),
          reason: 'politeness is per-host, not global');
    });

    test('treats host casing as the same host', () async {
      final limiter = RateLimiter(minInterval: const Duration(milliseconds: 120));

      final started = DateTime.now();
      await limiter.run(Uri.parse('https://Example.COM/a'), () async {});
      await limiter.run(Uri.parse('https://example.com/b'), () async {});

      expect(DateTime.now().difference(started).inMilliseconds,
          greaterThanOrEqualTo(110));
    });
  });

  group('crawl-delay override', () {
    test('a host-specific interval replaces the default', () {
      final limiter = RateLimiter(minInterval: const Duration(milliseconds: 100))
        ..setHostInterval('slow.example', const Duration(seconds: 3));

      expect(limiter.intervalFor('slow.example'), const Duration(seconds: 3));
      expect(limiter.intervalFor('other.example'),
          const Duration(milliseconds: 100));
    });

    test('the override is case-insensitive', () {
      final limiter = RateLimiter()
        ..setHostInterval('Slow.Example', const Duration(seconds: 2));

      expect(limiter.intervalFor('slow.example'), const Duration(seconds: 2));
    });
  });

  group('concurrency', () {
    test('caps simultaneous requests to one host', () async {
      final limiter = RateLimiter(
        minInterval: Duration.zero,
        maxConcurrentPerHost: 2,
      );
      final url = Uri.parse('https://example.com/x');

      var running = 0;
      var peak = 0;

      await Future.wait(List.generate(8, (_) async {
        await limiter.run(url, () async {
          running++;
          if (running > peak) peak = running;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          running--;
        });
      }));

      expect(peak, lessThanOrEqualTo(2));
    });

    test('a slot is released even when the action throws', () async {
      final limiter = RateLimiter(
        minInterval: Duration.zero,
        maxConcurrentPerHost: 1,
      );
      final url = Uri.parse('https://example.com/x');

      await expectLater(
        limiter.run(url, () async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );

      // A leaked slot would deadlock every later request to this host.
      await expectLater(
        limiter.run(url, () async => 'ok').timeout(const Duration(seconds: 2)),
        completion('ok'),
      );
    });
  });

  group('unlimited', () {
    test('imposes no delay', () async {
      final limiter = RateLimiter.unlimited();
      final url = Uri.parse('https://example.com/x');

      final started = DateTime.now();
      for (var i = 0; i < 5; i++) {
        await limiter.run(url, () async {});
      }

      expect(DateTime.now().difference(started).inMilliseconds, lessThan(100));
    });
  });

  group('reset', () {
    test('clears timing state and frees waiters', () async {
      final limiter = RateLimiter(minInterval: const Duration(milliseconds: 200))
        ..setHostInterval('a.example', const Duration(seconds: 5));

      await limiter.run(Uri.parse('https://a.example/x'), () async {});
      limiter.reset();

      expect(limiter.intervalFor('a.example'),
          const Duration(milliseconds: 200));
    });
  });
}
