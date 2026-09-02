import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

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

    late MobileScraper scraper;

    setUp(() {
      scraper = MobileScraper.fromHtml(castingDoorLikeHtml, url: 'https://test-castingdoor.com');
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
          MobileScraper.fromHtml(htmlWithClasses, url: 'https://test.com');
      final sectionTitles =
          classBasedScraper.queryAll(tag: 'h2', className: 'section-title');

      print('\n🎯 === CLASS-BASED H2 EXTRACTION ===');
      print('📊 H2 tags with "section-title" class: ${sectionTitles.length}');
      for (final title in sectionTitles) {
        print('  • "$title"');
      }

      // The fixture contains exactly two <h2 class="section-title">. 1.x
      // reported three because its class lookahead scanned the rest of the
      // document (BUG-2) and matched an h2 that did not carry the class.
      expect(sectionTitles.length, equals(2));
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
          '"${markdown.length > 200 ? '${markdown.substring(0, 200)}...' : markdown}"');

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
