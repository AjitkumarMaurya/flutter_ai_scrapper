/// Every error this package throws.
///
/// [ScraperException] is `sealed`, so a `switch` over it is exhaustive and a
/// new failure mode added here becomes a compile error at each call site
/// rather than a surprise at runtime.
library;

/// Base type for every error raised by flutter_ai_scrapper.
///
/// Carries enough context to diagnose the failure ([url], [cause],
/// [stackTrace]) and a separate [userMessage] safe to put in front of a person.
/// The two are deliberately different: `toString()` is for logs and bug
/// reports, [userMessage] is for a UI.
sealed class ScraperException implements Exception {
  /// Creates a scraper exception.
  const ScraperException(
    this.message, {
    this.url,
    this.cause,
    this.stackTrace,
  });

  /// Developer-facing description of what went wrong.
  final String message;

  /// The URL being processed when this was thrown, when there was one.
  final String? url;

  /// The underlying error, if this exception wraps one.
  final Object? cause;

  /// Stack trace captured at the original failure, when available.
  final StackTrace? stackTrace;

  /// A short, non-technical explanation suitable for display to a person.
  ///
  /// Never contains stack traces, type names, or credentials.
  String get userMessage;

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (url != null) buffer.write(' [url: $url]');
    if (cause != null) buffer.write(' (cause: $cause)');
    return buffer.toString();
  }
}

// ---------------------------------------------------------------------------
// Configuration and usage errors
// ---------------------------------------------------------------------------

/// Thrown when the scraper is used on a platform it does not support.
///
/// This package is Android and iOS only. Web cannot fetch third-party pages at
/// all because of CORS; desktop is simply out of scope for 2.0.
final class UnsupportedPlatformException extends ScraperException {
  /// Creates an unsupported-platform error for [platform].
  UnsupportedPlatformException(this.platform)
      : super(
          'flutter_ai_scrapper supports Android and iOS only. '
          'Current platform: $platform',
        );

  /// The operating system that was detected.
  final String platform;

  @override
  String get userMessage =>
      'Web scraping is not available on this device platform.';
}

/// Thrown when a URL cannot be used for scraping.
final class InvalidUrlException extends ScraperException {
  /// Creates an invalid-URL error.
  const InvalidUrlException(String url, String reason, {super.cause})
      : super('Invalid URL: $reason', url: url);

  @override
  String get userMessage => 'That web address does not look valid.';
}

/// Thrown when an argument is outside its accepted range or shape.
final class InvalidParameterException extends ScraperException {
  /// Creates an invalid-parameter error.
  const InvalidParameterException(
    this.parameterName,
    this.value,
    String reason, {
    super.url,
    super.cause,
  }) : super('Invalid $parameterName ($value): $reason');

  /// Name of the offending parameter.
  final String parameterName;

  /// The value that was rejected.
  final Object? value;

  @override
  String get userMessage => 'One of the extraction settings is not valid.';
}

/// Thrown when a CSS selector uses a feature the parser cannot evaluate.
///
/// `package:html` implements a subset of CSS. Structural pseudo-classes are
/// either unimplemented or — worse — silently return no matches, so this
/// package rejects them up front instead of handing back a confidently empty
/// result. See [unsupportedSelectorHelp] for the supported subset.
final class InvalidSelectorException extends ScraperException {
  /// Creates an invalid-selector error.
  const InvalidSelectorException(this.selector, String reason, {super.cause})
      : super('Unsupported CSS selector "$selector": $reason');

  /// The selector that was rejected.
  final String selector;

  /// Human-readable summary of what selectors this package can evaluate.
  static const String unsupportedSelectorHelp =
      'Supported: tag, .class, #id, [attr], [attr=value], [attr^=value], '
      'descendant (a b), child (a > b) and comma groups. '
      'Structural pseudo-classes (:nth-child, :first-child, :has, :not) are '
      'not supported by the underlying parser — filter the results in Dart '
      'instead.';

  @override
  String get userMessage => 'That element selector is not supported.';
}

/// Thrown when a query runs before `load()` has completed.
final class ScraperNotInitializedException extends ScraperException {
  /// Creates a not-initialized error.
  const ScraperNotInitializedException({super.url})
      : super('Scraper not initialized — call load() before querying.');

  @override
  String get userMessage => 'The page has not been loaded yet.';
}

// ---------------------------------------------------------------------------
// Network errors
// ---------------------------------------------------------------------------

/// Thrown when a request fails for a transport-level reason.
///
/// For a response that arrived but carried an error status, see
/// [HttpStatusException].
final class NetworkException extends ScraperException {
  /// Creates a network error.
  const NetworkException(
    String url,
    super.message, {
    super.cause,
    super.stackTrace,
  }) : super(url: url);

  @override
  String get userMessage =>
      'Could not reach that site. Check your connection and try again.';
}

/// Thrown when the server responded with a 4xx or 5xx status.
final class HttpStatusException extends ScraperException {
  /// Creates an HTTP status error.
  const HttpStatusException(
    String url,
    this.statusCode, {
    this.reasonPhrase,
    super.cause,
  }) : super('HTTP $statusCode', url: url);

  /// The status code returned by the server.
  final int statusCode;

  /// The server's reason phrase, when it sent one.
  final String? reasonPhrase;

  /// Whether retrying this request could plausibly succeed.
  bool get isRetryable => const {408, 425, 429, 500, 502, 503, 504}
      .contains(statusCode);

  /// Whether the failure is the caller's (4xx) rather than the server's.
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  @override
  String get userMessage => switch (statusCode) {
        401 || 403 => 'That page requires permission to view.',
        404 => 'That page could not be found.',
        429 => 'That site is rate-limiting us. Try again shortly.',
        >= 500 => 'That site is having problems right now.',
        _ => 'That site returned an error.',
      };
}

/// Thrown when an operation exceeds its allotted time.
///
/// Named to avoid colliding with `dart:async`'s `TimeoutException`. In 1.x this
/// type was called `TimeoutException` and shadowed the SDK's inside the same
/// library, so the `on TimeoutException` clause never caught what `.timeout()`
/// actually throws and every timeout was mislabelled as an unexpected network
/// error.
final class ScraperTimeoutException extends ScraperException {
  /// Creates a timeout error.
  const ScraperTimeoutException(this.timeout, {super.url, super.cause})
      : super('Operation timed out');

  /// How long was allowed before giving up.
  final Duration timeout;

  @override
  String toString() =>
      'ScraperTimeoutException: timed out after ${timeout.inMilliseconds}ms'
      '${url != null ? ' [url: $url]' : ''}';

  @override
  String get userMessage => 'That site took too long to respond.';
}

/// Thrown when a response exceeds the configured size limit.
///
/// Raised *during* the download, so an oversized body is abandoned rather than
/// buffered into memory first.
final class ContentTooLargeException extends ScraperException {
  /// Creates a content-too-large error.
  const ContentTooLargeException(this.size, this.maxSize, {super.url})
      : super('Content is $size bytes, over the $maxSize byte limit');

  /// Bytes received before the limit was hit, or the declared length.
  final int size;

  /// The configured ceiling.
  final int maxSize;

  @override
  String get userMessage => 'That page is too large to process.';
}

/// Thrown when a site's `robots.txt` disallows the requested path.
final class RobotsDisallowedException extends ScraperException {
  /// Creates a robots-disallowed error.
  const RobotsDisallowedException(String url, this.userAgent)
      : super('robots.txt disallows this path', url: url);

  /// The user agent the rule was matched against.
  final String userAgent;

  @override
  String get userMessage => 'That site asks not to be scraped.';
}

/// Thrown when an operation was cancelled by the caller.
final class CancelledException extends ScraperException {
  /// Creates a cancellation error.
  const CancelledException({super.url}) : super('Operation cancelled');

  @override
  String get userMessage => 'The request was cancelled.';
}

// ---------------------------------------------------------------------------
// Parsing errors
// ---------------------------------------------------------------------------

/// Thrown when content cannot be parsed.
///
/// `package:html` recovers from almost any malformed markup, so this is rare in
/// practice and usually signals that the response was not HTML at all.
final class ParseException extends ScraperException {
  /// Creates a parse error.
  const ParseException(
    super.message, {
    super.url,
    super.cause,
    super.stackTrace,
    this.snippet,
  });

  /// A short excerpt of the offending content, for diagnosis.
  final String? snippet;

  @override
  String get userMessage => 'That page could not be read.';
}
