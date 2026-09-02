import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config/scraper_config.dart';
import 'exceptions/scraper_exceptions.dart';
import 'utils/smart_extractor.dart';
import 'utils/cache_manager.dart';
import 'utils/content_formatter.dart';

/// A lightweight HTML scraper designed specifically for Flutter mobile apps.
/// Works only on Android and iOS platforms.
///
/// Example usage:
/// ```dart
/// final scraper = MobileScraper(
///   url: 'https://example.com',
///   config: ScraperConfig(timeout: Duration(seconds: 10)),
/// );
///
/// await scraper.load();
/// final results = scraper.queryAll(tag: 'h1');
/// ```
class MobileScraper {
  /// The URL to scrape
  final String url;

  /// Configuration options for the scraper
  final ScraperConfig config;

  /// Raw HTML content
  String? _htmlContent;

  /// HTTP client for making requests
  late final http.Client _client;

  /// Completer for cancellation support
  Completer<void>? _loadCompleter;

  /// Cache manager instance
  static final CacheManager _cacheManager = CacheManager.instance;

  /// Creates a new MobileScraper instance with the given URL and optional configuration.
  ///
  /// Throws [UnsupportedPlatformException] if the current platform is not Android or iOS.
  /// Throws [InvalidParameterException] if the URL is invalid.
  MobileScraper({
    required this.url,
    this.config = ScraperConfig.defaultConfig,
  }) {
    _validatePlatform();
    _validateUrl();
    _client = http.Client();
    _initializeCache();
  }

  /// Initialize cache if not already done
  void _initializeCache() {
    _cacheManager.initialize();
  }

  /// Validates that the current platform is supported (Android or iOS only).
  /// Skips validation in test environment.
  void _validatePlatform() {
    // Skip platform validation during testing
    if (_isInTestEnvironment()) return;

    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedPlatformException(Platform.operatingSystem);
    }
  }

  /// Validates the URL format
  void _validateUrl() {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        throw InvalidParameterException(
            'url', url, 'URL must start with http:// or https://');
      }
    } catch (e) {
      throw InvalidParameterException('url', url, 'Invalid URL format: $e');
    }
  }

  /// Checks if we're running in a test environment
  bool _isInTestEnvironment() {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST') ||
          Platform.environment.containsKey('UNIT_TEST');
    } catch (e) {
      return false;
    }
  }

  /// Loads HTML content from the specified URL with retry support and caching.
  ///
  /// Returns `true` if successful, throws appropriate exceptions on failure.
  ///
  /// Throws:
  /// - [NetworkException] for network-related errors
  /// - [TimeoutException] for timeout errors
  /// - [ContentTooLargeException] if content exceeds size limit
  Future<bool> load({bool useCache = true}) async {
    _loadCompleter = Completer<void>();

    try {
      // Check cache first if enabled
      if (useCache) {
        final cachedContent = await _cacheManager.get(url);
        if (cachedContent != null) {
          _htmlContent = cachedContent;
          _loadCompleter?.complete();
          return true;
        }
      }

      // Load from network
      final response = await _loadWithRetry();

      // Check content size
      final contentLength = response.contentLength ?? response.bodyBytes.length;
      if (contentLength > config.maxContentSize) {
        throw ContentTooLargeException(contentLength, config.maxContentSize);
      }

      // Handle different encodings
      _htmlContent = _decodeResponse(response);

      // Cache the content if enabled
      if (useCache && _htmlContent != null) {
        await _cacheManager.set(url, _htmlContent!);
      }

      _loadCompleter?.complete();
      return true;
    } catch (e) {
      _loadCompleter?.completeError(e);
      rethrow;
    }
  }

  /// Loads content with retry logic
  Future<http.Response> _loadWithRetry() async {
    if (!config.retryConfig.enabled) {
      return _makeRequest();
    }

    Exception? lastException;

    for (int attempt = 0; attempt < config.retryConfig.maxAttempts; attempt++) {
      try {
        return await _makeRequest();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        // Don't retry on final attempt
        if (attempt == config.retryConfig.maxAttempts - 1) {
          break;
        }

        // Check if we should retry based on error type
        if (!_shouldRetry(e)) {
          break;
        }

        // Wait before retrying
        final delay = config.retryConfig.getDelayForAttempt(attempt + 1);
        await Future.delayed(delay);
      }
    }

    throw lastException!;
  }

  /// Makes the actual HTTP request
  Future<http.Response> _makeRequest() async {
    final uri = Uri.parse(url);
    final headers = Map<String, String>.from(config.headers);
    headers['User-Agent'] = config.userAgent;
    headers['Accept'] =
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';

    try {
      final response =
          await _client.get(uri, headers: headers).timeout(config.timeout);

      if (response.statusCode >= 400) {
        throw NetworkException(
          url,
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          response.statusCode,
        );
      }

      return response;
    } on TimeoutException {
      throw TimeoutException(config.timeout);
    } on SocketException catch (e) {
      throw NetworkException(url, 'Network error: ${e.message}', null, e);
    } on HttpException catch (e) {
      throw NetworkException(url, 'HTTP error: ${e.message}', null, e);
    } catch (e) {
      throw NetworkException(url, 'Unexpected error: $e', null, e);
    }
  }

  /// Determines if an error should trigger a retry
  bool _shouldRetry(dynamic error) {
    if (error is NetworkException && error.statusCode != null) {
      return config.retryConfig.retryableStatusCodes.contains(error.statusCode);
    }
    if (error is TimeoutException || error is SocketException) {
      return true;
    }
    return false;
  }

  /// Decodes the HTTP response with proper encoding handling
  String _decodeResponse(http.Response response) {
    // Try to detect encoding from headers
    String? charset;
    final contentType = response.headers['content-type'];
    if (contentType != null) {
      final charsetMatch = RegExp(r'charset=([^;]+)').firstMatch(contentType);
      charset = charsetMatch?.group(1)?.toLowerCase();
    }

    // Default to UTF-8 if not specified
    charset ??= 'utf-8';

    try {
      switch (charset) {
        case 'utf-8':
        case 'utf8':
          return utf8.decode(response.bodyBytes);
        case 'latin-1':
        case 'iso-8859-1':
          return latin1.decode(response.bodyBytes);
        default:
          // Fallback to UTF-8
          return utf8.decode(response.bodyBytes, allowMalformed: true);
      }
    } catch (e) {
      // Final fallback
      return String.fromCharCodes(response.bodyBytes);
    }
  }

  /// Cancels any ongoing load operation
  void cancel() {
    if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
      _loadCompleter!.completeError(Exception('Operation cancelled'));
    }
  }

  // ========== SMART CONTENT EXTRACTION ==========

  /// Extract all common content types automatically using smart extraction
  ///
  /// This method automatically detects and extracts:
  /// - Page title
  /// - Meta description
  /// - Main content
  /// - Author information
  /// - Publication date
  /// - Images, links, emails, phone numbers, prices
  /// - Open Graph metadata
  ///
  /// Example:
  /// ```dart
  /// final content = scraper.extractSmartContent();
  /// print('Title: ${content.title}');
  /// print('Description: ${content.description}');
  /// print('Images found: ${content.images.length}');
  /// ```
  SmartContent extractSmartContent() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return SmartExtractor.extractAll(_htmlContent!);
  }

  /// Extract only the page title using smart detection
  String? extractTitle() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return SmartExtractor.extractTitle(_htmlContent!);
  }

  /// Extract only the description using smart detection
  String? extractDescription() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return SmartExtractor.extractDescription(_htmlContent!);
  }

  /// Extract all images found on the page
  List<String> extractImages() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return SmartExtractor.extractImages(_htmlContent!);
  }

  /// Extract all links found on the page
  List<String> extractLinks() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return SmartExtractor.extractLinks(_htmlContent!);
  }

  /// Extract email addresses found on the page
  List<String> extractEmails() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return SmartExtractor.extractEmails(_htmlContent!);
  }

  /// Extract phone numbers found on the page
  List<String> extractPhoneNumbers() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return SmartExtractor.extractPhoneNumbers(_htmlContent!);
  }

  /// Extract prices found on the page (useful for e-commerce)
  List<String> extractPrices() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return SmartExtractor.extractPrices(_htmlContent!);
  }

  // ========== CONTENT FORMATTING ==========

  /// Convert the entire page content to clean plain text
  String toPlainText() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return ContentFormatter.toPlainText(_htmlContent!);
  }

  /// Convert the entire page content to Markdown format
  String toMarkdown() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return ContentFormatter.toMarkdown(_htmlContent!);
  }

  /// Get readable content similar to Readability.js
  /// This removes ads, navigation, and other clutter
  String getReadableContent() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return ContentFormatter.toReadableContent(_htmlContent!);
  }

  /// Format content according to specified format
  String formatContent(ContentFormat format) {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return ContentFormatter.format(_htmlContent!, format);
  }

  /// Get content with specific formatting for extracted elements
  String getCleanContent({
    required String tag,
    String? className,
    String? id,
    ContentFormat format = ContentFormat.plainText,
  }) {
    final results = queryAll(tag: tag, className: className, id: id);
    if (results.isEmpty) return '';

    final combinedHtml = results.map((r) => '<p>$r</p>').join('\n');
    return ContentFormatter.format(combinedHtml, format);
  }

  /// Get word count of the page content
  int getWordCount() {
    final plainText = toPlainText();
    return ContentFormatter.wordCount(plainText);
  }

  /// Estimate reading time for the page content
  Duration estimateReadingTime({int wordsPerMinute = 200}) {
    final plainText = toPlainText();
    return ContentFormatter.estimateReadingTime(plainText,
        wordsPerMinute: wordsPerMinute);
  }

  /// Extract specific content types (headings, links, images, etc.)
  Map<String, List<String>> extractSpecificContent() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    return ContentFormatter.extractSpecificContent(_htmlContent!);
  }

  // ========== CACHE MANAGEMENT ==========

  /// Check if this URL is cached
  Future<bool> isCached() async {
    return await _cacheManager.contains(url);
  }

  /// Remove this URL from cache
  Future<void> removeFromCache() async {
    await _cacheManager.remove(url);
  }

  /// Clear all cached content
  static Future<void> clearAllCache() async {
    await _cacheManager.clear();
  }

  /// Get cache statistics
  static CacheStats getCacheStats() {
    return _cacheManager.getStats();
  }

  // ========== ORIGINAL METHODS ==========

  /// Extracts all text content from HTML tags matching the specified criteria.
  ///
  /// [tag] - The HTML tag to search for (e.g., 'h1', 'p', 'div')
  /// [className] - Optional CSS class name to filter by
  /// [id] - Optional ID attribute to filter by
  ///
  /// Returns a list of text content from matching elements.
  ///
  /// Throws [ScraperNotInitializedException] if HTML content not loaded.
  /// Throws [ParseException] if parsing fails.
  List<String> queryAll({
    required String tag,
    String? className,
    String? id,
  }) {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    try {
      List<String> results = [];
      String pattern = _buildTagPattern(tag, className: className, id: id);

      RegExp regex = RegExp(pattern, caseSensitive: false, dotAll: true);
      Iterable<RegExpMatch> matches = regex.allMatches(_htmlContent!);

      for (RegExpMatch match in matches) {
        String? content = match.group(1);
        if (content != null) {
          // Remove HTML tags from content and clean up whitespace
          String cleanContent = _cleanHtmlContent(content);
          if (cleanContent.isNotEmpty) {
            results.add(cleanContent);
          }
        }
      }

      return results;
    } catch (e) {
      throw ParseException(
          'Failed to parse HTML with tag pattern', _htmlContent, e);
    }
  }

  /// Extracts the first text content from HTML tags matching the specified criteria.
  ///
  /// Returns the first matching text content, or null if no matches found.
  String? query({
    required String tag,
    String? className,
    String? id,
  }) {
    List<String> results = queryAll(tag: tag, className: className, id: id);
    return results.isNotEmpty ? results.first : null;
  }

  /// Extracts text content using a regular expression pattern.
  ///
  /// [pattern] - The regex pattern to match against
  /// [group] - The capture group to extract (defaults to 1)
  ///
  /// Returns a list of matching text content.
  ///
  /// Throws [ScraperNotInitializedException] if HTML content not loaded.
  /// Throws [ParseException] if regex compilation fails.
  List<String> queryWithRegex({
    required String pattern,
    int group = 1,
  }) {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }

    try {
      List<String> results = [];
      RegExp regex = RegExp(pattern, caseSensitive: false, dotAll: true);
      Iterable<RegExpMatch> matches = regex.allMatches(_htmlContent!);

      for (RegExpMatch match in matches) {
        String? content = match.group(group);
        if (content != null) {
          String cleanContent = content.trim();
          if (cleanContent.isNotEmpty) {
            results.add(cleanContent);
          }
        }
      }

      return results;
    } catch (e) {
      throw ParseException(
          'Failed to parse HTML with regex pattern: $pattern', _htmlContent, e);
    }
  }

  /// Extracts the first match using a regular expression pattern.
  ///
  /// Returns the first matching text content, or null if no matches found.
  String? queryWithRegexFirst({
    required String pattern,
    int group = 1,
  }) {
    List<String> results = queryWithRegex(pattern: pattern, group: group);
    return results.isNotEmpty ? results.first : null;
  }

  /// Returns the raw HTML content.
  ///
  /// Returns null if HTML content hasn't been loaded yet.
  String? get rawHtml => _htmlContent;

  /// Checks if HTML content has been loaded.
  bool get isLoaded => _htmlContent != null;

  /// Builds a regex pattern for matching HTML tags with optional attributes.
  String _buildTagPattern(String tag, {String? className, String? id}) {
    String attributePattern = '';

    if (className != null) {
      attributePattern +=
          '(?=.*class=["\'](?:[^"\']*\\s)?${RegExp.escape(className)}(?:\\s[^"\']*)?["\'])';
    }

    if (id != null) {
      attributePattern += '(?=.*id=["\']${RegExp.escape(id)}["\'])';
    }

    return '<${RegExp.escape(tag)}$attributePattern[^>]*>(.*?)<\\/${RegExp.escape(tag)}>';
  }

  /// Removes HTML tags and cleans up whitespace from content.
  String _cleanHtmlContent(String content) {
    // Remove HTML tags
    String cleaned = content.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode common HTML entities
    cleaned = cleaned
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™');

    // Clean up whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  /// Disposes of resources used by the scraper
  void dispose() {
    cancel();
    _client.close();
    _htmlContent = null;
  }
}
