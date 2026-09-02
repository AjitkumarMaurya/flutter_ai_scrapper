import 'dart:async' as async;
import 'dart:convert';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A config that never touches robots.txt or the retry clock.
const _config = ScraperConfig(
  timeout: Duration(milliseconds: 300),
  retryPolicy: RetryPolicy.none,
  respectRobotsTxt: false,
  useCache: false,
);

Fetcher _fetcherReturning(
  http.StreamedResponse Function(http.BaseRequest request) handler, {
  ScraperConfig config = _config,
}) =>
    Fetcher(
      config: config,
      client: MockClient.streaming((request, bodyStream) async => handler(request)),
      rateLimiter: RateLimiter.unlimited(),
    );

http.StreamedResponse _html(String body, {Map<String, String>? headers, int status = 200}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: headers ?? const {'content-type': 'text/html; charset=utf-8'},
    );

void main() {
  group('BUG-3 — timeouts must surface as a timeout', () {
    test('a slow response throws ScraperTimeoutException', () async {
      final fetcher = Fetcher(
        config: _config,
        client: MockClient.streaming((request, _) async {
          // Outlive the 300ms timeout.
          await Future<void>.delayed(const Duration(seconds: 2));
          return _html('<html></html>');
        }),
        rateLimiter: RateLimiter.unlimited(),
      );
      addTearDown(fetcher.dispose);

      // In 1.x the package's own TimeoutException shadowed dart:async's inside
      // the same library, so `on TimeoutException` never matched what
      // .timeout() throws — every timeout was relabelled
      // "NetworkException: Unexpected error".
      await expectLater(
        fetcher.fetch('https://example.com'),
        throwsA(isA<ScraperTimeoutException>()),
      );
    });

    test('is not mislabelled as a generic network error', () async {
      final fetcher = Fetcher(
        config: _config,
        client: MockClient.streaming((request, _) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return _html('<html></html>');
        }),
        rateLimiter: RateLimiter.unlimited(),
      );
      addTearDown(fetcher.dispose);

      try {
        await fetcher.fetch('https://example.com');
        fail('should have thrown');
      } on ScraperException catch (e) {
        expect(e, isNot(isA<NetworkException>()));
        expect(e, isA<ScraperTimeoutException>());
        expect((e as ScraperTimeoutException).timeout, _config.timeout);
      }
    });

    test('the package timeout type is distinct from dart:async\'s', () {
      const e = ScraperTimeoutException(Duration(seconds: 1));
      expect(e, isNot(isA<async.TimeoutException>()));
    });
  });

  group('size cap is enforced during download', () {
    test('aborts a body that exceeds the limit mid-stream', () async {
      const limit = 1024;
      var chunksSent = 0;

      final fetcher = Fetcher(
        config: _config.copyWith(maxContentSize: limit),
        client: MockClient.streaming((request, _) async {
          // A LAZY generator: each chunk is produced only when pulled, so
          // chunksSent measures what was actually consumed. (An eager
          // List.generate would count all 100 before the stream is even read,
          // and could not distinguish early abort from full buffering.)
          Stream<List<int>> chunks() async* {
            for (var i = 0; i < 100; i++) {
              chunksSent++;
              yield List.filled(100, 0x61);
            }
          }

          // No declared Content-Length, so only streaming enforcement can stop it.
          return http.StreamedResponse(chunks(), 200);
        }),
        rateLimiter: RateLimiter.unlimited(),
      );
      addTearDown(fetcher.dispose);

      await expectLater(
        fetcher.fetch('https://example.com'),
        throwsA(isA<ContentTooLargeException>()),
      );

      // The whole point: it stopped early rather than buffering all 10,000
      // bytes and then complaining. 1.x checked the size only after http.get()
      // had already materialised the entire body.
      expect(chunksSent, lessThan(100));
    });

    test('rejects on a declared Content-Length before reading', () async {
      final fetcher = _fetcherReturning(
        (_) => http.StreamedResponse(
          Stream.value(utf8.encode('x')),
          200,
          contentLength: 50 * 1024 * 1024,
        ),
        config: _config.copyWith(maxContentSize: 1024),
      );
      addTearDown(fetcher.dispose);

      await expectLater(
        fetcher.fetch('https://example.com'),
        throwsA(isA<ContentTooLargeException>()),
      );
    });

    test('a body under the limit succeeds', () async {
      final fetcher = _fetcherReturning((_) => _html('<html><body>ok</body></html>'));
      addTearDown(fetcher.dispose);

      final response = await fetcher.fetch('https://example.com');
      expect(response.body, contains('ok'));
      expect(response.statusCode, 200);
    });
  });

  group('status handling', () {
    test('4xx and 5xx raise HttpStatusException with the code', () async {
      for (final code in const [404, 403, 500]) {
        final fetcher = _fetcherReturning((_) => _html('nope', status: code));
        addTearDown(fetcher.dispose);

        try {
          await fetcher.fetch('https://example.com');
          fail('should have thrown for $code');
        } on HttpStatusException catch (e) {
          expect(e.statusCode, code);
        }
      }
    });

    test('classifies retryable versus permanent', () {
      expect(const HttpStatusException('u', 503).isRetryable, isTrue);
      expect(const HttpStatusException('u', 404).isRetryable, isFalse);
      expect(const HttpStatusException('u', 404).isClientError, isTrue);
    });

    test('user messages stay non-technical', () {
      expect(const HttpStatusException('u', 404).userMessage,
          'That page could not be found.');
      expect(const HttpStatusException('u', 429).userMessage,
          contains('rate-limiting'));
    });
  });

  group('conditional requests', () {
    test('sends validators when given them', () async {
      late http.BaseRequest captured;
      final fetcher = _fetcherReturning((request) {
        captured = request;
        return _html('<html></html>');
      });
      addTearDown(fetcher.dispose);

      await fetcher.fetch(
        'https://example.com',
        etag: '"abc"',
        lastModified: 'Wed, 21 Oct 2015 07:28:00 GMT',
      );

      expect(captured.headers['If-None-Match'], '"abc"');
      expect(captured.headers['If-Modified-Since'],
          'Wed, 21 Oct 2015 07:28:00 GMT');
    });

    test('omits validators when there are none', () async {
      late http.BaseRequest captured;
      final fetcher = _fetcherReturning((request) {
        captured = request;
        return _html('<html></html>');
      });
      addTearDown(fetcher.dispose);

      await fetcher.fetch('https://example.com');

      expect(captured.headers.containsKey('If-None-Match'), isFalse);
      expect(captured.headers.containsKey('If-Modified-Since'), isFalse);
    });

    test('304 comes back flagged, not as an error', () async {
      final fetcher = _fetcherReturning(
        (_) => http.StreamedResponse(const Stream.empty(), 304),
      );
      addTearDown(fetcher.dispose);

      final response = await fetcher.fetch('https://example.com', etag: '"x"');
      expect(response.notModified, isTrue);
      expect(response.statusCode, 304);
    });
  });

  group('URL validation', () {
    test('rejects unusable addresses', () async {
      final fetcher = _fetcherReturning((_) => _html('x'));
      addTearDown(fetcher.dispose);

      for (final url in const ['not-a-url', 'ftp://example.com', 'http://']) {
        await expectLater(
          fetcher.fetch(url),
          throwsA(isA<InvalidUrlException>()),
          reason: url,
        );
      }
    });
  });

  group('user agent', () {
    test('identifies the library honestly and points somewhere', () async {
      late http.BaseRequest captured;
      final fetcher = _fetcherReturning((request) {
        captured = request;
        return _html('<html></html>');
      });
      addTearDown(fetcher.dispose);

      await fetcher.fetch('https://example.com');

      final agent = captured.headers['User-Agent']!;
      expect(agent, contains('flutter_ai_scrapper'));
      expect(agent, contains('https://'),
          reason: 'an operator reading their logs must be able to find us');
      expect(agent.toLowerCase(), isNot(contains('mozilla')),
          reason: 'impersonating a browser is not a default worth shipping');
    });
  });

  group('cancellation', () {
    test('a cancelled token stops the fetch', () async {
      final fetcher = _fetcherReturning((_) => _html('<html></html>'));
      addTearDown(fetcher.dispose);

      final token = CancellationToken()..cancel();

      await expectLater(
        fetcher.fetch('https://example.com', cancellationToken: token),
        throwsA(isA<CancelledException>()),
      );
    });
  });

  group('dispose', () {
    test('is idempotent', () {
      final fetcher = _fetcherReturning((_) => _html('x'));
      expect(fetcher.dispose, returnsNormally);
      expect(fetcher.dispose, returnsNormally);
    });

    test('using a disposed fetcher is a StateError', () async {
      final fetcher = _fetcherReturning((_) => _html('x'))..dispose();
      await expectLater(
        fetcher.fetch('https://example.com'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
