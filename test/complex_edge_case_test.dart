import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scrapper/mobile_scraper.dart';

void main() {
  group('Complex Edge Case Tests with Advanced Regex', () {
    // Complex website with nested structures, malformed HTML, and edge cases
    const complexWebsiteHtml = '''
    <!DOCTYPE html>
    <html lang="en-US">
    <head>
      <title>🚀 Advanced Tech Solutions | AI & Machine Learning Experts 2024</title>
      <meta name="description" content="Leading AI/ML company specializing in blockchain, IoT, and quantum computing solutions. Founded in 2019.">
      <meta name="author" content="Dr. Sarah Johnson-Smith, PhD">
      <meta name="keywords" content="AI, ML, blockchain, IoT, quantum, tech, innovation">
      <meta property="og:title" content="Advanced Tech Solutions - Innovation Leaders">
      <meta property="og:description" content="Cutting-edge technology solutions for enterprise clients">
      <meta property="og:image" content="https://example.com/og-image-2024.jpg">
      <meta property="og:url" content="https://advancedtech.com">
      <meta property="article:published_time" content="2024-01-15T14:30:00Z">
      <meta property="article:modified_time" content="2024-01-20T09:15:30Z">
      <meta name="twitter:card" content="summary_large_image">
      <meta name="twitter:title" content="Advanced Tech Solutions | AI Experts">
    </head>
    <body>
      <header class="main-header" id="top-header">
        <h1 class="company-title primary-heading">🏢 Advanced Tech Solutions Inc.</h1>
        <nav aria-label="Main navigation">
          <ul>
            <li><a href="/ai-services">AI Services</a></li>
            <li><a href="/blockchain">Blockchain</a></li>
            <li><a href="/iot-solutions">IoT Solutions</a></li>
            <li><a href="/quantum-computing">Quantum Computing</a></li>
          </ul>
        </nav>
      </header>
      
      <main role="main" class="content-wrapper">
        <section class="hero-section" data-section="hero">
          <h1 class="hero-title">Revolutionizing Technology Since 2019</h1>
          <p class="hero-subtitle">Transforming businesses with AI, ML, and emerging technologies</p>
          <div class="stats-container">
            <div class="stat-item">
              <span class="stat-number">500+</span>
              <span class="stat-label">Projects Completed</span>
            </div>
            <div class="stat-item">
              <span class="stat-number">\$50M+</span>
              <span class="stat-label">Revenue Generated</span>
            </div>
            <div class="stat-item">
              <span class="stat-number">99.9%</span>
              <span class="stat-label">Uptime Guarantee</span>
            </div>
          </div>
        </section>
        
        <article class="main-content" id="services">
          <h2 class="section-heading">🤖 Our AI & Machine Learning Services</h2>
          <p class="intro-text">We provide cutting-edge AI solutions with <strong>95% accuracy</strong> and <em>real-time processing</em>.</p>
          
          <div class="service-grid">
            <div class="service-card" data-service="nlp">
              <h3 class="service-title">Natural Language Processing</h3>
              <p class="service-description">Advanced NLP models with 98.5% accuracy for sentiment analysis.</p>
              <ul class="feature-list">
                <li>Multi-language support (50+ languages)</li>
                <li>Real-time text analysis</li>
                <li>Custom model training</li>
                <li>API integration ready</li>
              </ul>
              <div class="pricing">
                <span class="price-label">Starting at:</span>
                <span class="price-amount">\$2,999/month</span>
                <span class="price-note">(was \$4,999/month)</span>
              </div>
            </div>
            
            <div class="service-card" data-service="computer-vision">
              <h3 class="service-title">Computer Vision Solutions</h3>
              <p class="service-description">State-of-the-art image recognition with 99.2% precision.</p>
              <ul class="feature-list">
                <li>Object detection & classification</li>
                <li>Facial recognition systems</li>
                <li>Medical image analysis</li>
                <li>Quality control automation</li>
              </ul>
              <div class="pricing">
                <span class="price-label">Enterprise pricing:</span>
                <span class="price-amount">\$15,000 - \$50,000</span>
                <span class="price-note">Custom quotes available</span>
              </div>
            </div>
          </div>
          
          <h2 class="section-heading">🔗 Blockchain & Cryptocurrency Solutions</h2>
          <div class="blockchain-services">
            <h3 class="subsection-title">Smart Contract Development</h3>
            <p>Secure smart contracts on Ethereum, Polygon, and Binance Smart Chain.</p>
            <div class="crypto-prices">
              <span class="crypto-item">ETH: \$2,345.67</span>
              <span class="crypto-item">BTC: \$43,210.89</span>
              <span class="crypto-item">ADA: \$0.4567</span>
            </div>
            
            <h3 class="subsection-title">DeFi Protocol Development</h3>
            <p>Custom DeFi solutions with TVL of \$100M+ managed.</p>
          </div>
          
          <h2 class="section-heading">📊 Client Success Stories</h2>
          <div class="testimonials">
            <blockquote class="testimonial" data-client="fortune500">
              <p>"Advanced Tech Solutions increased our efficiency by 300% and saved us \$2.5 million annually!"</p>
              <cite class="testimonial-author">— John Smith, CTO at TechCorp Inc.</cite>
              <div class="testimonial-meta">
                <span class="company">TechCorp Inc.</span>
                <span class="industry">Fortune 500 Technology</span>
                <span class="project-value">\$5.2M project value</span>
              </div>
            </blockquote>
            
            <blockquote class="testimonial" data-client="healthcare">
              <p>"Their AI diagnostic tool achieved 99.7% accuracy in clinical trials!"</p>
              <cite class="testimonial-author">— Dr. Emily Chen, MD, PhD</cite>
              <div class="testimonial-meta">
                <span class="company">MedTech Innovations</span>
                <span class="industry">Healthcare & Biotechnology</span>
                <span class="project-value">\$12.8M research grant</span>
              </div>
            </blockquote>
            
            <blockquote class="testimonial" data-client="fintech">
              <p>"ROI of 450% within 18 months of implementation!"</p>
              <cite class="testimonial-author">— Michael Rodriguez, CFO</cite>
              <div class="testimonial-meta">
                <span class="company">FinanceFlow Solutions</span>
                <span class="industry">Financial Technology</span>
                <span class="project-value">\$8.7M implementation</span>
              </div>
            </blockquote>
          </div>
          
          <h2 class="section-heading">👥 Our Expert Team</h2>
          <div class="team-grid">
            <div class="team-member" data-role="ceo">
              <h3 class="member-name">Dr. Sarah Johnson-Smith</h3>
              <p class="member-title">CEO & Chief AI Scientist</p>
              <p class="member-credentials">PhD in Computer Science (MIT), 15+ years experience</p>
              <div class="member-contact">
                <span class="email">sarah.johnson@advancedtech.com</span>
                <span class="phone">+1-555-TECH-CEO (555-832-4236)</span>
                <span class="linkedin">example.com/in/sarah-johnson-ai</span>
              </div>
            </div>
            
            <div class="team-member" data-role="cto">
              <h3 class="member-name">Alex Chen-Williams</h3>
              <p class="member-title">CTO & Blockchain Architect</p>
              <p class="member-credentials">MS in Cryptography (Stanford), Former Google Senior Engineer</p>
              <div class="member-contact">
                <span class="email">alex.chen@advancedtech.com</span>
                <span class="phone">+1-555-BLOCK-CHAIN (555-256-2524)</span>
                <span class="linkedin">example.com/in/alex-chen-blockchain</span>
              </div>
            </div>
          </div>
          
          <h2 class="section-heading">📞 Contact & Pricing Information</h2>
          <div class="contact-section">
            <h3 class="contact-heading">Get in Touch</h3>
            <div class="contact-grid">
              <div class="contact-method">
                <h4>Sales Inquiries</h4>
                <p>Email: sales@advancedtech.com</p>
                <p>Phone: +1-800-GET-TECH (800-438-8324)</p>
                <p>WhatsApp: +1-555-WHATSAPP</p>
              </div>
              
              <div class="contact-method">
                <h4>Technical Support</h4>
                <p>Email: support@advancedtech.com</p>
                <p>Phone: +1-888-TECH-HELP (888-832-4435)</p>
                <p>Emergency: +1-555-URGENT-99</p>
              </div>
              
              <div class="contact-method">
                <h4>Partnership Opportunities</h4>
                <p>Email: partnerships@advancedtech.com</p>
                <p>Phone: (415) 123-4567</p>
                <p>Fax: (415) 123-4568</p>
              </div>
            </div>
            
            <h3 class="pricing-heading">💰 Pricing Tiers</h3>
            <div class="pricing-table">
              <div class="pricing-tier" data-tier="startup">
                <h4>Startup Package</h4>
                <div class="price">\$5,000 - \$25,000</div>
                <p>Perfect for early-stage companies</p>
              </div>
              
              <div class="pricing-tier" data-tier="enterprise">
                <h4>Enterprise Solution</h4>
                <div class="price">\$100,000 - \$1,000,000+</div>
                <p>Comprehensive AI transformation</p>
              </div>
            </div>
          </div>
        </article>
        
        <!-- Malformed HTML section to test error handling -->
        <section class="malformed-section">
          <h2>Edge Case Testing</h2>
          <p>This section has <strong>unclosed tags and <em>nested issues
          <div class="broken-div">
            <h3>Broken Structure</h3>
            <p>Missing closing tags</p>
          <!-- Missing closing div -->
          
          <h2>Special Characters & Encoding</h2>
          <p>Testing: &amp; &lt; &gt; &quot; &#39; &nbsp; &copy; &reg; &trade;</p>
          <p>Unicode: 🚀 🤖 💰 📊 🔗 ⚡ 🌟 💡</p>
          <p>Math symbols: ∑ ∆ π ∞ ≈ ≠ ≤ ≥</p>
        </section>
      </main>
      
      <footer class="site-footer" role="contentinfo">
        <div class="footer-content">
          <h3>Advanced Tech Solutions Inc.</h3>
          <p>© 2024 Advanced Tech Solutions Inc. All rights reserved.</p>
          <p>Headquarters: 123 Innovation Drive, Silicon Valley, CA 94025</p>
          <p>Global offices in: New York, London, Tokyo, Singapore</p>
          <div class="footer-links">
            <a href="/privacy">Privacy Policy</a>
            <a href="/terms">Terms of Service</a>
            <a href="/careers">Careers</a>
            <a href="/investors">Investor Relations</a>
          </div>
          <div class="social-media">
            <a href="https://example.com/advancedtech">Twitter</a>
            <a href="https://example.com/company/advanced-tech-solutions">LinkedIn</a>
            <a href="https://example.com/advanced-tech-solutions">GitHub</a>
          </div>
        </div>
      </footer>
    </body>
    </html>
    ''';

    group('Advanced Regex Pattern Tests', () {
      late TestMobileScraper scraper;

      setUp(() {
        scraper =
            TestMobileScraper('https://advancedtech.com', complexWebsiteHtml);
      });

      test('should extract complex pricing information using advanced regex',
          () {
        // Complex regex for various price formats
        final pricePatterns = [
          r'\$([0-9,]+(?:\.[0-9]{2})?)\s*(?:/month|/year)?', // Standard prices (fixed escaping)
          r'\$([0-9,]+(?:\.[0-9]{2})?)\s*-\s*\$([0-9,]+(?:\.[0-9]{2})?)', // Price ranges (fixed escaping)
          r'([0-9,]+(?:\.[0-9]{2})?)\s*million', // Million dollar amounts
          r'ROI\s+of\s+([0-9]+)%', // ROI percentages
          r'([0-9]+(?:\.[0-9]+)?)%\s+accuracy', // Accuracy percentages
        ];

        print('\n💰 === ADVANCED PRICING EXTRACTION ===');

        for (int i = 0; i < pricePatterns.length; i++) {
          final matches = scraper.queryWithRegex(pattern: pricePatterns[i]);
          print('Pattern ${i + 1} matches: ${matches.join(", ")}');
          expect(matches.length, greaterThan(0),
              reason: 'Pattern ${i + 1} should find matches');
        }

        // Test complex price range extraction
        final priceRanges = scraper.queryWithRegex(
            pattern:
                r'\$([0-9,]+(?:\.[0-9]{2})?)\s*-\s*\$([0-9,]+(?:\.[0-9]{2})?)',
            group: 0);
        print('Price ranges found: ${priceRanges.join(", ")}');
        expect(priceRanges.length, greaterThanOrEqualTo(2));
      });

      test('should extract complex contact information with multiple formats',
          () {
        // Advanced phone number patterns
        final phonePatterns = [
          r'\+1-([0-9]{3})-([A-Z-]+)', // Vanity numbers like +1-555-TECH-CEO
          r'\+1-([0-9]{3})-([0-9]{3})-([0-9]{4})', // Standard format
          r'\(([0-9]{3})\)\s*([0-9]{3})-([0-9]{4})', // (415) 123-4567 format
          r'([0-9]{3})-([0-9]{3})-([0-9]{4})', // 800-438-8324 format
        ];

        print('\n📞 === COMPLEX CONTACT EXTRACTION ===');

        for (int i = 0; i < phonePatterns.length; i++) {
          final phones =
              scraper.queryWithRegex(pattern: phonePatterns[i], group: 0);
          print('Phone pattern ${i + 1}: ${phones.join(", ")}');
        }

        // Extract email addresses with complex domains
        final emails = scraper.queryWithRegex(
            pattern: r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})');
        print('Emails found: ${emails.join(", ")}');
        expect(emails.length, greaterThanOrEqualTo(5));

        // Extract LinkedIn profiles
        final linkedinProfiles = scraper.queryWithRegex(
            pattern: r'linkedin\.com/(?:in|company)/([a-zA-Z0-9-]+)');
        print('LinkedIn profiles: ${linkedinProfiles.join(", ")}');
        expect(linkedinProfiles.length, greaterThanOrEqualTo(3));
      });

      test('should extract cryptocurrency and financial data', () {
        // Crypto price pattern
        final cryptoPrices = scraper.queryWithRegex(
            pattern: r'([A-Z]{3,4}):\s*\$([0-9,]+(?:\.[0-9]{2,8})?)');
        print('\n💎 === CRYPTOCURRENCY EXTRACTION ===');
        print('Crypto prices: ${cryptoPrices.join(", ")}');
        expect(cryptoPrices.length, greaterThanOrEqualTo(3));

        // Financial metrics
        final financialMetrics = scraper.queryWithRegex(
            pattern:
                r'(TVL|ROI|revenue)\s+of\s+\$?([0-9,]+(?:\.[0-9]+)?[MBK]?)');
        print('Financial metrics: ${financialMetrics.join(", ")}');

        // Project values
        final projectValues = scraper.queryWithRegex(
            pattern:
                r'\$([0-9,]+(?:\.[0-9]+)?[MBK]?)\s+(?:project|implementation|grant)');
        print('Project values: ${projectValues.join(", ")}');
        expect(projectValues.length, greaterThanOrEqualTo(3));
      });

      test('should extract team member information with complex patterns', () {
        // Extract names with titles and credentials
        final teamMembers = scraper.queryWithRegex(
            pattern: r'(Dr\.|PhD|MS|MD)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z-]+)*)');
        print('\n👥 === TEAM MEMBER EXTRACTION ===');
        print('Team members with credentials: ${teamMembers.join(", ")}');

        // Extract job titles
        final jobTitles = scraper.queryWithRegex(
            pattern: r'(CEO|CTO|CFO|Chief\s+[A-Z][a-z]+\s+[A-Z][a-z]+)');
        print('Job titles: ${jobTitles.join(", ")}');
        expect(jobTitles.length, greaterThanOrEqualTo(2));

        // Extract educational background
        final education = scraper.queryWithRegex(
            pattern:
                r'(PhD|MS|MD)\s+in\s+([A-Z][a-z\s&]+)\s+\(([A-Z][a-z]+)\)');
        print('Education background: ${education.join(", ")}');
        expect(education.length, greaterThanOrEqualTo(1));
      });

      test('should handle malformed HTML and extract content anyway', () {
        // Test extraction from malformed section
        final malformedContent = scraper.queryAll(tag: 'p');
        print('\n⚠️ === MALFORMED HTML HANDLING ===');
        print(
            'Paragraphs extracted despite malformed HTML: ${malformedContent.length}');
        expect(malformedContent.length, greaterThan(10));

        // Test special character handling
        final specialChars = scraper.queryWithRegex(
            pattern: r'(&[a-z]+;|&#[0-9]+;|[🚀🤖💰📊🔗⚡🌟💡∑∆π∞≈≠≤≥])');
        print('Special characters found: ${specialChars.join(", ")}');
        expect(specialChars.length, greaterThan(5));
      });
    });

    group('Automated Title Extraction Methods', () {
      late TestMobileScraper scraper;

      setUp(() {
        scraper =
            TestMobileScraper('https://advancedtech.com', complexWebsiteHtml);
      });

      test('should extract titles using multiple automated methods', () {
        print('\n🎯 === AUTOMATED TITLE EXTRACTION METHODS ===');

        // Method 1: Smart Content Extraction
        final smartContent = scraper.extractSmartContent();
        print('Smart extraction title: "${smartContent.title}"');
        expect(smartContent.title, isNotNull);

        // Method 2: OpenGraph title
        print('OpenGraph title: "${smartContent.openGraph?.title}"');
        expect(smartContent.openGraph?.title, isNotNull);

        // Method 3: All H1 tags
        final h1Tags = scraper.queryAll(tag: 'h1');
        print('H1 tags found: ${h1Tags.join(" | ")}');
        expect(h1Tags.length, greaterThanOrEqualTo(2));

        // Method 4: Title tag extraction
        final titleTags = scraper.queryAll(tag: 'title');
        print(
            'Title tag: "${titleTags.isNotEmpty ? titleTags.first : "Not found"}"');
        expect(titleTags.length, equals(1));

        // Method 5: Meta title extraction
        final metaTitles = scraper.queryWithRegex(
            pattern:
                r'<meta[^>]*property=[\x22\x27]og:title[\x22\x27][^>]*content=[\x22\x27]([^\x22\x27]*)[\x22\x27]');
        print('Meta OG titles: ${metaTitles.join(", ")}');

        // Method 6: Twitter card title
        final twitterTitles = scraper.queryWithRegex(
            pattern:
                r'<meta[^>]*name=[\x22\x27]twitter:title[\x22\x27][^>]*content=[\x22\x27]([^\x22\x27]*)[\x22\x27]');
        print('Twitter card titles: ${twitterTitles.join(", ")}');

        // Verify all methods found titles
        expect(smartContent.title, contains('Tech'));
        expect(h1Tags.first, contains('Advanced Tech'));
      });

      test('should extract complex heading hierarchy', () {
        final h1Tags = scraper.queryAll(tag: 'h1');
        final h2Tags = scraper.queryAll(tag: 'h2');
        final h3Tags = scraper.queryAll(tag: 'h3');
        final h4Tags = scraper.queryAll(tag: 'h4');

        print('\n📋 === HEADING HIERARCHY ANALYSIS ===');
        print('H1 tags (${h1Tags.length}): ${h1Tags.join(" | ")}');
        print('H2 tags (${h2Tags.length}): ${h2Tags.join(" | ")}');
        print('H3 tags (${h3Tags.length}): ${h3Tags.join(" | ")}');
        print('H4 tags (${h4Tags.length}): ${h4Tags.join(" | ")}');

        // Verify complex hierarchy
        expect(h1Tags.length, greaterThanOrEqualTo(2));
        expect(h2Tags.length, greaterThanOrEqualTo(4));
        expect(h3Tags.length, greaterThanOrEqualTo(6));
        expect(h4Tags.length, greaterThanOrEqualTo(2));

        // Test emoji handling in headings
        final emojiHeadings = h2Tags
            .where((heading) =>
                heading.contains('🤖') ||
                heading.contains('🔗') ||
                heading.contains('📊'))
            .toList();
        print('Headings with emojis: ${emojiHeadings.join(" | ")}');
        expect(emojiHeadings.length, greaterThanOrEqualTo(2));
      });
    });

    group('Error Generation and Edge Case Tests', () {
      test('should handle extremely long regex patterns without crashing', () {
        final scraper =
            TestMobileScraper('https://test.com', complexWebsiteHtml);

        // Extremely complex regex that might cause performance issues
        final complexPattern =
            r'(?:(?:[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})|(?:\+1-[0-9]{3}-[A-Z-]+)|(?:\$[0-9,]+(?:\.[0-9]{2})?)|(?:[0-9]+(?:\.[0-9]+)?%)|(?:CEO|CTO|CFO)|(?:PhD|MS|MD)|(?:🚀|🤖|💰|📊|🔗))';

        print('\n🔥 === STRESS TEST WITH COMPLEX REGEX ===');

        expect(() {
          final results = scraper.queryWithRegex(pattern: complexPattern);
          print('Complex pattern matches: ${results.length}');
          expect(results.length, greaterThan(0));
        }, returnsNormally);
      });

      test('should handle invalid regex patterns gracefully', () {
        final scraper =
            TestMobileScraper('https://test.com', complexWebsiteHtml);

        print('\n❌ === INVALID REGEX HANDLING ===');

        // Test with invalid regex patterns that should cause errors
        final invalidPatterns = [
          r'[unclosed bracket',
          r'*invalid quantifier',
          r'(?invalid group',
          r'\k<invalid_reference>',
        ];

        for (final pattern in invalidPatterns) {
          expect(() {
            scraper.queryWithRegex(pattern: pattern);
          }, throwsA(isA<Exception>()));
          print('✓ Invalid pattern "$pattern" properly threw exception');
        }
      });

      test('should handle empty and null content gracefully', () {
        print('\n🚫 === EMPTY CONTENT HANDLING ===');

        // Test with empty HTML
        final emptyScraper = TestMobileScraper('https://empty.com', '');
        expect(() {
          emptyScraper.queryAll(tag: 'h1');
        }, throwsA(isA<ScraperNotInitializedException>()));

        // Test with minimal HTML
        final minimalScraper = TestMobileScraper(
            'https://minimal.com', '<html><body></body></html>');
        final results = minimalScraper.queryAll(tag: 'h1');
        expect(results, isEmpty);
        print('✓ Empty results handled gracefully');
      });

      test('should handle extremely nested HTML structures', () {
        const deeplyNestedHtml = '''
        <html><body>
        <div><div><div><div><div><div><div><div><div><div>
        <h1>Deeply Nested Title</h1>
        <p>This is <strong>very <em>deeply <span>nested <a href="#">content</a></span></em></strong></p>
        </div></div></div></div></div></div></div></div></div></div>
        </body></html>
        ''';

        final nestedScraper =
            TestMobileScraper('https://nested.com', deeplyNestedHtml);

        print('\n🏗️ === DEEPLY NESTED STRUCTURE TEST ===');

        final h1Results = nestedScraper.queryAll(tag: 'h1');
        final pResults = nestedScraper.queryAll(tag: 'p');

        print('H1 from nested structure: ${h1Results.join(", ")}');
        print('P from nested structure: ${pResults.join(", ")}');

        expect(h1Results.length, equals(1));
        expect(h1Results.first, equals('Deeply Nested Title'));
        expect(pResults.length, equals(1));
      });

      test(
          'should extract content with maximum complexity and verify consistency',
          () {
        final scraper =
            TestMobileScraper('https://complex.com', complexWebsiteHtml);

        print('\n🎯 === MAXIMUM COMPLEXITY TEST ===');

        // Run all extraction methods simultaneously
        final smartContent = scraper.extractSmartContent();
        final allH1 = scraper.queryAll(tag: 'h1');
        final allH2 = scraper.queryAll(tag: 'h2');
        final allH3 = scraper.queryAll(tag: 'h3');
        final allEmails = scraper.queryWithRegex(
            pattern: r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})');
        final allPrices =
            scraper.queryWithRegex(pattern: r'\$([0-9,]+(?:\.[0-9]{2})?)');
        final markdown = scraper.toMarkdown();
        final plainText = scraper.toPlainText();
        final wordCount = scraper.getWordCount();
        final readingTime = scraper.estimateReadingTime();

        print('📊 COMPREHENSIVE EXTRACTION RESULTS:');
        print('  Smart title: "${smartContent.title}"');
        print('  H1 count: ${allH1.length}');
        print('  H2 count: ${allH2.length}');
        print('  H3 count: ${allH3.length}');
        print('  Emails found: ${allEmails.length}');
        print('  Prices found: ${allPrices.length}');
        print('  Word count: $wordCount');
        print('  Reading time: ${readingTime.inMinutes} minutes');
        print('  Markdown length: ${markdown.length} chars');
        print('  Plain text length: ${plainText.length} chars');
        print('  Author: "${smartContent.author}"');
        print('  OpenGraph data: ${smartContent.openGraph != null}');

        // Verify all extractions are consistent and working
        expect(smartContent.title, isNotNull);
        expect(allH1.length, greaterThanOrEqualTo(2));
        expect(allH2.length, greaterThanOrEqualTo(4));
        expect(allH3.length, greaterThanOrEqualTo(6));
        expect(allEmails.length, greaterThanOrEqualTo(5));
        expect(allPrices.length, greaterThanOrEqualTo(3));
        expect(wordCount, greaterThan(200));
        expect(readingTime.inMinutes, greaterThanOrEqualTo(1));
        expect(markdown.length, greaterThan(500));
        expect(plainText.length, greaterThan(1000));
        expect(smartContent.author, equals('Dr. Sarah Johnson-Smith, PhD'));
        expect(smartContent.openGraph, isNotNull);

        print('\n✅ ALL COMPLEX EXTRACTIONS SUCCESSFUL!');
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
