import 'dart:async' as async;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/cancellation.dart';
import '../core/scraper_config.dart';
import '../core/scraper_exceptions.dart';
import 'encoding_detector.dart';
import 'rate_limiter.dart';
import 'robots_policy.dart';

/// A fetched page.
class FetchResponse {
  /// Creates a fetch response.
  const FetchResponse({
    required this.url,
    required this.body,
    required this.statusCode,
    required this.headers,
    required this.bytesReceived,
    this.fromCache = false,
    this.notModified = false,
  });

  /// The final URL, after any redirects.
  final String url;

  /// The decoded body.
  final String body;

  /// The response status.
  final int statusCode;

  /// Response headers, lowercase keys.
  final Map<String, String> headers;

  /// How many bytes were read off the wire.
  final int bytesReceived;

  /// Whether this came from the local cache rather than the network.
  final bool fromCache;

  /// Whether the server answered `304 Not Modified`.
  final bool notModified;

  /// The `ETag`, when the server sent one.
  String? get etag => headers['etag'];

  /// The `Last-Modified` value, when the server sent one.
  String? get lastModified => headers['last-modified'];

  /// The raw `Content-Type`.
  String? get contentType => headers['content-type'];
}

/// Performs HTTP requests for the scraper.
///
/// Three things here were broken or missing in 1.x:
///
/// - **The size limit did nothing.** It was checked after `http.get()` had
///   already buffered the entire body into memory, so an enormous page still
///   caused the allocation it was supposed to prevent. This streams and aborts
///   mid-download instead.
/// - **Timeouts were never caught.** The package declared its own
///   `TimeoutException`, which shadowed `dart:async`'s inside the same library,
///   so `on TimeoutException` did not match what `.timeout()` throws. Every
///   timeout fell through to the generic handler and was reported as an
///   unexpected network error. `dart:async` is now imported prefixed.
/// - **No politeness.** No rate limiting, no `robots.txt`.
class Fetcher {
  /// Creates a fetcher.
  Fetcher({
    required this.config,
    http.Client? client,
    RateLimiter? rateLimiter,
    RobotsPolicy? robotsPolicy,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        rateLimiter = rateLimiter ?? RateLimiter(),
        robotsPolicy = robotsPolicy ?? RobotsPolicy();

  /// Timeouts, size limits, headers and retry settings.
  final ScraperConfig config;

  /// Per-host pacing.
  final RateLimiter rateLimiter;

  /// `robots.txt` enforcement.
  final RobotsPolicy robotsPolicy;

  final http.Client _client;
  final bool _ownsClient;
  bool _disposed = false;

  /// Fetches [url].
  ///
  /// Pass [etag] or [lastModified] to make the request conditional; a `304`
  /// comes back as a [FetchResponse] with `notModified` set and an empty body.
  Future<FetchResponse> fetch(
    String url, {
    String? etag,
    String? lastModified,
    CancellationToken? cancellationToken,
  }) async {
    if (_disposed) {
      throw StateError('Fetcher has been disposed');
    }

    final uri = _parseUrl(url);
    cancellationToken?.throwIfCancelled(url: url);

    if (config.respectRobotsTxt) {
      final rules = await robotsPolicy.rulesFor(uri, config.userAgent);
      if (!rules.isAllowed(uri.path)) {
        throw RobotsDisallowedException(url, config.userAgent);
      }
      // Honour the site's own stated pace over our default.
      final crawlDelay = rules.crawlDelay;
      if (crawlDelay != null) {
        rateLimiter.setHostInterval(uri.host, crawlDelay);
      }
    }

    return rateLimiter.run(
      uri,
      () => _fetchWithRetry(
        uri,
        etag: etag,
        lastModified: lastModified,
        cancellationToken: cancellationToken,
      ),
    );
  }

  Future<FetchResponse> _fetchWithRetry(
    Uri uri, {
    String? etag,
    String? lastModified,
    CancellationToken? cancellationToken,
  }) async {
    final policy = config.retryPolicy;
    final attempts = policy.enabled ? policy.maxAttempts : 1;

    ScraperException? lastError;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      cancellationToken?.throwIfCancelled(url: uri.toString());

      try {
        return await _send(
          uri,
          etag: etag,
          lastModified: lastModified,
          cancellationToken: cancellationToken,
        );
      } on CancelledException {
        rethrow;
      } on RobotsDisallowedException {
        rethrow;
      } on ContentTooLargeException {
        rethrow; // Retrying cannot make the page smaller.
      } on ScraperException catch (error) {
        lastError = error;
        if (attempt == attempts || !_isRetryable(error)) rethrow;

        final delay = policy.delayForAttempt(attempt);
        await Future<void>.delayed(delay);
      }
    }

    throw lastError ?? NetworkException(uri.toString(), 'Request failed');
  }

  Future<FetchResponse> _send(
    Uri uri, {
    String? etag,
    String? lastModified,
    CancellationToken? cancellationToken,
  }) async {
    final request = http.Request('GET', uri)
      ..followRedirects = config.followRedirects
      ..maxRedirects = config.maxRedirects;

    request.headers.addAll({
      ...config.headers,
      'User-Agent': config.userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Encoding': 'gzip, deflate',
      'If-None-Match': ?etag,
      'If-Modified-Since': ?lastModified,
    });

    try {
      final streamed =
          await _client.send(request).timeout(config.timeout);

      final headers = <String, String>{
        for (final entry in streamed.headers.entries)
          entry.key.toLowerCase(): entry.value,
      };
      final finalUrl = _finalUrl(streamed, uri);

      if (streamed.statusCode == 304) {
        await streamed.stream.drain<void>();
        return FetchResponse(
          url: finalUrl,
          body: '',
          statusCode: 304,
          headers: headers,
          bytesReceived: 0,
          notModified: true,
        );
      }

      if (streamed.statusCode >= 400) {
        await streamed.stream.drain<void>();
        throw HttpStatusException(
          finalUrl,
          streamed.statusCode,
          reasonPhrase: streamed.reasonPhrase,
        );
      }

      // Reject on the declared length before reading a single byte, when the
      // server is honest enough to tell us.
      final declared = streamed.contentLength;
      if (declared != null && declared > config.maxContentSize) {
        await streamed.stream.drain<void>();
        throw ContentTooLargeException(
          declared,
          config.maxContentSize,
          url: finalUrl,
        );
      }

      final bytes = await _readCapped(
        streamed.stream,
        finalUrl,
        cancellationToken: cancellationToken,
      );

      return FetchResponse(
        url: finalUrl,
        body: EncodingDetector.decode(
          bytes,
          contentTypeHeader: headers['content-type'],
        ),
        statusCode: streamed.statusCode,
        headers: headers,
        bytesReceived: bytes.length,
      );
    } on async.TimeoutException catch (error) {
      // The whole reason ScraperTimeoutException is not called
      // TimeoutException: this clause has to match dart:async's type, and in
      // 1.x the package's own class shadowed it so this never fired.
      throw ScraperTimeoutException(
        config.timeout,
        url: uri.toString(),
        cause: error,
      );
    } on SocketException catch (error, stackTrace) {
      throw NetworkException(
        uri.toString(),
        'Network unreachable: ${error.message}',
        cause: error,
        stackTrace: stackTrace,
      );
    } on HandshakeException catch (error, stackTrace) {
      throw NetworkException(
        uri.toString(),
        'TLS handshake failed: ${error.message}',
        cause: error,
        stackTrace: stackTrace,
      );
    } on http.ClientException catch (error, stackTrace) {
      throw NetworkException(
        uri.toString(),
        'Request failed: ${error.message}',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Reads [stream], aborting as soon as the size limit is passed.
  ///
  /// This is the point of streaming: an oversized body is abandoned partway
  /// through rather than fully buffered and then rejected.
  Future<Uint8List> _readCapped(
    Stream<List<int>> stream,
    String url, {
    CancellationToken? cancellationToken,
  }) async {
    final builder = BytesBuilder(copy: false);
    final subscription = async.StreamIterator<List<int>>(stream);

    try {
      while (await subscription.moveNext()) {
        if (cancellationToken?.isCancelled ?? false) {
          throw CancelledException(url: url);
        }

        builder.add(subscription.current);

        if (builder.length > config.maxContentSize) {
          throw ContentTooLargeException(
            builder.length,
            config.maxContentSize,
            url: url,
          );
        }
      }
    } finally {
      await subscription.cancel();
    }

    return builder.takeBytes();
  }

  static String _finalUrl(http.StreamedResponse response, Uri fallback) {
    final requested = response.request?.url;
    return (requested ?? fallback).toString();
  }

  static bool _isRetryable(ScraperException error) => switch (error) {
        HttpStatusException(:final isRetryable) => isRetryable,
        ScraperTimeoutException() => true,
        NetworkException() => true,
        _ => false,
      };

  Uri _parseUrl(String url) {
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException catch (error) {
      throw InvalidUrlException(url, 'could not be parsed', cause: error);
    }

    if (!uri.hasScheme) {
      throw InvalidUrlException(url, 'missing a scheme (http:// or https://)');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw InvalidUrlException(url, 'scheme "${uri.scheme}" is not supported');
    }
    if (uri.host.isEmpty) {
      throw InvalidUrlException(url, 'missing a host');
    }

    return uri;
  }

  /// Releases held resources. Safe to call more than once.
  ///
  /// 1.x could double-close its client and complete an already-completed
  /// completer; both are guarded now.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ownsClient) _client.close();
    robotsPolicy.dispose();
  }
}
