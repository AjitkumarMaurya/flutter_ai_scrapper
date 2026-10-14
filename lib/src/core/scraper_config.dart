class ScraperConfig {
  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;
  final String userAgent;
  final bool enableCache;
  final Duration cacheTtl;
  final int maxTokensPerChunk;
  final bool stripBoilerplate;

  const ScraperConfig({
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 800),
    this.userAgent =
        'Mozilla/5.0 (compatible; FlutterAiScrapper/2.0; +https://pub.dev/packages/flutter_ai_scrapper)',
    this.enableCache = true,
    this.cacheTtl = const Duration(minutes: 30),
    this.maxTokensPerChunk = 3000,
    this.stripBoilerplate = true,
  });

  ScraperConfig copyWith({
    Duration? timeout,
    int? maxRetries,
    Duration? retryDelay,
    String? userAgent,
    bool? enableCache,
    Duration? cacheTtl,
    int? maxTokensPerChunk,
    bool? stripBoilerplate,
  }) {
    return ScraperConfig(
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      userAgent: userAgent ?? this.userAgent,
      enableCache: enableCache ?? this.enableCache,
      cacheTtl: cacheTtl ?? this.cacheTtl,
      maxTokensPerChunk: maxTokensPerChunk ?? this.maxTokensPerChunk,
      stripBoilerplate: stripBoilerplate ?? this.stripBoilerplate,
    );
  }
}
