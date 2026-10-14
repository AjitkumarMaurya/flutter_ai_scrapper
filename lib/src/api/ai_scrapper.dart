import 'package:http/http.dart' as http;
import '../ai/ai_provider.dart';
import '../cache/cache_store.dart';
import '../core/scraper_config.dart';
import '../dom/html_document.dart';
import '../models/scrape_result.dart';
import '../net/fetcher.dart';
import '../reduce/chunker.dart';

class AiScrapper {
  final ScraperConfig config;
  final AiProvider? aiProvider;
  final Fetcher _fetcher;
  final CacheStore<ParsedDocumentData> _cache;

  AiScrapper({
    this.config = const ScraperConfig(),
    this.aiProvider,
    http.Client? httpClient,
  })  : _fetcher = Fetcher(client: httpClient, config: config),
        _cache = CacheStore<ParsedDocumentData>(defaultTtl: config.cacheTtl);

  /// Scrapes a URL using background isolates for DOM parsing and optionally runs AI extraction.
  Future<ScrapeResult> scrape(
    String url, {
    List<String> selectors = const [],
    String? aiInstruction,
    Map<String, String>? schemaFields,
    Map<String, String>? headers,
    bool? forceRefresh,
  }) async {
    final stopwatch = Stopwatch()..start();
    final cacheKey = '$url|${selectors.join(',')}';

    ParsedDocumentData? parsed;
    bool fromCache = false;

    if (config.enableCache && forceRefresh != true) {
      parsed = _cache.get(cacheKey);
      if (parsed != null) {
        fromCache = true;
      }
    }

    if (parsed == null) {
      final rawHtml = await _fetcher.fetchHtml(url, headers: headers);
      parsed = await HtmlDocumentParser.parseInBackground(
        rawHtml,
        baseUrl: url,
        customSelectors: selectors,
        stripBoilerplate: config.stripBoilerplate,
      );
      if (config.enableCache) {
        _cache.set(cacheKey, parsed);
      }
    }

    Map<String, dynamic>? aiData;
    if (aiInstruction != null && aiProvider != null) {
      final chunks = Chunker.chunkText(
        parsed.markdown.isNotEmpty ? parsed.markdown : parsed.cleanText,
        maxTokensPerChunk: config.maxTokensPerChunk,
      );
      final relevantChunks = Chunker.rankChunksByQuery(chunks, aiInstruction);
      final contextPayload = relevantChunks.join('\n\n---\n\n');

      aiData = await aiProvider!.extractJson(
        instruction: aiInstruction,
        content: contextPayload,
        schemaFields: schemaFields,
      );
    }

    stopwatch.stop();
    return ScrapeResult(
      url: url,
      title: parsed.title,
      cleanText: parsed.cleanText,
      markdown: parsed.markdown,
      links: parsed.links,
      selectorMatches: parsed.selectorMatches,
      structuredData: parsed.structuredData,
      aiExtractedData: aiData,
      fromCache: fromCache,
      elapsed: stopwatch.elapsed,
    );
  }

  /// Parses raw HTML directly without network fetching (useful for WebView or local HTML).
  Future<ScrapeResult> scrapeHtml(
    String rawHtml, {
    String baseUrl = 'https://localhost',
    List<String> selectors = const [],
    String? aiInstruction,
    Map<String, String>? schemaFields,
  }) async {
    final stopwatch = Stopwatch()..start();
    final parsed = await HtmlDocumentParser.parseInBackground(
      rawHtml,
      baseUrl: baseUrl,
      customSelectors: selectors,
      stripBoilerplate: config.stripBoilerplate,
    );

    Map<String, dynamic>? aiData;
    if (aiInstruction != null && aiProvider != null) {
      final chunks = Chunker.chunkText(
        parsed.markdown.isNotEmpty ? parsed.markdown : parsed.cleanText,
        maxTokensPerChunk: config.maxTokensPerChunk,
      );
      final relevantChunks = Chunker.rankChunksByQuery(chunks, aiInstruction);
      aiData = await aiProvider!.extractJson(
        instruction: aiInstruction,
        content: relevantChunks.join('\n\n---\n\n'),
        schemaFields: schemaFields,
      );
    }

    stopwatch.stop();
    return ScrapeResult(
      url: baseUrl,
      title: parsed.title,
      cleanText: parsed.cleanText,
      markdown: parsed.markdown,
      links: parsed.links,
      selectorMatches: parsed.selectorMatches,
      structuredData: parsed.structuredData,
      aiExtractedData: aiData,
      fromCache: false,
      elapsed: stopwatch.elapsed,
    );
  }

  void clearCache() => _cache.clear();

  void dispose() => _fetcher.close();
}
