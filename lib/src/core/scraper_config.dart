import '../net/retry_policy.dart';

/// Settings for a scrape.
///
/// The defaults are deliberately conservative and polite: `robots.txt` is
/// honoured, requests to one host are paced, and bodies are capped. A library
/// that made abusive scraping the path of least resistance would push the cost
/// onto sites that never opted in.
class ScraperConfig {
  /// Creates a configuration.
  const ScraperConfig({
    this.timeout = const Duration(seconds: 30),
    this.maxContentSize = 10 * 1024 * 1024,
    this.headers = const {},
    this.userAgent = defaultUserAgent,
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.retryPolicy = const RetryPolicy(),
    this.respectRobotsTxt = true,
    this.useCache = true,
    this.cacheTtl = const Duration(hours: 1),
  });

  /// The stock configuration.
  static const ScraperConfig defaultConfig = ScraperConfig();

  /// A configuration for tests and local fixtures.
  ///
  /// Skips `robots.txt` and retries, and uses a short timeout, so tests are
  /// fast and make no unexpected network calls.
  static const ScraperConfig testing = ScraperConfig(
    timeout: Duration(seconds: 5),
    retryPolicy: RetryPolicy.none,
    respectRobotsTxt: false,
    useCache: false,
  );

  /// The default `User-Agent`.
  ///
  /// Identifies the library honestly and points at the project, so an operator
  /// reading their logs can find out what is hitting them and get in touch.
  /// Impersonating a browser here would make this package's traffic
  /// deliberately hard to identify or block, which is not a default worth
  /// shipping.
  static const String defaultUserAgent =
      'flutter_ai_scrapper/2.0.0 (+https://github.com/raghav117/flutter_scrapper)';

  /// How long a single request may take.
  final Duration timeout;

  /// Largest body accepted, in bytes.
  ///
  /// Enforced *during* the download — the transfer is abandoned once the
  /// threshold is crossed rather than buffered and then rejected.
  final int maxContentSize;

  /// Extra request headers.
  final Map<String, String> headers;

  /// The `User-Agent` sent with each request.
  final String userAgent;

  /// Whether redirects are followed.
  final bool followRedirects;

  /// Redirect ceiling.
  final int maxRedirects;

  /// How failures are retried.
  final RetryPolicy retryPolicy;

  /// Whether `robots.txt` is fetched and obeyed.
  ///
  /// Turning this off is a decision about someone else's server. If you do,
  /// make sure you have the right to.
  final bool respectRobotsTxt;

  /// Whether responses are cached locally.
  final bool useCache;

  /// How long a cached response stays fresh without revalidation.
  final Duration cacheTtl;

  /// Copies this config with the given overrides.
  ScraperConfig copyWith({
    Duration? timeout,
    int? maxContentSize,
    Map<String, String>? headers,
    String? userAgent,
    bool? followRedirects,
    int? maxRedirects,
    RetryPolicy? retryPolicy,
    bool? respectRobotsTxt,
    bool? useCache,
    Duration? cacheTtl,
  }) =>
      ScraperConfig(
        timeout: timeout ?? this.timeout,
        maxContentSize: maxContentSize ?? this.maxContentSize,
        headers: headers ?? this.headers,
        userAgent: userAgent ?? this.userAgent,
        followRedirects: followRedirects ?? this.followRedirects,
        maxRedirects: maxRedirects ?? this.maxRedirects,
        retryPolicy: retryPolicy ?? this.retryPolicy,
        respectRobotsTxt: respectRobotsTxt ?? this.respectRobotsTxt,
        useCache: useCache ?? this.useCache,
        cacheTtl: cacheTtl ?? this.cacheTtl,
      );

  @override
  String toString() => 'ScraperConfig(timeout: $timeout, maxContentSize: '
      '$maxContentSize, respectRobotsTxt: $respectRobotsTxt, '
      'useCache: $useCache)';
}
