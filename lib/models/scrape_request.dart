/// Data model representing a web scraping request
class ScrapeRequest {
  final String url;
  final ScrapeRequestType type;
  final TagBasedRequest? tagRequest;
  final RegexBasedRequest? regexRequest;

  ScrapeRequest.tagBased({
    required this.url,
    required String tag,
    String? className,
    String? id,
  })  : type = ScrapeRequestType.tagBased,
        tagRequest = TagBasedRequest(
          tag: tag,
          className: className,
          id: id,
        ),
        regexRequest = null;

  ScrapeRequest.regexBased({
    required this.url,
    required String pattern,
    int group = 1,
  })  : type = ScrapeRequestType.regexBased,
        regexRequest = RegexBasedRequest(
          pattern: pattern,
          group: group,
        ),
        tagRequest = null;

  @override
  String toString() {
    return 'ScrapeRequest(url: $url, type: $type)';
  }
}

/// Enum for scrape request types
enum ScrapeRequestType {
  tagBased,
  regexBased,
}

/// Data model for tag-based scraping parameters
class TagBasedRequest {
  final String tag;
  final String? className;
  final String? id;

  TagBasedRequest({
    required this.tag,
    this.className,
    this.id,
  });

  @override
  String toString() {
    return 'TagBasedRequest(tag: $tag, className: $className, id: $id)';
  }
}

/// Data model for regex-based scraping parameters
class RegexBasedRequest {
  final String pattern;
  final int group;

  RegexBasedRequest({
    required this.pattern,
    this.group = 1,
  });

  @override
  String toString() {
    return 'RegexBasedRequest(pattern: $pattern, group: $group)';
  }
}
