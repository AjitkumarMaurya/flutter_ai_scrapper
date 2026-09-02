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

export 'src/config/scraper_config.dart';
export 'src/exceptions/scraper_exceptions.dart';
export 'src/mobile_scraper.dart';
export 'src/models/scrape_request.dart';
export 'src/models/scrape_result.dart';
export 'src/utils/cache_manager.dart';
export 'src/utils/content_formatter.dart';
export 'src/utils/smart_extractor.dart';
