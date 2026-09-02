import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

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
      scraper = MobileScraper(
        url: testUrl,
        // 2.0 removed the FLUTTER_TEST environment sniffing that used to
        // bypass the platform gate from inside production code. Tests
        // now declare the platform they mean to exercise.
        platformInfo: const FakePlatformInfo.android(),
      );
    });

    group('HTML Loading', () {
      test('should create MobileScraper with valid URL', () {
        expect(scraper.url, equals(testUrl));
        expect(scraper.rawHtml, isNull);
        expect(scraper.isLoaded, isFalse);
      });

      test('should throw InvalidUrlException with invalid URL format', () {
        // Validation runs during construction. 2.0 splits URL problems out of
        // the catch-all InvalidParameterException into their own type, so a
        // caller can tell "bad address" from "bad selector".
        expect(
          () => MobileScraper(
            url: 'invalid-url',
            platformInfo: const FakePlatformInfo.android(),
          ),
          throwsA(isA<InvalidUrlException>()),
        );
      });
    });

    group('Tag-based Querying', () {
      test('should extract all matching tags', () {
        // Mock loaded state
        scraper = MobileScraper.fromHtml(testHtml, url: testUrl);

        final results = scraper.queryAll(tag: 'h2');
        expect(results, hasLength(2));
        expect(results, contains('Sub Headline'));
        expect(results, contains('Another Sub Headline'));
      });

      test('should extract tags with specific class', () {
        scraper = MobileScraper.fromHtml(testHtml, url: testUrl);

        final results = scraper.queryAll(tag: 'h1', className: 'main-headline');
        expect(results, hasLength(1));
        expect(results.first, equals('Main Headline'));
      });

      test('should extract tag with specific ID', () {
        scraper = MobileScraper.fromHtml(testHtml, url: testUrl);

        final results = scraper.queryAll(tag: 'div', id: 'scores');
        expect(results, hasLength(1));
        expect(results.first, equals('Score: 120'));
      });

      test('should return empty list for non-existent tags', () {
        scraper = MobileScraper.fromHtml(testHtml, url: testUrl);

        final results = scraper.queryAll(tag: 'h3');
        expect(results, isEmpty);
      });

      test('should return first matching element with query method', () {
        scraper = MobileScraper.fromHtml(testHtml, url: testUrl);

        final result = scraper.query(tag: 'p');
        expect(result, equals('This is paragraph content'));
      });

      test('should return null when no matches found with query method', () {
        scraper = MobileScraper.fromHtml(testHtml, url: testUrl);

        final result = scraper.query(tag: 'h5');
        expect(result, isNull);
      });
    });

    group('Regex-based Querying', () {
      test('should extract content using regex pattern', () {
        scraper = MobileScraper.fromHtml(testHtml, url: testUrl);

        final results = scraper.queryWithRegex(pattern: r'Score:\s*(\d+)');
        expect(results, hasLength(2));
        expect(results, contains('120'));
        expect(results, contains('98'));
      });

      test('should extract title using regex', () {
        scraper = MobileScraper.fromHtml(testHtml, url: testUrl);

        final results =
            scraper.queryWithRegex(pattern: r'<title>(.*?)</title>');
        expect(results, hasLength(1));
        expect(results.first, equals('Test Page Title'));
      });

      test('should return first match with queryWithRegexFirst', () {
        scraper = MobileScraper.fromHtml(testHtml, url: testUrl);

        final result = scraper.queryWithRegexFirst(pattern: r'Score:\s*(\d+)');
        expect(result, equals('120'));
      });

      test('should return null when no regex matches found', () {
        scraper = MobileScraper.fromHtml(testHtml, url: testUrl);

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

        scraper = MobileScraper.fromHtml(htmlWithTags, url: testUrl);
        final results = scraper.queryAll(tag: 'h1');

        expect(results.first, equals('Title with bold and italic text'));
      });

      test('should decode HTML entities', () {
        const htmlWithEntities = '''
          <p>Test &amp; example with &quot;quotes&quot; and &lt;brackets&gt;</p>
        ''';

        scraper = MobileScraper.fromHtml(htmlWithEntities, url: testUrl);
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

        scraper = MobileScraper.fromHtml(htmlWithWhitespace, url: testUrl);
        final results = scraper.queryAll(tag: 'p');

        expect(
            results.first, equals('Text with multiple spaces and line breaks'));
      });
    });
  });
}
