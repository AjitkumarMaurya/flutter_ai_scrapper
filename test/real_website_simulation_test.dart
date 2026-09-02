import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scrapper/mobile_scraper.dart';

void main() {
  group('Real Website Simulation Tests', () {
    // Test Case 1: News Website (BBC-like structure)
    const newsWebsiteHtml = '''
    <!DOCTYPE html>
    <html>
    <head>
      <title>Breaking News - Tech Innovation</title>
      <meta name="description" content="Latest technology news and innovations from around the world">
      <meta name="author" content="John Reporter">
      <meta property="og:title" content="Breaking News - Tech Innovation">
      <meta property="og:description" content="Latest technology news and innovations">
      <meta property="og:image" content="https://example.com/news-image.jpg">
    </head>
    <body>
      <header>
        <h1>Tech News Daily</h1>
        <nav>
          <a href="/home">Home</a>
          <a href="/tech">Technology</a>
          <a href="/business">Business</a>
        </nav>
      </header>
      
      <main>
        <article>
          <h1>AI Revolution Transforms Healthcare Industry</h1>
          <p class="byline">By John Reporter | Published: 2024-01-15</p>
          
          <h2>Key Developments</h2>
          <p>Artificial intelligence is revolutionizing healthcare with breakthrough innovations.</p>
          
          <h3>Machine Learning Applications</h3>
          <p>ML algorithms are improving diagnostic accuracy by 85%.</p>
          
          <h3>Patient Care Enhancement</h3>
          <p>AI-powered systems reduce treatment time by 40%.</p>
          
          <h2>Industry Impact</h2>
          <p>Healthcare costs expected to decrease by \$150 billion annually.</p>
          
          <h3>Future Prospects</h3>
          <p>Contact our newsroom at news@example-news.com for more information.</p>
          <p>Phone: +1-555-NEWS-123</p>
          <p>Follow us on social media for updates.</p>
        </article>
      </main>
      
      <footer>
        <p>Email: contact@example-news.com</p>
        <p>© 2024 Tech News Daily</p>
      </footer>
    </body>
    </html>
    ''';

    // Test Case 2: E-commerce Website (Amazon-like structure)
    const ecommerceWebsiteHtml = '''
    <!DOCTYPE html>
    <html>
    <head>
      <title>Premium Laptop - TechStore</title>
      <meta name="description" content="High-performance laptop with advanced features">
      <meta property="og:title" content="Premium Laptop - Best Deal">
      <meta property="og:price:amount" content="1299.99">
    </head>
    <body>
      <header>
        <h1>TechStore</h1>
        <nav>
          <a href="/laptops">Laptops</a>
          <a href="/phones">Phones</a>
          <a href="/accessories">Accessories</a>
        </nav>
      </header>
      
      <main>
        <div class="product">
          <h1>MacBook Pro 16-inch</h1>
          <img src="https://example.com/macbook.jpg" alt="MacBook Pro">
          
          <h2>Product Details</h2>
          <div class="price">Price: \$1,299.99</div>
          <div class="price">Was: \$1,499.99</div>
          <p>Save \$200.00 USD</p>
          
          <h3>Specifications</h3>
          <ul>
            <li>16-inch Retina Display</li>
            <li>Apple M2 Pro Chip</li>
            <li>16GB Unified Memory</li>
            <li>512GB SSD Storage</li>
          </ul>
          
          <h3>Customer Reviews</h3>
          <div class="review">
            <p>"Excellent performance!" - Sarah Tech</p>
            <p>"Best laptop I've owned" - Mike Developer</p>
          </div>
          
          <h2>Shipping Information</h2>
          <p>Free shipping on orders over \$999.99</p>
          <p>Contact support: support@example-store.com</p>
          <p>Customer service: 1-800-TECH-HELP</p>
        </div>
      </main>
    </body>
    </html>
    ''';

    // Test Case 3: Blog Website (Medium-like structure)
    const blogWebsiteHtml = '''
    <!DOCTYPE html>
    <html>
    <head>
      <title>10 Flutter Tips for Better Performance</title>
      <meta name="description" content="Essential Flutter development tips to optimize your app performance">
      <meta name="author" content="Flutter Expert">
      <meta property="article:published_time" content="2024-01-10T10:00:00Z">
    </head>
    <body>
      <header>
        <h1>Flutter Dev Blog</h1>
      </header>
      
      <main>
        <article>
          <h1>10 Flutter Tips for Better Performance</h1>
          <p class="author">By Flutter Expert</p>
          <time datetime="2024-01-10">January 10, 2024</time>
          
          <h2>Introduction</h2>
          <p>Flutter performance optimization is crucial for creating smooth user experiences.</p>
          
          <h3>Tip 1: Use const Constructors</h3>
          <p>Const constructors help Flutter avoid unnecessary widget rebuilds.</p>
          
          <h3>Tip 2: Optimize Images</h3>
          <p>Use appropriate image formats and sizes for better performance.</p>
          <img src="https://example.com/flutter-performance.png" alt="Flutter Performance">
          
          <h2>Advanced Techniques</h2>
          
          <h3>Tip 3: ListView.builder</h3>
          <p>Use ListView.builder for large lists to improve memory usage.</p>
          
          <h3>Tip 4: Avoid Expensive Operations</h3>
          <p>Move heavy computations away from the build method.</p>
          
          <h2>Conclusion</h2>
          <p>These tips will significantly improve your Flutter app performance.</p>
          <p>Questions? Email me at flutter.expert@example-blog.com</p>
        </article>
        
        <aside>
          <h3>Related Articles</h3>
          <a href="/flutter-widgets">Flutter Widget Guide</a>
          <a href="/dart-tips">Dart Programming Tips</a>
        </aside>
      </main>
    </body>
    </html>
    ''';

    // Test Case 4: Portfolio Website (Personal/Agency structure)
    const portfolioWebsiteHtml = '''
    <!DOCTYPE html>
    <html>
    <head>
      <title>John Designer - Creative Portfolio</title>
      <meta name="description" content="Creative designer specializing in web and mobile design">
      <meta name="author" content="John Designer">
    </head>
    <body>
      <header>
        <h1>John Designer</h1>
        <nav>
          <a href="#about">About</a>
          <a href="#portfolio">Portfolio</a>
          <a href="#contact">Contact</a>
        </nav>
      </header>
      
      <main>
        <section id="hero">
          <h1>Creative Designer & Developer</h1>
          <p>Crafting beautiful digital experiences</p>
        </section>
        
        <section id="about">
          <h2>About Me</h2>
          <p>I'm a passionate designer with 8+ years of experience.</p>
          
          <h3>Skills</h3>
          <ul>
            <li>UI/UX Design</li>
            <li>Web Development</li>
            <li>Mobile App Design</li>
            <li>Brand Identity</li>
          </ul>
        </section>
        
        <section id="portfolio">
          <h2>Featured Work</h2>
          
          <div class="project">
            <h3>E-commerce App Design</h3>
            <img src="https://example.com/project1.jpg" alt="E-commerce App">
            <p>Modern shopping app with intuitive user experience.</p>
          </div>
          
          <div class="project">
            <h3>Corporate Website</h3>
            <img src="https://example.com/project2.jpg" alt="Corporate Website">
            <p>Professional website for Fortune 500 company.</p>
          </div>
          
          <h3>Client Testimonials</h3>
          <blockquote>"John delivered exceptional work!" - CEO, TechCorp</blockquote>
          <blockquote>"Outstanding design skills" - Marketing Director</blockquote>
        </section>
        
        <section id="contact">
          <h2>Get In Touch</h2>
          <p>Ready to start your next project?</p>
          
          <h3>Contact Information</h3>
          <p>Email: john@example-portfolio.com</p>
          <p>Phone: +1-555-DESIGN-1 or (555) 337-4461</p>
          <p>LinkedIn: https://example.com/in/johndesigner</p>
          
          <h3>Office Location</h3>
          <p>123 Creative Street, Design City, DC 12345</p>
        </section>
      </main>
    </body>
    </html>
    ''';

    group('News Website Tests', () {
      late TestMobileScraper scraper;

      setUp(() {
        scraper = TestMobileScraper(
            'https://example-news.com/ai-healthcare', newsWebsiteHtml);
      });

      test('should extract all heading levels (H1, H2, H3)', () {
        final h1Tags = scraper.queryAll(tag: 'h1');
        final h2Tags = scraper.queryAll(tag: 'h2');
        final h3Tags = scraper.queryAll(tag: 'h3');

        print('\n📰 === NEWS WEBSITE - HEADING EXTRACTION ===');
        print('H1 tags (${h1Tags.length}): ${h1Tags.join(", ")}');
        print('H2 tags (${h2Tags.length}): ${h2Tags.join(", ")}');
        print('H3 tags (${h3Tags.length}): ${h3Tags.join(", ")}');

        expect(h1Tags.length, equals(2));
        expect(h2Tags.length, equals(2));
        expect(h3Tags.length, equals(3));
        expect(h3Tags, contains('Machine Learning Applications'));
        expect(h3Tags, contains('Patient Care Enhancement'));
      });

      test('should extract contact information using regex', () {
        final emails = scraper.queryWithRegex(
            pattern: r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})');
        final phones = scraper.queryWithRegex(
            pattern: r'(\+1-\d{3}-[A-Z]+-\d{3}|\(\d{3}\)\s?\d{3}-\d{4})');

        print('\n📞 === NEWS WEBSITE - CONTACT EXTRACTION ===');
        print('Emails found: ${emails.join(", ")}');
        print('Phones found: ${phones.join(", ")}');

        expect(emails.length, equals(2));
        expect(emails, contains('news@example-news.com'));
        expect(emails, contains('contact@example-news.com'));
        expect(phones.length, equals(1));
      });

      test('should perform smart content extraction', () {
        final smartContent = scraper.extractSmartContent();

        print('\n🧠 === NEWS WEBSITE - SMART EXTRACTION ===');
        print('Title: "${smartContent.title}"');
        print('Description: "${smartContent.description}"');
        print('Author: "${smartContent.author}"');
        print('Emails: ${smartContent.emails.length}');
        print('OpenGraph Title: "${smartContent.openGraph?.title}"');

        expect(smartContent.title, equals('Breaking News - Tech Innovation'));
        expect(smartContent.author, equals('John Reporter'));
        expect(smartContent.emails.length, greaterThanOrEqualTo(2));
        expect(smartContent.openGraph?.title,
            equals('Breaking News - Tech Innovation'));
      });
    });

    group('E-commerce Website Tests', () {
      late TestMobileScraper scraper;

      setUp(() {
        scraper = TestMobileScraper(
            'https://example-store.com/macbook-pro', ecommerceWebsiteHtml);
      });

      test('should extract product information and prices', () {
        final h1Tags = scraper.queryAll(tag: 'h1');
        final h2Tags = scraper.queryAll(tag: 'h2');
        final h3Tags = scraper.queryAll(tag: 'h3');
        final prices =
            scraper.queryWithRegex(pattern: r'\$([0-9,]+(?:\.[0-9]{2})?)');

        print('\n🛒 === E-COMMERCE WEBSITE - PRODUCT EXTRACTION ===');
        print('Product Title (H1): ${h1Tags.join(", ")}');
        print('Sections (H2): ${h2Tags.join(", ")}');
        print('Subsections (H3): ${h3Tags.join(", ")}');
        print('Prices found: ${prices.join(", ")}');

        expect(h1Tags, contains('MacBook Pro 16-inch'));
        expect(h2Tags, contains('Product Details'));
        expect(h3Tags, contains('Specifications'));
        expect(h3Tags, contains('Customer Reviews'));
        expect(prices.length, greaterThanOrEqualTo(1));
      });

      test('should extract customer reviews using regex', () {
        final reviews = scraper.queryWithRegex(
            pattern: r'"([^"]+)"\s*-\s*([A-Z][a-z]+\s+[A-Z][a-z]+)');
        final customerNames =
            scraper.queryWithRegex(pattern: r'-\s*([A-Z][a-z]+\s+[A-Z][a-z]+)');

        print('\n⭐ === E-COMMERCE WEBSITE - REVIEW EXTRACTION ===');
        print('Reviews found: ${reviews.length}');
        print('Customer names: ${customerNames.join(", ")}');

        expect(customerNames.length, equals(2));
        expect(customerNames, contains('Sarah Tech'));
        expect(customerNames, contains('Mike Developer'));
      });

      test('should extract product specifications', () {
        final specs = scraper.queryAll(tag: 'li');

        print('\n📋 === E-COMMERCE WEBSITE - SPECIFICATIONS ===');
        print('Specifications found: ${specs.join(", ")}');

        expect(specs.length, equals(4));
        expect(specs, contains('16-inch Retina Display'));
        expect(specs, contains('Apple M2 Pro Chip'));
      });
    });

    group('Blog Website Tests', () {
      late TestMobileScraper scraper;

      setUp(() {
        scraper = TestMobileScraper(
            'https://example-blog.com/performance-tips', blogWebsiteHtml);
      });

      test('should extract blog structure and content', () {
        final h1Tags = scraper.queryAll(tag: 'h1');
        final h2Tags = scraper.queryAll(tag: 'h2');
        final h3Tags = scraper.queryAll(tag: 'h3');

        print('\n📝 === BLOG WEBSITE - CONTENT STRUCTURE ===');
        print('Main Title (H1): ${h1Tags.join(", ")}');
        print('Sections (H2): ${h2Tags.join(", ")}');
        print('Tips (H3): ${h3Tags.join(", ")}');

        expect(h1Tags, contains('10 Flutter Tips for Better Performance'));
        expect(h2Tags, contains('Introduction'));
        expect(h2Tags, contains('Advanced Techniques'));
        expect(h3Tags, contains('Tip 1: Use const Constructors'));
        expect(h3Tags, contains('Tip 4: Avoid Expensive Operations'));
      });

      test('should extract author and publication date', () {
        final smartContent = scraper.extractSmartContent();
        final dates = scraper.queryWithRegex(pattern: r'(\d{4}-\d{2}-\d{2})');

        print('\n👤 === BLOG WEBSITE - AUTHOR & DATE ===');
        print('Author: "${smartContent.author}"');
        print('Publication Date: "${smartContent.publishDate}"');
        print('Dates found: ${dates.join(", ")}');

        expect(smartContent.author, equals('Flutter Expert'));
        expect(dates.length, greaterThanOrEqualTo(1));
      });

      test('should format blog content to markdown', () {
        final markdown = scraper.toMarkdown();
        final wordCount = scraper.getWordCount();
        final readingTime = scraper.estimateReadingTime();

        print('\n📄 === BLOG WEBSITE - CONTENT FORMATTING ===');
        print('Markdown length: ${markdown.length} characters');
        print('Word count: $wordCount words');
        print('Reading time: ${readingTime.inMinutes} minutes');
        print('Contains H2 headers: ${markdown.contains('## Introduction')}');
        print('Contains H3 headers: ${markdown.contains('### Tip 1')}');

        expect(wordCount, greaterThan(50));
        expect(readingTime.inMinutes, greaterThanOrEqualTo(1));
        expect(markdown, contains('# 10 Flutter Tips'));
      });
    });

    group('Portfolio Website Tests', () {
      late TestMobileScraper scraper;

      setUp(() {
        scraper = TestMobileScraper(
            'https://example-portfolio.com', portfolioWebsiteHtml);
      });

      test('should extract portfolio sections and projects', () {
        final h1Tags = scraper.queryAll(tag: 'h1');
        final h2Tags = scraper.queryAll(tag: 'h2');
        final h3Tags = scraper.queryAll(tag: 'h3');

        print('\n🎨 === PORTFOLIO WEBSITE - STRUCTURE ===');
        print('Main Titles (H1): ${h1Tags.join(", ")}');
        print('Sections (H2): ${h2Tags.join(", ")}');
        print('Subsections (H3): ${h3Tags.join(", ")}');

        expect(h1Tags, contains('John Designer'));
        expect(h2Tags, contains('About Me'));
        expect(h2Tags, contains('Featured Work'));
        expect(h3Tags, contains('Skills'));
        expect(h3Tags, contains('E-commerce App Design'));
      });

      test('should extract contact information and links', () {
        final emails = scraper.queryWithRegex(
            pattern: r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})');
        final phones = scraper.queryWithRegex(
            pattern: r'(\+1-\d{3}-[A-Z]+-\d|\(\d{3}\)\s?\d{3}-\d{4})');
        final linkedinUrls =
            scraper.queryWithRegex(pattern: r'(https://example.com/[^\s]+)');

        print('\n📞 === PORTFOLIO WEBSITE - CONTACT INFO ===');
        print('Emails: ${emails.join(", ")}');
        print('Phones: ${phones.join(", ")}');
        print('LinkedIn: ${linkedinUrls.join(", ")}');

        expect(emails, contains('john@example-portfolio.com'));
        expect(linkedinUrls, contains('https://example.com/in/johndesigner'));
      });

      test('should extract testimonials using blockquote', () {
        final testimonials = scraper.queryAll(tag: 'blockquote');

        print('\n💬 === PORTFOLIO WEBSITE - TESTIMONIALS ===');
        print('Testimonials found: ${testimonials.join(" | ")}');

        expect(testimonials.length, equals(2));
        expect(
            testimonials.first, contains('John delivered exceptional work!'));
      });
    });

    group('Cross-Website Functionality Comparison', () {
      test('should demonstrate consistent smart extraction across all websites',
          () {
        final websites = [
          {
            'name': 'News',
            'scraper':
                TestMobileScraper('https://example-news.com', newsWebsiteHtml)
          },
          {
            'name': 'E-commerce',
            'scraper': TestMobileScraper(
                'https://example-store.com', ecommerceWebsiteHtml)
          },
          {
            'name': 'Blog',
            'scraper':
                TestMobileScraper('https://example-blog.com', blogWebsiteHtml)
          },
          {
            'name': 'Portfolio',
            'scraper': TestMobileScraper(
                'https://example-portfolio.com', portfolioWebsiteHtml)
          },
        ];

        print('\n🔄 === CROSS-WEBSITE FUNCTIONALITY COMPARISON ===');

        for (final website in websites) {
          final scraper = website['scraper'] as TestMobileScraper;
          final smartContent = scraper.extractSmartContent();
          final h1Count = scraper.queryAll(tag: 'h1').length;
          final h2Count = scraper.queryAll(tag: 'h2').length;
          final h3Count = scraper.queryAll(tag: 'h3').length;
          final emailCount = smartContent.emails.length;
          final wordCount = scraper.getWordCount();

          print('\n${website['name']} Website:');
          print('  Title: "${smartContent.title}"');
          print('  H1: $h1Count, H2: $h2Count, H3: $h3Count');
          print('  Emails: $emailCount');
          print('  Word Count: $wordCount');
          print('  Has Author: ${smartContent.author != null}');
          print('  Has OpenGraph: ${smartContent.openGraph != null}');

          // Verify each website has consistent extraction
          expect(smartContent.title, isNotNull);
          expect(h1Count, greaterThan(0));
          expect(wordCount, greaterThan(0));
        }
      });

      test('should demonstrate consistent content formatting across websites',
          () {
        final websites = [
          {
            'name': 'News',
            'scraper':
                TestMobileScraper('https://example-news.com', newsWebsiteHtml)
          },
          {
            'name': 'Blog',
            'scraper':
                TestMobileScraper('https://example-blog.com', blogWebsiteHtml)
          },
        ];

        print('\n📝 === CONTENT FORMATTING CONSISTENCY ===');

        for (final website in websites) {
          final scraper = website['scraper'] as TestMobileScraper;
          final markdown = scraper.toMarkdown();
          final plainText = scraper.toPlainText();
          final readingTime = scraper.estimateReadingTime();

          print('\n${website['name']} Website Formatting:');
          print('  Markdown length: ${markdown.length}');
          print('  Plain text length: ${plainText.length}');
          print('  Reading time: ${readingTime.inMinutes} min');
          print('  Has H1 in markdown: ${markdown.contains('# ')}');
          print('  Has H2 in markdown: ${markdown.contains('## ')}');

          expect(markdown.length, greaterThan(0));
          expect(plainText.length, greaterThan(0));
          expect(readingTime.inSeconds, greaterThan(0));
        }
      });
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
