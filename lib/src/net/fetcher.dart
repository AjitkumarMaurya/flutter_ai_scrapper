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
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
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
    if (parsed == null ||
        (!parsed.isScheme('http') && !parsed.isScheme('https'))) {
      return null;
    }
    return parsed;
  }
}
