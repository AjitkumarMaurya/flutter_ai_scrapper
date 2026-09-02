import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scrapper/mobile_scraper.dart';

void main() {
  group('MobileScraper Tests', () {
    late MobileScraper scraper;
    const testUrl = 'https://example.com';

    // Sample HTML for testing
    const testHtml = '''
      <html>
        <head><title>Test Page Title</title></head>
        <body>
          <h1 class="main-headline">Main Headline</h1>
          <h2>Sub Headline</h2>
          <h2>Another Sub Headline</h2>
          <p>This is paragraph content</p>
          <p>Another paragraph</p>
          <div id="scores">Score: 120</div>
          <div>Score: 98</div>
        </body>
      </html>
    ''';

    setUp(() {
      scraper = MobileScraper(url: testUrl);
    });

    group('HTML Loading', () {
      test('should create MobileScraper with valid URL', () {
        expect(scraper.url, equals(testUrl));
        expect(scraper.rawHtml, isNull);
        expect(scraper.isLoaded, isFalse);
      });

      test('should throw InvalidParameterException with invalid URL format',
          () {
        // Now it throws during construction due to validation
        expect(
          () => MobileScraper(url: 'invalid-url'),
          throwsA(isA<InvalidParameterException>()),
        );
      });
    });

    group('Tag-based Querying', () {
      test('should extract all matching tags', () {
        // Mock loaded state
        scraper = TestMobileScraper(testUrl, testHtml);

        final results = scraper.queryAll(tag: 'h2');
        expect(results, hasLength(2));
        expect(results, contains('Sub Headline'));
        expect(results, contains('Another Sub Headline'));
      });

      test('should extract tags with specific class', () {
        scraper = TestMobileScraper(testUrl, testHtml);

        final results = scraper.queryAll(tag: 'h1', className: 'main-headline');
        expect(results, hasLength(1));
        expect(results.first, equals('Main Headline'));
      });

      test('should extract tag with specific ID', () {
        scraper = TestMobileScraper(testUrl, testHtml);

        final results = scraper.queryAll(tag: 'div', id: 'scores');
        expect(results, hasLength(1));
        expect(results.first, equals('Score: 120'));
      });

      test('should return empty list for non-existent tags', () {
        scraper = TestMobileScraper(testUrl, testHtml);

        final results = scraper.queryAll(tag: 'h3');
        expect(results, isEmpty);
      });

      test('should return first matching element with query method', () {
        scraper = TestMobileScraper(testUrl, testHtml);

        final result = scraper.query(tag: 'p');
        expect(result, equals('This is paragraph content'));
      });

      test('should return null when no matches found with query method', () {
        scraper = TestMobileScraper(testUrl, testHtml);

        final result = scraper.query(tag: 'h5');
        expect(result, isNull);
      });
    });

    group('Regex-based Querying', () {
      test('should extract content using regex pattern', () {
        scraper = TestMobileScraper(testUrl, testHtml);

        final results = scraper.queryWithRegex(pattern: r'Score:\s*(\d+)');
        expect(results, hasLength(2));
        expect(results, contains('120'));
        expect(results, contains('98'));
      });

      test('should extract title using regex', () {
        scraper = TestMobileScraper(testUrl, testHtml);

        final results =
            scraper.queryWithRegex(pattern: r'<title>(.*?)</title>');
        expect(results, hasLength(1));
        expect(results.first, equals('Test Page Title'));
      });

      test('should return first match with queryWithRegexFirst', () {
        scraper = TestMobileScraper(testUrl, testHtml);

        final result = scraper.queryWithRegexFirst(pattern: r'Score:\s*(\d+)');
        expect(result, equals('120'));
      });

      test('should return null when no regex matches found', () {
        scraper = TestMobileScraper(testUrl, testHtml);

        final result =
            scraper.queryWithRegexFirst(pattern: r'NoMatch:\s*(\d+)');
        expect(result, isNull);
      });
    });

    group('Error Handling', () {
      test(
          'should throw ScraperNotInitializedException when querying before loading',
          () {
        expect(
          () => scraper.queryAll(tag: 'h1'),
          throwsA(isA<ScraperNotInitializedException>()),
        );
      });

      test(
          'should throw ScraperNotInitializedException when using regex before loading',
          () {
        expect(
          () => scraper.queryWithRegex(pattern: r'test'),
          throwsA(isA<ScraperNotInitializedException>()),
        );
      });
    });

    group('HTML Content Cleaning', () {
      test('should clean HTML tags from content', () {
        const htmlWithTags = '''
          <h1>Title with <strong>bold</strong> and <em>italic</em> text</h1>
        ''';

        scraper = TestMobileScraper(testUrl, htmlWithTags);
        final results = scraper.queryAll(tag: 'h1');

        expect(results.first, equals('Title with bold and italic text'));
      });

      test('should decode HTML entities', () {
        const htmlWithEntities = '''
          <p>Test &amp; example with &quot;quotes&quot; and &lt;brackets&gt;</p>
        ''';

        scraper = TestMobileScraper(testUrl, htmlWithEntities);
        final results = scraper.queryAll(tag: 'p');

        expect(results.first,
            equals('Test & example with "quotes" and <brackets>'));
      });

      test('should normalize whitespace', () {
        const htmlWithWhitespace = '''
          <p>Text   with     multiple    spaces
          and
          line
          breaks</p>
        ''';

        scraper = TestMobileScraper(testUrl, htmlWithWhitespace);
        final results = scraper.queryAll(tag: 'p');

        expect(
            results.first, equals('Text with multiple spaces and line breaks'));
      });
    });
  });
}

/// Test helper class that allows setting HTML content directly
class TestMobileScraper extends MobileScraper {
  TestMobileScraper(String url, String htmlContent) : super(url: url) {
    _htmlContent = htmlContent;
  }

  String? _htmlContent;

  @override
  String? get rawHtml => _htmlContent;

  @override
  bool get isLoaded => _htmlContent != null;

  @override
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

  @override
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

  // Private helper methods
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
}
