class ScrapeResult {
  final String url;
  final String title;
  final String cleanText;
  final String markdown;
  final List<String> links;
  final Map<String, List<String>> selectorMatches;
  final Map<String, dynamic> structuredData;
  final Map<String, dynamic>? aiExtractedData;
  final bool fromCache;
  final Duration elapsed;

  const ScrapeResult({
    required this.url,
    required this.title,
    required this.cleanText,
    required this.markdown,
    required this.links,
    required this.selectorMatches,
    required this.structuredData,
    this.aiExtractedData,
    required this.fromCache,
    required this.elapsed,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'cleanText': cleanText,
        'markdown': markdown,
        'links': links,
        'selectorMatches': selectorMatches,
        'structuredData': structuredData,
        if (aiExtractedData != null) 'aiExtractedData': aiExtractedData,
        'fromCache': fromCache,
        'elapsedMs': elapsed.inMilliseconds,
      };
}
