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

export 'src/ai/ai_provider.dart';
export 'src/ai/cost_tracker.dart';
export 'src/ai/extractor.dart';
export 'src/ai/fake_ai_provider.dart';
export 'src/ai/model_manager.dart';
export 'src/ai/planner.dart';
export 'src/ai/provider_chain.dart';
export 'src/ai/providers/anthropic_provider.dart';
export 'src/ai/providers/custom_provider.dart';
export 'src/ai/providers/gemma_provider.dart';
export 'src/ai/providers/openai_provider.dart';
export 'src/ai/tool_bridge.dart';
export 'src/api/ai_scrapper.dart';
export 'src/api/scraped_page.dart';
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
export 'src/output/codecs/codecs.dart';
export 'src/output/normalizers/date_normalizer.dart';
export 'src/output/normalizers/money_normalizer.dart';
export 'src/output/normalizers/number_normalizer.dart';
export 'src/output/normalizers/phone_normalizer.dart';
export 'src/output/normalizers/url_normalizer.dart';
export 'src/readability/scorer.dart';
export 'src/recipe/recipe.dart';
export 'src/recipe/runner.dart';
export 'src/recipe/skeleton.dart';
export 'src/recipe/store.dart';
export 'src/recipe/synthesizer.dart';
export 'src/reduce/bm25_ranker.dart';
export 'src/reduce/budget.dart';
export 'src/reduce/chunker.dart';
export 'src/reduce/markdown_writer.dart';
export 'src/reduce/token_estimator.dart';
export 'src/schema/field.dart';
export 'src/schema/schema.dart';
export 'src/structured/json_ld.dart';
export 'src/structured/mapper.dart';
export 'src/structured/microdata.dart';
export 'src/structured/open_graph.dart';
export 'src/structured/rdfa.dart';
export 'src/ui/extraction_console.dart';
export 'src/ui/model_manager_sheet.dart';
export 'src/ui/provider_settings_sheet.dart';
export 'src/ui/result_viewer.dart';
export 'src/ui/streaming_text_view.dart';
export 'src/utils/content_formatter.dart';
export 'src/utils/smart_extractor.dart';
