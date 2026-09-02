import 'package:http/http.dart' as http;

import 'cache/cache_store.dart';
import 'core/cancellation.dart';
import 'core/platform_info.dart';
import 'core/scraper_config.dart';
import 'core/scraper_exceptions.dart';
import 'dom/html_document.dart';
import 'net/fetcher.dart';
import 'net/rate_limiter.dart';
import 'net/robots_policy.dart';
import 'utils/content_formatter.dart';
import 'utils/smart_extractor.dart';

/// What [MobileScraper.queryWithRegex] matches against.
enum RegexTarget {
  /// The page's markup, tags and attributes included.
  ///
  /// Necessary for anything structural, but note that a pattern has no idea
  /// where a tag or attribute ends — `(https://[^\s]+)` against markup happily
  /// captures the closing `</p>` too. Prefer [text] whenever the target is
  /// something a reader can see.
  html,

  /// The page's visible text, with scripts, styles and tags removed.
  ///
  /// The right choice for pulling an address, identifier or reference out of
  /// prose, because there is no markup left to contaminate the match.
  text,
}

/// Fetches a page and extracts content from it.
///
/// ```dart
/// final scraper = MobileScraper(url: 'https://example.com');
/// try {
///   await scraper.load();
///   final headings = scraper.queryAll(tag: 'h1');
///   final links = scraper.select('a[href]');
/// } finally {
///   scraper.dispose();
/// }
/// ```
///
/// Android and iOS only.
///
/// Parsing goes through [HtmlDocument] — a real HTML5 parser — rather than the
/// regular expressions 1.x used. That change is what fixes the nested-tag
/// truncation and the class filter that leaked across the whole document:
/// regex cannot pair a tag with its matching close, nor tell where an
/// attribute ends.
class MobileScraper {
  /// Creates a scraper for [url].
  ///
  /// Throws [UnsupportedPlatformException] off Android and iOS, and
  /// [InvalidUrlException] if [url] is not a usable http(s) address.
  ///
  /// The injectable collaborators exist for testing, and for callers who want
  /// to share one HTTP client, cache or rate limiter across many scrapers.
  MobileScraper({
    required this.url,
    this.config = ScraperConfig.defaultConfig,
    PlatformInfo? platformInfo,
    http.Client? httpClient,
    CacheStore? cacheStore,
    RateLimiter? rateLimiter,
    RobotsPolicy? robotsPolicy,
  })  : _platform = platformInfo ?? PlatformInfo.current,
        _cache = cacheStore ?? sharedCache {
    _platform.requireSupported();
    _validateUrl();
    _fetcher = Fetcher(
      config: config,
      client: httpClient,
      rateLimiter: rateLimiter,
      robotsPolicy: robotsPolicy,
    );
  }

  /// Creates a scraper over HTML you already have.
  ///
  /// No network access and no platform gate — for tests, for saved fixtures,
  /// and for parsing a response fetched by other means.
  factory MobileScraper.fromHtml(
    String html, {
    String? url,
    ScraperConfig config = ScraperConfig.testing,
  }) {
    final scraper = MobileScraper._offline(url ?? 'https://localhost/', config)
      .._document = HtmlDocument.parse(html, url: url);
    return scraper;
  }

  MobileScraper._offline(this.url, this.config)
      : _platform = const FakePlatformInfo.android(),
        _cache = sharedCache {
    _fetcher = Fetcher(config: config);
  }

  /// The URL this scraper targets.
  final String url;

  /// The active configuration.
  final ScraperConfig config;

  final PlatformInfo _platform;
  final CacheStore _cache;
  late final Fetcher _fetcher;

  /// The process-wide cache, used when no other store is supplied.
  static final CacheStore sharedCache = CacheStore();

  HtmlDocument? _document;
  CancellationToken? _cancellationToken;
  bool _disposed = false;

  /// The parsed document, or `null` before [load].
  HtmlDocument? get document => _document;

  /// Whether a page has been loaded.
  bool get isLoaded => _document != null;

  /// The page's HTML, or `null` before [load].
  String? get rawHtml => _document?.raw.outerHtml;

  /// Fetches and parses the page.
  ///
  /// With caching on, a stale entry is revalidated using
  /// `If-None-Match`/`If-Modified-Since`, so an unchanged page costs a `304`
  /// instead of a full transfer.
  ///
  /// Returns `true` on success. Throws [NetworkException],
  /// [HttpStatusException], [ScraperTimeoutException],
  /// [ContentTooLargeException], [RobotsDisallowedException] or
  /// [CancelledException].
  Future<bool> load({
    bool? useCache,
    CancellationToken? cancellationToken,
  }) async {
    if (_disposed) {
      throw StateError('Scraper has been disposed');
    }

    final token = cancellationToken ?? CancellationToken();
    _cancellationToken = token;

    final shouldCache = useCache ?? config.useCache;
    CacheEntry? cached;

    if (shouldCache) {
      cached = await _cache.get(url);
      if (cached != null && cached.isFresh) {
        _document = HtmlDocument.parse(cached.body, url: url);
        return true;
      }
    }

    final canRevalidate = cached?.canRevalidate ?? false;
    final response = await _fetcher.fetch(
      url,
      etag: canRevalidate ? cached?.etag : null,
      lastModified: canRevalidate ? cached?.lastModified : null,
      cancellationToken: token,
    );

    // Unchanged since we last saw it: keep the body, extend its life.
    if (response.notModified && cached != null) {
      await _cache.revalidate(url, ttl: config.cacheTtl);
      _document = HtmlDocument.parse(cached.body, url: url);
      return true;
    }

    _document = HtmlDocument.parse(response.body, url: response.url);

    if (shouldCache) {
      await _cache.put(
        url,
        CacheEntry(
          url: response.url,
          body: response.body,
          cachedAt: DateTime.now(),
          expiresAt: DateTime.now().add(config.cacheTtl),
          etag: response.etag,
          lastModified: response.lastModified,
          contentType: response.contentType,
        ),
      );
    }

    return true;
  }

  /// Cancels an in-flight [load].
  void cancel() => _cancellationToken?.cancel();

  // -------------------------------------------------------------------------
  // Tag queries
  // -------------------------------------------------------------------------

  /// The text of every element matching [tag], optionally filtered.
  ///
  /// [className] matches elements carrying that class among any others; pass
  /// several separated by spaces to require all of them. [id] matches the
  /// element with that id. Elements whose text is empty are omitted.
  ///
  /// Throws [ScraperNotInitializedException] before [load], and
  /// [InvalidParameterException] if [tag] is blank.
  List<String> queryAll({
    required String tag,
    String? className,
    String? id,
  }) {
    final doc = _requireDocument();

    if (tag.trim().isEmpty) {
      throw const InvalidParameterException('tag', '', 'must not be empty');
    }

    final selector = StringBuffer(tag.trim());
    if (id != null && id.trim().isNotEmpty) {
      selector.write('#${id.trim()}');
    }
    if (className != null && className.trim().isNotEmpty) {
      for (final name in className.trim().split(RegExp(r'\s+'))) {
        if (name.isNotEmpty) selector.write('.$name');
      }
    }

    return doc
        .select(selector.toString())
        .map((node) => node.text)
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
  }

  /// The text of the first element matching [tag], or `null`.
  String? query({required String tag, String? className, String? id}) {
    final results = queryAll(tag: tag, className: className, id: id);
    return results.isEmpty ? null : results.first;
  }

  /// Elements matching [cssSelector].
  ///
  /// More capable than [queryAll], and the preferred route. Throws
  /// [InvalidSelectorException] for selectors the parser cannot evaluate —
  /// refused rather than silently returning nothing.
  List<HtmlNode> select(String cssSelector) =>
      _requireDocument().select(cssSelector);

  /// The first element matching [cssSelector], or `null`.
  HtmlNode? selectFirst(String cssSelector) =>
      _requireDocument().selectFirst(cssSelector);

  // -------------------------------------------------------------------------
  // Regex queries
  // -------------------------------------------------------------------------

  /// Text matched by [pattern] against the page's HTML.
  ///
  /// Prefer [select]; regex over HTML is where the 1.x defects came from. This
  /// stays for genuinely non-structural matches — pulling an identifier out of
  /// an inline script, say.
  ///
  /// [group] selects a capture group. Omit it and the whole match (group 0) is
  /// used for a pattern with no capture groups, group 1 otherwise.
  ///
  /// That default is the fix for a trap in 1.x, which always read group 1: a
  /// pattern built entirely from non-capturing `(?:…)` groups threw a
  /// `RangeError`, which a broad `catch` relabelled as "Failed to parse HTML" —
  /// pointing the caller at their markup rather than at the group index.
  ///
  /// [caseSensitive] defaults to `true`, matching Dart's own `RegExp`. 1.x
  /// forced case-*insensitive* matching with no way to opt out, which quietly
  /// broke any pattern relying on case: `-\s*([A-Z][a-z]+\s+[A-Z][a-z]+)`,
  /// written to mean "a Capitalised Full Name", also matched
  /// `-performance laptop`. Pass `caseSensitive: false` for the old behaviour.
  ///
  /// [dotAll] defaults to `true`, so `.` spans newlines — usually what you want
  /// against HTML.
  ///
  /// [target] chooses the haystack. Use [RegexTarget.text] to match against
  /// visible text with the markup stripped, which is what you want for an
  /// address or identifier printed in prose.
  ///
  /// Throws [InvalidParameterException] if [pattern] is not valid regex, or if
  /// [group] is outside the pattern's range.
  List<String> queryWithRegex({
    required String pattern,
    int? group,
    bool caseSensitive = true,
    bool dotAll = true,
    RegexTarget target = RegexTarget.html,
  }) {
    final doc = _requireDocument();

    final RegExp regex;
    try {
      regex = RegExp(pattern, caseSensitive: caseSensitive, dotAll: dotAll);
    } on FormatException catch (error) {
      throw InvalidParameterException(
        'pattern',
        pattern,
        'not a valid regular expression: ${error.message}',
        url: url,
        cause: error,
      );
    }

    final haystack = switch (target) {
      RegexTarget.html => doc.raw.outerHtml,
      RegexTarget.text => ContentFormatter.toPlainText(doc),
    };
    final matches = regex.allMatches(haystack).toList(growable: false);
    if (matches.isEmpty) return const [];

    final groupCount = matches.first.groupCount;
    final effectiveGroup = group ?? (groupCount >= 1 ? 1 : 0);

    if (effectiveGroup < 0 || effectiveGroup > groupCount) {
      throw InvalidParameterException(
        'group',
        effectiveGroup,
        groupCount == 0
            ? 'the pattern has no capture groups, so only group 0 (the whole '
                'match) is available. Omit `group`, or add a capturing "(...)" '
                'group — "(?:...)" does not capture.'
            : 'the pattern has $groupCount capture group'
                '${groupCount == 1 ? '' : 's'}, so valid values are 0 to '
                '$groupCount.',
        url: url,
      );
    }

    return matches
        .map((match) => match.group(effectiveGroup)?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  /// The first match for [pattern], or `null`.
  String? queryWithRegexFirst({
    required String pattern,
    int? group,
    bool caseSensitive = true,
    bool dotAll = true,
    RegexTarget target = RegexTarget.html,
  }) {
    final results = queryWithRegex(
      pattern: pattern,
      group: group,
      caseSensitive: caseSensitive,
      dotAll: dotAll,
      target: target,
    );
    return results.isEmpty ? null : results.first;
  }

  // -------------------------------------------------------------------------
  // Smart extraction
  // -------------------------------------------------------------------------

  /// Every field [SmartExtractor] can find on the page.
  SmartContent extractSmartContent() =>
      SmartExtractor.extractAll(_requireDocument());

  /// The page title, from OpenGraph, `<title>` or the first `<h1>`.
  String? extractTitle() => SmartExtractor.extractTitle(_requireDocument());

  /// The page summary, from OpenGraph, meta tags or the first real paragraph.
  String? extractDescription() =>
      SmartExtractor.extractDescription(_requireDocument());

  /// Absolute image URLs found on the page.
  List<String> extractImages() =>
      SmartExtractor.extractImages(_requireDocument());

  /// Absolute link URLs found on the page.
  List<String> extractLinks() => SmartExtractor.extractLinks(_requireDocument());

  /// Email addresses, taken from `mailto:` links only.
  List<String> extractEmails() =>
      SmartExtractor.extractEmails(_requireDocument());

  /// Headings in document order.
  List<Heading> extractHeadings() =>
      SmartExtractor.extractHeadings(_requireDocument());

  /// OpenGraph metadata, or `null` when the page carries none.
  OpenGraphData? extractOpenGraph() =>
      SmartExtractor.extractOpenGraph(_requireDocument());

  // -------------------------------------------------------------------------
  // Formatting
  // -------------------------------------------------------------------------

  /// The page as readable text, with block structure kept as newlines.
  String toPlainText() => ContentFormatter.toPlainText(_requireDocument());

  /// The page as Markdown, preserving headings, lists, links and tables.
  String toMarkdown() => ContentFormatter.toMarkdown(_requireDocument());

  /// The main article body, with navigation, headers and footers removed.
  String getReadableContent() =>
      ContentFormatter.toReadableContent(_requireDocument());

  /// The page rendered as [format].
  String formatContent(ContentFormat format) =>
      ContentFormatter.format(_requireDocument(), format);

  /// Every table on the page, as structured rows.
  List<ExtractedTable> extractTables() =>
      ContentFormatter.extractTables(_requireDocument());

  /// Headings, links, images, lists, quotes and tables, grouped by kind.
  Map<String, List<String>> extractSpecificContent() =>
      ContentFormatter.extractSpecificContent(_requireDocument());

  /// Words in the page's readable text.
  int getWordCount() => ContentFormatter.wordCount(toPlainText());

  /// How long the page would take to read.
  Duration estimateReadingTime({int wordsPerMinute = 200}) =>
      ContentFormatter.estimateReadingTime(
        toPlainText(),
        wordsPerMinute: wordsPerMinute,
      );

  // -------------------------------------------------------------------------
  // Cache
  // -------------------------------------------------------------------------

  /// Whether a fresh cache entry exists for this URL.
  Future<bool> isCached() => _cache.contains(url);

  /// Drops this URL from the cache.
  Future<void> removeFromCache() => _cache.remove(url);

  /// Empties the shared cache.
  static Future<void> clearAllCache() => sharedCache.clear();

  /// Statistics for the shared cache.
  static CacheStats getCacheStats() => sharedCache.stats();

  HtmlDocument _requireDocument() {
    final doc = _document;
    if (doc == null) throw ScraperNotInitializedException(url: url);
    return doc;
  }

  void _validateUrl() {
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException catch (error) {
      throw InvalidUrlException(url, 'could not be parsed', cause: error);
    }

    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw InvalidUrlException(url, 'must start with http:// or https://');
    }
    if (uri.host.isEmpty) {
      throw InvalidUrlException(url, 'missing a host');
    }
  }

  /// Releases held resources. Safe to call more than once.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancellationToken?.cancel();
    _fetcher.dispose();
    _document = null;
  }
}
