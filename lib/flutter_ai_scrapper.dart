/// On-device AI web scraping for Flutter (Android and iOS).
///
/// Fetches a page, parses it, and extracts what you asked for — preferring
/// deterministic sources over inference wherever it can:
///
/// 1. Structured data the page already publishes (JSON-LD, OpenGraph, …)
/// 2. A cached selector recipe for that host
/// 3. A language model, local or remote, constrained by your schema
///
/// ```dart
/// final scraper = MobileScraper(url: 'https://example.com');
/// await scraper.load();
/// final headings = scraper.queryAll(tag: 'h1');
/// ```
///
/// Android and iOS only — see `platforms:` in `pubspec.yaml`.
///
/// Exports are ordered alphabetically by path to satisfy `directives_ordering`;
/// the groupings they fall into are configuration, exceptions, the scraper
/// itself, request/result models, and the caching, formatting and extraction
/// utilities.
library;

export 'src/cache/cache_store.dart';
export 'src/core/cancellation.dart';
export 'src/core/platform_info.dart';
export 'src/core/scraper_config.dart';
export 'src/core/scraper_exceptions.dart';
export 'src/dom/html_document.dart';
export 'src/dom/sanitizer.dart';
export 'src/dom/selector.dart';
export 'src/dom/url_resolver.dart';
export 'src/mobile_scraper.dart';
export 'src/models/scrape_request.dart';
export 'src/models/scrape_result.dart';
export 'src/net/encoding_detector.dart';
export 'src/net/fetcher.dart';
export 'src/net/rate_limiter.dart';
export 'src/net/retry_policy.dart';
export 'src/net/robots_policy.dart';
export 'src/utils/content_formatter.dart';
export 'src/utils/smart_extractor.dart';
