/// Data model representing the result of a web scraping operation
class ScrapeResult {
  final List<String> data;
  final String url;
  final DateTime timestamp;
  final ScrapeType type;
  final String? error;
  final bool isSuccess;

  ScrapeResult({
    required this.data,
    required this.url,
    required this.timestamp,
    required this.type,
    this.error,
    required this.isSuccess,
  });

  factory ScrapeResult.success({
    required List<String> data,
    required String url,
    required ScrapeType type,
  }) {
    return ScrapeResult(
      data: data,
      url: url,
      timestamp: DateTime.now(),
      type: type,
      isSuccess: true,
    );
  }

  factory ScrapeResult.failure({
    required String url,
    required String error,
    required ScrapeType type,
  }) {
    return ScrapeResult(
      data: [],
      url: url,
      timestamp: DateTime.now(),
      type: type,
      error: error,
      isSuccess: false,
    );
  }

  @override
  String toString() {
    return 'ScrapeResult(isSuccess: $isSuccess, dataCount: ${data.length}, error: $error)';
  }
}

/// Enum representing different types of scraping operations
enum ScrapeType {
  tagBased,
  regexBased,
}

extension ScrapeTypeExtension on ScrapeType {
  String get displayName {
    switch (this) {
      case ScrapeType.tagBased:
        return 'Tag-based';
      case ScrapeType.regexBased:
        return 'Regex-based';
    }
  }
}
