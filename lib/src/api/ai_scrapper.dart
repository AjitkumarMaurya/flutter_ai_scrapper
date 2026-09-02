/// Entrypoint for Tier-1 scraping and extraction with AiScrapper.
library;

import 'package:http/http.dart' as http;

import '../cache/cache_store.dart';
import '../core/cancellation.dart';
import '../core/platform_info.dart';
import '../core/scraper_config.dart';
import '../core/scraper_exceptions.dart';
import '../dom/html_document.dart';
import '../mobile_scraper.dart';
import '../net/rate_limiter.dart';
import '../net/robots_policy.dart';
import 'scraped_page.dart';

/// The primary entry point for web scraping and content extraction.
abstract final class AiScrapper {
  /// Opens [url], loads and parses the content, and returns a [ScrapedPage].
  ///
  /// Throws [UnsupportedPlatformException] off Android and iOS, or network/HTTP
  /// exceptions on connection failures.
  static Future<ScrapedPage> open(
    String url, {
    ScraperConfig config = ScraperConfig.defaultConfig,
    PlatformInfo? platformInfo,
    http.Client? httpClient,
    CacheStore? cacheStore,
    RateLimiter? rateLimiter,
    RobotsPolicy? robotsPolicy,
    CancellationToken? cancellationToken,
  }) async {
    final scraper = MobileScraper(
      url: url,
      config: config,
      platformInfo: platformInfo,
      httpClient: httpClient,
      cacheStore: cacheStore,
      rateLimiter: rateLimiter,
      robotsPolicy: robotsPolicy,
    );

    try {
      await scraper.load(cancellationToken: cancellationToken);
      return ScrapedPage(
        url: scraper.url,
        document: scraper.document!,
        statusCode: 200,
      );
    } finally {
      scraper.dispose();
    }
  }

  /// Creates a [ScrapedPage] from existing [html] content offline.
  ///
  /// Useful for local parsing, unit tests, and pre-downloaded content without
  /// triggering network requests or platform gates.
  static ScrapedPage fromHtml(
    String html, {
    String? url,
  }) {
    final document = HtmlDocument.parse(html, url: url);
    return ScrapedPage(
      url: url ?? 'https://localhost/',
      document: document,
      statusCode: 200,
    );
  }
}
