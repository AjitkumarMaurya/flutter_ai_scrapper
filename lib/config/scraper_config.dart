/// Configuration options for the MobileScraper
class ScraperConfig {
  /// Request timeout duration (default: 30 seconds)
  final Duration timeout;

  /// Maximum content size in bytes (default: 10MB)
  final int maxContentSize;

  /// Custom headers to include in requests
  final Map<String, String> headers;

  /// User agent string
  final String userAgent;

  /// Whether to follow redirects (default: true)
  final bool followRedirects;

  /// Maximum number of redirects to follow (default: 5)
  final int maxRedirects;

  /// Whether to verify SSL certificates (default: true)
  final bool verifySSL;

  /// Request retry configuration
  final RetryConfig retryConfig;

  const ScraperConfig({
    this.timeout = const Duration(seconds: 30),
    this.maxContentSize = 10 * 1024 * 1024, // 10MB
    this.headers = const {},
    this.userAgent = 'flutter_scrapper/0.1.0',
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.verifySSL = true,
    this.retryConfig = const RetryConfig(),
  });

  /// Default configuration
  static const ScraperConfig defaultConfig = ScraperConfig();

  /// Copy with modifications
  ScraperConfig copyWith({
    Duration? timeout,
    int? maxContentSize,
    Map<String, String>? headers,
    String? userAgent,
    bool? followRedirects,
    int? maxRedirects,
    bool? verifySSL,
    RetryConfig? retryConfig,
  }) {
    return ScraperConfig(
      timeout: timeout ?? this.timeout,
      maxContentSize: maxContentSize ?? this.maxContentSize,
      headers: headers ?? this.headers,
      userAgent: userAgent ?? this.userAgent,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
      verifySSL: verifySSL ?? this.verifySSL,
      retryConfig: retryConfig ?? this.retryConfig,
    );
  }

  @override
  String toString() {
    return 'ScraperConfig(timeout: $timeout, maxContentSize: $maxContentSize, '
        'followRedirects: $followRedirects, maxRedirects: $maxRedirects)';
  }
}

/// Configuration for retry behavior
class RetryConfig {
  /// Whether to enable retries (default: true)
  final bool enabled;

  /// Maximum number of retry attempts (default: 3)
  final int maxAttempts;

  /// Initial delay between retries (default: 1 second)
  final Duration initialDelay;

  /// Multiplier for exponential backoff (default: 2.0)
  final double backoffMultiplier;

  /// Maximum delay between retries (default: 10 seconds)
  final Duration maxDelay;

  /// HTTP status codes that should trigger a retry
  final Set<int> retryableStatusCodes;

  const RetryConfig({
    this.enabled = true,
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 10),
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
  });

  /// Calculate delay for a given retry attempt
  Duration getDelayForAttempt(int attempt) {
    if (attempt <= 0) return Duration.zero;

    final delay = Duration(
      milliseconds:
          (initialDelay.inMilliseconds * (backoffMultiplier * attempt)).round(),
    );

    return delay > maxDelay ? maxDelay : delay;
  }

  @override
  String toString() {
    return 'RetryConfig(enabled: $enabled, maxAttempts: $maxAttempts, '
        'initialDelay: $initialDelay, backoffMultiplier: $backoffMultiplier)';
  }
}
