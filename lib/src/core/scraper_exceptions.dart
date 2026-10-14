sealed class ScraperException implements Exception {
  final String message;
  final Object? cause;

  const ScraperException(this.message, [this.cause]);

  @override
  String toString() =>
      '$runtimeType:$message${cause != null ? ' ($cause)' : ''}';
}

class NetworkScraperException extends ScraperException {
  final int? statusCode;
  const NetworkScraperException(super.message, {this.statusCode, Object? cause})
      : super(cause);
}

class ParseScraperException extends ScraperException {
  const ParseScraperException(super.message, [super.cause]);
}

class AiExtractionException extends ScraperException {
  const AiExtractionException(super.message, [super.cause]);
}

class RateLimitExceededException extends ScraperException {
  final Duration? retryAfter;
  const RateLimitExceededException(super.message, {this.retryAfter});
}
