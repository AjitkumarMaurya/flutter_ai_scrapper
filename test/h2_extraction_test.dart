import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scrapper/mobile_scraper.dart';

void main() {
  group('H2 Tag Extraction Tests', () {
    // Sample HTML simulating structure similar to castingdoor.com
    const castingDoorLikeHtml = '''
    <!DOCTYPE html>
    <html>
    <head>
      <title>Castingdoor - Artist Platform</title>
      <meta name="description" content="Connect with artists and casting opportunities">
    </head>
    <body>
      <nav>
        <h1>Castingdoor</h1>
        <ul>
          <li>Home</li>
          <li>Artists</li>
          <li>Events</li>
          <li>FAQ</li>
        </ul>
      </nav>
      
      <main>
        <section class="hero">
          <h1>Welcome to Castingdoor</h1>
          <p>Your gateway to the entertainment industry</p>
        </section>
        
        <section class="categories">
          <h2>Artist Categories</h2>
          <div class="category-grid">
            <div class="category">Actors</div>
            <div class="category">Musicians</div>
            <div class="category">Dancers</div>
            <div class="category">Models</div>
            <div class="category">Voice Artists</div>
          </div>
        </section>
        
        <section class="featured">
          <h2>Top Artists</h2>
          <div class="artist-grid">
            <div class="artist-card">John Doe - Actor</div>
            <div class="artist-card">Jane Smith - Singer</div>
            <div class="artist-card">Mike Johnson - Dancer</div>
          </div>
        </section>
        
        <section class="newcomers">
          <h2>New Faces</h2>
          <div class="artist-grid">
            <div class="artist-card">Sarah Wilson - Model</div>
            <div class="artist-card">Tom Brown - Voice Artist</div>
          </div>
        </section>
        
        <section class="app-promotion">
          <h2>The Castingdoor App</h2>
          <p>Download our mobile app for better experience</p>
          <div class="download-links">
            <a href="#appstore">App Store</a>
            <a href="#playstore">Play Store</a>
          </div>
        </section>
        
        <section class="contact">
          <h2>Contact Information</h2>
          <p>Email: info@castingdoor.com</p>
          <p>Follow us on social media</p>
        </section>
      </main>
      
      <footer>
        <h2>About Castingdoor</h2>
        <p>Copyright © 2024 Castingdoor All rights reserved</p>
        <div class="links">
          <a href="#privacy">Privacy Policy</a>
          <a href="#terms">Terms of Service</a>
        </div>
      </footer>
    </body>
    </html>
    ''';

    late TestMobileScraper scraper;

    setUp(() {
      scraper = TestMobileScraper(
          'https://test-castingdoor.com', castingDoorLikeHtml);
    });

    test('should extract all H2 tags from castingdoor-like structure', () {
      final h2Results = scraper.queryAll(tag: 'h2');

      print('\n🎯 === H2 TAG EXTRACTION RESULTS ===');
      print('📊 Total H2 tags found: ${h2Results.length}');
      print('📝 H2 tag contents:');
      for (int i = 0; i < h2Results.length; i++) {
        print('  ${i + 1}. "${h2Results[i]}"');
      }

      // Verify expected H2 tags are found
      expect(h2Results.length, equals(6));
      expect(h2Results, contains('Artist Categories'));
      expect(h2Results, contains('Top Artists'));
      expect(h2Results, contains('New Faces'));
      expect(h2Results, contains('The Castingdoor App'));
      expect(h2Results, contains('Contact Information'));
      expect(h2Results, contains('About Castingdoor'));
    });

    test('should extract H2 tags with specific class selectors', () {
      const htmlWithClasses = '''
      <html>
      <body>
        <h2 class="section-title">Main Categories</h2>
        <h2 class="featured-section">Featured Content</h2>
        <h2 class="section-title">Sub Categories</h2>
        <h2>Regular H2</h2>
      </body>
      </html>
      ''';

      final classBasedScraper =
          TestMobileScraper('https://test.com', htmlWithClasses);
      final sectionTitles =
          classBasedScraper.queryAll(tag: 'h2', className: 'section-title');

      print('\n🎯 === CLASS-BASED H2 EXTRACTION ===');
      print('📊 H2 tags with "section-title" class: ${sectionTitles.length}');
      for (final title in sectionTitles) {
        print('  • "$title"');
      }

      expect(sectionTitles.length, equals(3));
      expect(sectionTitles, contains('Main Categories'));
      expect(sectionTitles, contains('Sub Categories'));
    });

    test('should demonstrate smart content extraction on castingdoor-like page',
        () {
      final smartContent = scraper.extractSmartContent();

      print('\n🧠 === SMART CONTENT EXTRACTION ===');
      print('📰 Title: "${smartContent.title}"');
      print('📄 Description: "${smartContent.description}"');
      print('👤 Author: "${smartContent.author ?? "Not found"}"');
      print('🖼️ Images found: ${smartContent.images.length}');
      print('🔗 Links found: ${smartContent.links.length}');
      print('📧 Emails found: ${smartContent.emails.length}');

      // Verify smart extraction works
      expect(smartContent.title, equals('Castingdoor - Artist Platform'));
      expect(smartContent.description, contains('Connect with artists'));
      expect(smartContent.emails.length, equals(1));
      expect(smartContent.emails.first, equals('info@castingdoor.com'));
    });

    test('should extract content using regex patterns', () {
      // Extract artist names using regex
      final artistNames = scraper.queryWithRegex(
          pattern:
              r'([A-Z][a-z]+ [A-Z][a-z]+) - (Actor|Singer|Dancer|Model|Voice Artist)');

      print('\n🔍 === REGEX EXTRACTION ===');
      print('🎭 Artist entries found: ${artistNames.length}');
      for (final artist in artistNames) {
        print('  • "$artist"');
      }

      expect(artistNames.length, greaterThan(0));
    });

    test('should format content to markdown', () {
      final markdown = scraper.toMarkdown();

      print('\n📝 === MARKDOWN CONVERSION ===');
      print('📄 Markdown length: ${markdown.length} characters');
      print('📝 First 200 characters:');
      print(
          '"${markdown.length > 200 ? markdown.substring(0, 200) + '...' : markdown}"');

      // Verify H2 tags are converted to markdown headers
      expect(markdown, contains('## Artist Categories'));
      expect(markdown, contains('## Top Artists'));
      expect(markdown, contains('## New Faces'));
    });

    test('should analyze content statistics', () {
      final wordCount = scraper.getWordCount();
      final readingTime = scraper.estimateReadingTime();
      final plainText = scraper.toPlainText();

      print('\n📊 === CONTENT ANALYSIS ===');
      print('📖 Word count: $wordCount');
      print(
          '⏱️ Reading time: ${readingTime.inMinutes} min ${readingTime.inSeconds % 60} sec');
      print('📄 Plain text length: ${plainText.length} characters');
      print('📝 First line of plain text: "${plainText.split('\n').first}"');

      expect(wordCount, greaterThan(0));
      expect(readingTime.inSeconds, greaterThan(0));
    });
  });
}

/// Test helper class for simulating mobile scraper functionality
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

  @override
  SmartContent extractSmartContent() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }
    return SmartExtractor.extractAll(_htmlContent!);
  }

  @override
  String toMarkdown() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }
    return ContentFormatter.toMarkdown(_htmlContent!);
  }

  @override
  String toPlainText() {
    if (_htmlContent == null) {
      throw ScraperNotInitializedException();
    }
    return ContentFormatter.toPlainText(_htmlContent!);
  }

  @override
  int getWordCount() {
    final plainText = toPlainText();
    return ContentFormatter.wordCount(plainText);
  }

  @override
  Duration estimateReadingTime({int wordsPerMinute = 200}) {
    final plainText = toPlainText();
    return ContentFormatter.estimateReadingTime(plainText,
        wordsPerMinute: wordsPerMinute);
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
