import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scrapper/utils/smart_extractor.dart';

void main() {
  group('SmartExtractor', () {
    const sampleHtml = '''
    <!DOCTYPE html>
    <html>
    <head>
      <title>Test Page Title</title>
      <meta name="description" content="This is a test description">
      <meta property="og:title" content="OG Test Title">
      <meta property="og:description" content="OG Test Description">
      <meta property="og:image" content="https://example.com/og-image.jpg">
    </head>
    <body>
      <h1>Main Heading</h1>
      <p>This is the main content with <strong>bold text</strong>.</p>
      <img src="https://example.com/image1.jpg" alt="Test Image 1">
      <img src="https://example.com/image2.jpg" alt="Test Image 2">
      <a href="https://example.com/link1">Link 1</a>
      <a href="https://example.com/link2">Link 2</a>
      <p>Contact us at test@example.com or call (555) 123-4567</p>
      <p>Price: \$29.99 for this product</p>
      <div class="author">By John Doe</div>
      <time datetime="2024-01-15">January 15, 2024</time>
    </body>
    </html>
    ''';

    test('extractAll should extract all content types', () {
      final result = SmartExtractor.extractAll(sampleHtml);

      expect(result.title, isNotNull);
      expect(result.description, isNotNull);
      expect(result.images.length, greaterThan(0));
      expect(result.links.length, greaterThan(0));
      expect(result.emails.length, greaterThan(0));
      expect(result.phoneNumbers.length, greaterThan(0));
      expect(result.prices.length, greaterThan(0));
    });

    test('extractTitle should extract page title', () {
      final title = SmartExtractor.extractTitle(sampleHtml);
      expect(title, isNotNull);
      expect(title, isIn(['Test Page Title', 'OG Test Title']));
    });

    test('extractTitle should fallback to OG title', () {
      const htmlWithoutTitle = '''
      <html>
      <head>
        <meta property="og:title" content="OG Fallback Title">
      </head>
      <body><h1>Header Title</h1></body>
      </html>
      ''';

      final title = SmartExtractor.extractTitle(htmlWithoutTitle);
      expect(title, equals('OG Fallback Title'));
    });

    test('extractDescription should extract meta description', () {
      final description = SmartExtractor.extractDescription(sampleHtml);
      expect(description, isNotNull);
    });

    test('extractImages should extract all image URLs', () {
      final images = SmartExtractor.extractImages(sampleHtml);
      expect(images.length, equals(3)); // 2 img tags + 1 OG image
      expect(images, contains('https://example.com/image1.jpg'));
      expect(images, contains('https://example.com/image2.jpg'));
      expect(images, contains('https://example.com/og-image.jpg'));
    });

    test('extractLinks should extract all external links', () {
      final links = SmartExtractor.extractLinks(sampleHtml);
      expect(links.length, equals(2));
      expect(links, contains('https://example.com/link1'));
      expect(links, contains('https://example.com/link2'));
    });

    test('extractEmails should extract email addresses', () {
      final emails = SmartExtractor.extractEmails(sampleHtml);
      expect(emails.length, equals(1));
      expect(emails, contains('test@example.com'));
    });

    test('extractPhoneNumbers should extract phone numbers', () {
      final phones = SmartExtractor.extractPhoneNumbers(sampleHtml);
      expect(phones.length, greaterThanOrEqualTo(1));
      expect(phones.any((phone) => phone.contains('555')), isTrue);
    });

    test('extractPrices should extract prices', () {
      final prices = SmartExtractor.extractPrices(sampleHtml);
      expect(prices.length, equals(1));
      expect(prices.first, contains('29.99'));
    });

    test('extractOpenGraph should extract OG metadata', () {
      final og = SmartExtractor.extractOpenGraph(sampleHtml);
      expect(og, isNotNull);
      expect(og!.title, equals('OG Test Title'));
      expect(og.description, equals('OG Test Description'));
      expect(og.image, equals('https://example.com/og-image.jpg'));
    });

    test('should handle empty HTML gracefully', () {
      final result = SmartExtractor.extractAll('');
      expect(result.title, isNull);
      expect(result.description, isNull);
      expect(result.images, isEmpty);
      expect(result.links, isEmpty);
    });

    test('should clean HTML entities', () {
      const htmlWithEntities =
          '<title>Test &amp; Title with &quot;quotes&quot;</title>';
      final title = SmartExtractor.extractTitle(htmlWithEntities);
      expect(title, equals('Test & Title with "quotes"'));
    });
  });
}
