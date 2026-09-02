/// Custom exceptions for the flutter_scrapper package
library;

/// Base exception class for all scraper-related errors
abstract class ScraperException implements Exception {
  /// The error message
  final String message;

  /// Optional underlying cause
  final dynamic cause;

  const ScraperException(this.message, [this.cause]);

  @override
  String toString() =>
      'ScraperException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Exception thrown when trying to use the scraper on an unsupported platform
class UnsupportedPlatformException extends ScraperException {
  /// The current platform that is not supported
  final String platform;

  UnsupportedPlatformException(this.platform)
      : super(
            'flutter_scrapper only supports Android and iOS platforms. Current platform: $platform');
}

/// Exception thrown when there's a network-related error
class NetworkException extends ScraperException {
  /// HTTP status code if available
  final int? statusCode;

  /// The URL that failed to load
  final String url;

  const NetworkException(this.url, super.message,
      [this.statusCode, super.cause]);

  @override
  String toString() =>
      'NetworkException: Failed to load $url${statusCode != null ? ' (Status: $statusCode)' : ''} - $message';
}

/// Exception thrown when parsing fails
class ParseException extends ScraperException {
  /// The content that failed to parse
  final String? content;

  const ParseException(super.message, [this.content, super.cause]);

  @override
  String toString() => 'ParseException: $message';
}

/// Exception thrown when invalid parameters are provided
class InvalidParameterException extends ScraperException {
  /// The parameter name that is invalid
  final String parameterName;

  /// The invalid value
  final dynamic value;

  const InvalidParameterException(
      this.parameterName, this.value, super.message);

  @override
  String toString() =>
      'InvalidParameterException: Invalid $parameterName: $value - $message';
}

/// Exception thrown when the scraper is not properly initialized
class ScraperNotInitializedException extends ScraperException {
  ScraperNotInitializedException()
      : super(
            'Scraper not initialized. Call load() first before performing operations.');
}

/// Exception thrown when a timeout occurs
class TimeoutException extends ScraperException {
  /// The timeout duration
  final Duration timeout;

  TimeoutException(this.timeout)
      : super('Operation timed out after ${timeout.inMilliseconds}ms');
}

/// Exception thrown when content is too large
class ContentTooLargeException extends ScraperException {
  /// The content size in bytes
  final int size;

  /// The maximum allowed size
  final int maxSize;

  ContentTooLargeException(this.size, this.maxSize)
      : super(
            'Content size ($size bytes) exceeds maximum allowed size ($maxSize bytes)');
}
