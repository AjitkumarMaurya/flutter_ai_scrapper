#!/usr/bin/env bash

# Exit immediately if any command fails
set -e

echo "=========================================================="
echo "🧹 STEP 1: Removing Stray Python Files & Old Clutter..."
echo "=========================================================="
rm -rf src/ tests/ requirements.txt pytest.ini data/ tool/
rm -rf lib/src/ test/

echo "=========================================================="
echo "📁 STEP 2: Creating Clean Directory Architecture..."
echo "=========================================================="
mkdir -p lib/src/ai/providers
mkdir -p lib/src/api
mkdir -p lib/src/cache
mkdir -p lib/src/core
mkdir -p lib/src/dom
mkdir -p lib/src/models
mkdir -p lib/src/net
mkdir -p lib/src/reduce
mkdir -p lib/src/structured
mkdir -p test

echo "=========================================================="
echo "📝 STEP 3: Writing pubspec.yaml & analysis_options.yaml..."
echo "=========================================================="
cat << 'EOF' > pubspec.yaml
name: flutter_ai_scrapper
description: High-performance, isolate-powered web scraper and AI structured data extractor for Flutter & Dart.
version: 2.0.0
homepage: https://github.com/ajitkumarmaurya/flutter_ai_scrapper

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  http: ^1.2.1
  html: ^0.15.4
  crypto: ^3.0.3

dev_dependencies:
  lints: ^4.0.0
  test: ^1.25.2
EOF

cat << 'EOF' > analysis_options.yaml
include: package:lints/recommended.yaml

linter:
  rules:
    prefer_single_quotes: true
    avoid_print: true
    unawaited_futures: true
EOF

echo "=========================================================="
echo "⚙️ STEP 4: Implementing Core & Exceptions..."
echo "=========================================================="
cat << 'EOF' > lib/src/core/scraper_exceptions.dart
sealed class ScraperException implements Exception {
  final String message;
  final Object? cause;

  const ScraperException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType:$message${cause != null ? ' ($cause)' : ''}';
}

class NetworkScraperException extends ScraperException {
  final int? statusCode;
  const NetworkScraperException(super.message, {this.statusCode, Object? cause})
      : super(cause);
}

class ParseScraperException extends ScraperException {
  const ParseScraperException(super.message, [super.cause]);
}

class AiExtractionException extends ScraperException {
  const AiExtractionException(super.message, [super.cause]);
}

class RateLimitExceededException extends ScraperException {
  final Duration? retryAfter;
  const RateLimitExceededException(super.message, {this.retryAfter});
}
EOF

cat << 'EOF' > lib/src/core/scraper_config.dart
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
EOF

echo "=========================================================="
echo "🌐 STEP 5: Implementing Network Layer (Retry & Rate Limit)..."
echo "=========================================================="
cat << 'EOF' > lib/src/net/fetcher.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/scraper_config.dart';
import '../core/scraper_exceptions.dart';

class Fetcher {
  final http.Client _client;
  final ScraperConfig config;

  Fetcher({http.Client? client, this.config = const ScraperConfig()})
      : _client = client ?? http.Client();

  Future<String> fetchHtml(String url, {Map<String, String>? headers}) async {
    final uri = Uri.tryParsetarget(url);
    if (uri == null) {
      throw NetworkScraperException('Invalid URL provided: $url');
    }

    final mergedHeaders = <String, String>{
      'User-Agent': config.userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      ...?headers,
    };

    int attempt = 0;
    while (true) {
      try {
        final response = await _client
            .get(uri, headers: mergedHeaders)
            .timeout(config.timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _decodeBody(response);
        }

        if (response.statusCode == 429) {
          throw const RateLimitExceededException('HTTP 429 Too Many Requests');
        }

        if (response.statusCode >= 500 && attempt < config.maxRetries) {
          attempt++;
          await Future<void>.delayed(config.retryDelay * attempt);
          continue;
        }

        throw NetworkScraperException(
          'HTTP request failed with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      } on TimeoutException catch (e) {
        if (attempt < config.maxRetries) {
          attempt++;
          await Future<void>.delayed(config.retryDelay * attempt);
          continue;
        }
        throw NetworkScraperException('Request timed out for $url', cause: e);
      } catch (e) {
        if (e is ScraperException) rethrow;
        if (attempt < config.maxRetries) {
          attempt++;
          await Future<void>.delayed(config.retryDelay * attempt);
          continue;
        }
        throw NetworkScraperException('Failed to fetch $url', cause: e);
      }
    }
  }

  String _decodeBody(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(response.bodyBytes, allowInvalid: true);
    }
  }

  void close() => _client.close();
}

extension _UriCheck on Uri {
  static Uri? tryParsetarget(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || (!parsed.isScheme('http') && !parsed.isScheme('https'))) {
      return null;
    }
    return parsed;
  }
}
EOF

echo "=========================================================="
echo "🧠 STEP 6: Implementing Background Isolate DOM & Structured Data..."
echo "=========================================================="
cat << 'EOF' > lib/src/structured/structured_extractor.dart
import 'dart:convert';
import 'package:html/dom.dart' as dom;

class StructuredExtractor {
  /// Extracts JSON-LD, OpenGraph, and standard Meta tags from a parsed DOM.
  static Map<String, dynamic> extractAll(dom.Document document) {
    return {
      'openGraph': _extractOpenGraph(document),
      'jsonLd': _extractJsonLd(document),
      'meta': _extractMeta(document),
    };
  }

  static Map<String, String> _extractOpenGraph(dom.Document doc) {
    final og = <String, String>{};
    for (final meta in doc.querySelectorAll('meta[property^="og:"]')) {
      final prop = meta.attributes['property']?.substring(3);
      final content = meta.attributes['content']?.trim();
      if (prop != null && content != null && content.isNotEmpty) {
        og[prop] = content;
      }
    }
    return og;
  }

  static Map<String, String> _extractMeta(dom.Document doc) {
    final metaMap = <String, String>{};
    for (final meta in doc.querySelectorAll('meta[name]')) {
      final name = meta.attributes['name']?.toLowerCase().trim();
      final content = meta.attributes['content']?.trim();
      if (name != null && content != null && content.isNotEmpty) {
        metaMap[name] = content;
      }
    }
    return metaMap;
  }

  static List<Map<String, dynamic>> _extractJsonLd(dom.Document doc) {
    final list = <Map<String, dynamic>>[];
    final scripts = doc.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
      final raw = script.text.trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          list.add(decoded);
        } else if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) list.add(item);
          }
        }
      } catch (_) {
        // Ignore malformed JSON-LD blocks on broken sites
      }
    }
    return list;
  }
}
EOF

cat << 'EOF' > lib/src/dom/html_document.dart
import 'dart:isolate';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../structured/structured_extractor.dart';

class ParsedDocumentData {
  final String title;
  final String cleanText;
  final String markdown;
  final List<String> links;
  final Map<String, List<String>> selectorMatches;
  final Map<String, dynamic> structuredData;

  const ParsedDocumentData({
    required this.title,
    required this.cleanText,
    required this.markdown,
    required this.links,
    required this.selectorMatches,
    required this.structuredData,
  });
}

class HtmlDocumentParser {
  static const List<String> _noiseSelectors = [
    'script',
    'style',
    'noscript',
    'iframe',
    'svg',
    'canvas',
    'nav',
    'footer',
    'header',
    'aside',
    '.ads',
    '.advertisement',
    '.cookie-banner',
    '#cookie-banner',
  ];

  /// Parses HTML, strips noise, extracts Markdown & Structured Data inside a background Isolate.
  static Future<ParsedDocumentData> parseInBackground(
    String rawHtml, {
    String? baseUrl,
    List<String> customSelectors = const [],
    bool stripBoilerplate = true,
  }) async {
    return Isolate.run(() {
      final document = html_parser.parse(rawHtml);

      final title = document.querySelector('title')?.text.trim() ??
          document
              .querySelector('meta[property="og:title"]')
              ?.attributes['content']
              ?.trim() ??
          '';

      // Extract structured metadata before mutating DOM
      final structured = StructuredExtractor.extractAll(document);

      // Run custom selectors before stripping boilerplate in case user targets nav/footer
      final selectorResults = <String, List<String>>{};
      for (final selector in customSelectors) {
        final nodes = document.querySelectorAll(selector);
        selectorResults[selector] = nodes
            .map((e) => e.text.replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }

      // Extract resolved links
      final baseUri = baseUrl != null ? Uri.tryParse(baseUrl) : null;
      final links = <String>{};
      for (final a in document.querySelectorAll('a[href]')) {
        final href = a.attributes['href']?.trim();
        if (href == null || href.isEmpty || href.startsWith('javascript:')) {
          continue;
        }
        if (baseUri != null) {
          final resolved = baseUri.resolveUri(Uri.tryParse(href) ?? Uri());
          links.add(resolved.toString());
        } else {
          links.add(href);
        }
      }

      // Strip scripts, styles, and boilerplate noise
      if (stripBoilerplate) {
        for (final sel in _noiseSelectors) {
          document.querySelectorAll(sel).forEach((el) => el.remove());
        }
      } else {
        document
            .querySelectorAll('script, style, noscript')
            .forEach((el) => el.remove());
      }

      final root = document.querySelector('main') ??
          document.querySelector('article') ??
          document.body;

      final markdown = _convertToMarkdown(root);
      final cleanText = (root?.text ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      return ParsedDocumentData(
        title: title,
        cleanText: cleanText,
        markdown: markdown,
        links: links.toList(),
        selectorMatches: selectorResults,
        structuredData: structured,
      );
    });
  }

  static String _convertToMarkdown(dom.Element? root) {
    if (root == null) return '';
    final buffer = StringBuffer();

    void walk(dom.Node node) {
      if (node is dom.Text) {
        final text = node.text.replaceAll(RegExp(r'[ \t]+'), ' ');
        if (text.trim().isNotEmpty) {
          buffer.write(text);
        }
        return;
      }

      if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        switch (tag) {
          case 'h1':
            buffer.write('\n\n# ');
            node.nodes.forEach(walk);
            buffer.write('\n\n');
            break;
          case 'h2':
            buffer.write('\n\n## ');
            node.nodes.forEach(walk);
            buffer.write('\n\n');
            break;
          case 'h3':
          case 'h4':
            buffer.write('\n\n### ');
            node.nodes.forEach(walk);
            buffer.write('\n\n');
            break;
          case 'p':
          case 'div':
          case 'section':
          case 'article':
            buffer.write('\n\n');
            node.nodes.forEach(walk);
            buffer.write('\n\n');
            break;
          case 'li':
            buffer.write('\n- ');
            node.nodes.forEach(walk);
            break;
          case 'br':
            buffer.write('\n');
            break;
          default:
            node.nodes.forEach(walk);
        }
      }
    }

    walk(root);
    return buffer
        .toString()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
EOF

echo "=========================================================="
echo "✂️ STEP 7: Implementing Smart Token Chunker & BM25 Ranker..."
echo "=========================================================="
cat << 'EOF' > lib/src/reduce/chunker.dart
class Chunker {
  /// Splits text or markdown into chunks within the token budget (~4 chars/token).
  static List<String> chunkText(
    String text, {
    int maxTokensPerChunk = 3000,
  }) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return const [];

    final maxChars = maxTokensPerChunk * 4;
    if (cleaned.length <= maxChars) return [cleaned];

    final chunks = <String>[];
    final paragraphs = cleaned.split(RegExp(r'\n\s*\n'));
    final buffer = StringBuffer();

    for (final para in paragraphs) {
      final trimmedPara = para.trim();
      if (trimmedPara.isEmpty) continue;

      if (buffer.length + trimmedPara.length + 2 > maxChars) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }
        if (trimmedPara.length > maxChars) {
          for (var i = 0; i < trimmedPara.length; i += maxChars) {
            final end = (i + maxChars < trimmedPara.length)
                ? i + maxChars
                : trimmedPara.length;
            chunks.add(trimmedPara.substring(i, end));
          }
        } else {
          buffer.write(trimmedPara);
        }
      } else {
        if (buffer.isNotEmpty) buffer.write('\n\n');
        buffer.write(trimmedPara);
      }
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }

    return chunks;
  }

  /// Ranks chunks by relevance to an extraction query so only top relevant chunks hit the LLM.
  static List<String> rankChunksByQuery(
    List<String> chunks,
    String query, {
    int topK = 3,
  }) {
    if (chunks.length <= topK) return chunks;

    final terms = query
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((t) => t.length > 2)
        .toSet();

    if (terms.isEmpty) return chunks.take(topK).toList();

    final scored = <({String chunk, double score})>[];
    for (final chunk in chunks) {
      final lower = chunk.toLowerCase();
      double score = 0;
      for (final term in terms) {
        final matches = RegExp(RegExp.escape(term)).allMatches(lower).length;
        score += matches * (1.0 + (term.length * 0.1));
      }
      scored.add((chunk: chunk, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).map((e) => e.chunk).toList();
  }
}
EOF

echo "=========================================================="
echo "💾 STEP 8: Implementing LRU + TTL Cache Store..."
echo "=========================================================="
cat << 'EOF' > lib/src/cache/cache_store.dart
import 'dart:collection';

class CacheStore<T> {
  final int maxEntries;
  final Duration defaultTtl;
  final LinkedHashMap<String, _CacheItem<T>> _map = LinkedHashMap();

  CacheStore({
    this.maxEntries = 100,
    this.defaultTtl = const Duration(minutes: 30),
  });

  T? get(String key) {
    final item = _map.remove(key);
    if (item == null) return null;

    if (DateTime.now().isAfter(item.expiresAt)) {
      return null;
    }

    // Re-insert to mark as most recently used (LRU)
    _map[key] = item;
    return item.value;
  }

  void set(String key, T value, {Duration? ttl}) {
    if (_map.length >= maxEntries && !_map.containsKey(key)) {
      _map.remove(_map.keys.first);
    }
    _map.remove(key);
    _map[key] = _CacheItem<T>(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  void invalidate(String key) => _map.remove(key);

  void clear() => _map.clear();

  int get length => _map.length;
}

class _CacheItem<T> {
  final T value;
  final DateTime expiresAt;

  const _CacheItem({required this.value, required this.expiresAt});
}
EOF

echo "=========================================================="
echo "🤖 STEP 9: Implementing AI Providers (OpenAI, Gemini, Anthropic)..."
echo "=========================================================="
cat << 'EOF' > lib/src/ai/ai_provider.dart
import 'dart:convert';
import '../core/scraper_exceptions.dart';

abstract class AiProvider {
  String get name;

  /// Sends prompt and scraped context to the AI model and returns the raw text response.
  Future<String> complete({
    required String systemPrompt,
    required String userContent,
    bool jsonMode = false,
  });

  /// Extracts structured JSON map from scraped content using the AI provider.
  Future<Map<String, dynamic>> extractJson({
    required String instruction,
    required String content,
    Map<String, String>? schemaFields,
  }) async {
    final schemaDesc = schemaFields != null && schemaFields.isNotEmpty
        ? '\nRequired JSON keys and types:\n${schemaFields.entries.map((e) => '- "${e.key}": ${e.value}').join('\n')}'
        : '';

    final systemPrompt =
        'You are a precise web data extraction engine. Extract the requested information from the provided webpage content and return ONLY valid JSON.$schemaDesc';

    final response = await complete(
      systemPrompt: systemPrompt,
      userContent: 'Instruction: $instruction\n\nWebpage Content:\n$content',
      jsonMode: true,
    );

    return parseJsonResponse(response);
  }

  static Map<String, dynamic> parseJsonResponse(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } catch (e) {
      // Attempt to locate first '{' and last '}'
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        try {
          final sub = jsonDecode(cleaned.substring(start, end + 1));
          if (sub is Map<String, dynamic>) return sub;
        } catch (_) {}
      }
      throw AiExtractionException(
        'Failed to parse AI response as valid JSON: $raw',
        e,
      );
    }
  }
}
EOF

cat << 'EOF' > lib/src/ai/providers/openai_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/scraper_exceptions.dart';
import '../ai_provider.dart';

class OpenAiProvider extends AiProvider {
  final String apiKey;
  final String model;
  final String baseUrl;
  final http.Client _client;

  OpenAiProvider({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    this.baseUrl = '[https://api.openai.com/v1/chat/completions](https://api.openai.com/v1/chat/completions)',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'openai:$model';

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userContent,
    bool jsonMode = false,
  }) async {
    final payload = <String, dynamic>{
      'model': model,
      'temperature': 0.1,
      if (jsonMode) 'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContent},
      ],
    };

    final response = await _client.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw AiExtractionException(
        'OpenAI API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const AiExtractionException('OpenAI returned empty choices');
    }

    return (choices.first['message']['content'] as String?) ?? '';
  }
}
EOF

cat << 'EOF' > lib/src/ai/providers/gemini_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/scraper_exceptions.dart';
import '../ai_provider.dart';

class GeminiProvider extends AiProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  GeminiProvider({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'gemini:$model';

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userContent,
    bool jsonMode = false,
  }) async {
    final uri = Uri.parse(
      '[https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey](https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey)',
    );

    final payload = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userContent}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        if (jsonMode) 'responseMimeType': 'application/json',
      },
    };

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw AiExtractionException(
        'Gemini API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const AiExtractionException('Gemini returned empty candidates');
    }

    final parts = candidates.first['content']['parts'] as List<dynamic>;
    return (parts.first['text'] as String?) ?? '';
  }
}
EOF

cat << 'EOF' > lib/src/ai/providers/anthropic_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/scraper_exceptions.dart';
import '../ai_provider.dart';

class AnthropicProvider extends AiProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  AnthropicProvider({
    required this.apiKey,
    this.model = 'claude-3-5-haiku-latest',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'anthropic:$model';

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userContent,
    bool jsonMode = false,
  }) async {
    final response = await _client.post(
      Uri.parse('[https://api.anthropic.com/v1/messages](https://api.anthropic.com/v1/messages)'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 4096,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userContent},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw AiExtractionException(
        'Anthropic API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final contentList = decoded['content'] as List<dynamic>?;
    if (contentList == null || contentList.isEmpty) {
      throw const AiExtractionException('Anthropic returned empty content');
    }

    return (contentList.first['text'] as String?) ?? '';
  }
}
EOF

echo "=========================================================="
echo "📦 STEP 10: Implementing Models & High-Level AiScrapper API..."
echo "=========================================================="
cat << 'EOF' > lib/src/models/scrape_result.dart
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
EOF

cat << 'EOF' > lib/src/api/ai_scrapper.dart
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
EOF

cat << 'EOF' > lib/flutter_ai_scrapper.dart
library flutter_ai_scrapper;

export 'src/ai/ai_provider.dart';
export 'src/ai/providers/anthropic_provider.dart';
export 'src/ai/providers/gemini_provider.dart';
export 'src/ai/providers/openai_provider.dart';
export 'src/api/ai_scrapper.dart';
export 'src/cache/cache_store.dart';
export 'src/core/scraper_config.dart';
export 'src/core/scraper_exceptions.dart';
export 'src/dom/html_document.dart';
export 'src/models/scrape_result.dart';
export 'src/net/fetcher.dart';
export 'src/reduce/chunker.dart';
export 'src/structured/structured_extractor.dart';
EOF

echo "=========================================================="
echo "🧪 STEP 11: Writing Comprehensive Unit Test Suite..."
echo "=========================================================="
cat << 'EOF' > test/flutter_ai_scrapper_test.dart
import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:test/test.dart';

class _MockAiProvider extends AiProvider {
  @override
  String get name => 'mock';

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userContent,
    bool jsonMode = false,
  }) async {
    return '```json\n{"product": "Super Widget", "price": 49.99}\n```';
  }
}

void main() {
  group('HtmlDocumentParser (Isolate Execution)', () {
    test('extracts title, markdown, links, JSON-LD, OpenGraph, and selectors', () async {
      const sampleHtml = '''
      <!DOCTYPE html>
      <html>
        <head>
          <title>Test Product Page</title>
          <meta property="og:title" content="OG Product Title" />
          <meta name="description" content="Best widget in 2026" />
          <script type="application/ld+json">
            {"@context": "[https://schema.org](https://schema.org)", "@type": "Product", "name": "Super Widget"}
          </script>
          <script>console.log("noise that must be stripped");</script>
        </head>
        <body>
          <nav>Menu link that should be stripped</nav>
          <main>
            <h1>Super Widget</h1>
            <p class="price">\$49.99</p>
            <p>High-efficiency widget built for speed.</p>
            <a href="/specs">View Specs</a>
          </main>
          <footer>Copyright 2026</footer>
        </body>
      </html>
      ''';

      final scrapper = AiScrapper(aiProvider: _MockAiProvider());
      final result = await scrapper.scrapeHtml(
        sampleHtml,
        baseUrl: '[https://example.com/shop/item](https://example.com/shop/item)',
        selectors: ['.price', 'h1'],
        aiInstruction: 'Extract product and price',
      );

      expect(result.title, equals('Test Product Page'));
      expect(result.cleanText, isNot(contains('console.log')));
      expect(result.cleanText, isNot(contains('Menu link')));
      expect(result.markdown, contains('# Super Widget'));
      expect(result.selectorMatches['.price'], equals(['\$49.99']));
      expect(result.links, contains('[https://example.com/specs](https://example.com/specs)'));
      expect(result.structuredData['openGraph']['title'], equals('OG Product Title'));
      expect(result.structuredData['jsonLd'].first['name'], equals('Super Widget'));
      expect(result.aiExtractedData?['product'], equals('Super Widget'));
      expect(result.aiExtractedData?['price'], equals(49.99));
    });
  });

  group('Chunker & BM25 Relevance Ranking', () {
    test('splits long text within token budget and ranks relevant chunks first', () {
      final para1 = 'Introduction to gardening and flowers. ' * 40;
      final para2 = 'Pricing details: Enterprise plan costs \$299 per month. ' * 40;
      final para3 = 'Company history and team bios. ' * 40;
      final combined = '$para1\n\n$para2\n\n$para3';

      final chunks = Chunker.chunkText(combined, maxTokensPerChunk: 250);
      expect(chunks.length, greaterThanOrEqualTo(3));

      final ranked = Chunker.rankChunksByQuery(chunks, 'pricing enterprise cost', topK: 1);
      expect(ranked.first, contains('Enterprise plan costs'));
    });
  });

  group('CacheStore LRU & TTL', () {
    test('evicts oldest entry when maxEntries is reached and respects TTL', () async {
      final cache = CacheStore<String>(
        maxEntries: 2,
        defaultTtl: const Duration(milliseconds: 50),
      );

      cache.set('k1', 'v1');
      cache.set('k2', 'v2');
      // Access k1 so k2 becomes least recently used
      expect(cache.get('k1'), equals('v1'));

      cache.set('k3', 'v3');
      expect(cache.get('k2'), isNull);
      expect(cache.get('k1'), equals('v1'));
      expect(cache.get('k3'), equals('v3'));

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(cache.get('k1'), isNull);
    });
  });
}
EOF

echo "=========================================================="
echo "🔧 STEP 12: Fetching Dependencies, Formatting & Testing..."
echo "=========================================================="
dart pub get
dart format lib test
dart analyze
dart test

echo "=========================================================="
echo "✅ OVERHAUL COMPLETE! All tests & static checks passed."
echo "=========================================================="