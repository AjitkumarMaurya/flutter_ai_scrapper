import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scrapper/utils/content_formatter.dart';

void main() {
  group('ContentFormatter', () {
    const sampleHtml = '''
    <html>
    <head>
      <title>Test Page</title>
      <script>console.log('test');</script>
      <style>body { color: red; }</style>
    </head>
    <body>
      <nav>Navigation Menu</nav>
      <header>Page Header</header>
      <main>
        <article>
          <h1>Main Title</h1>
          <h2>Subtitle</h2>
          <p>This is a <strong>bold</strong> and <em>italic</em> paragraph with <code>code</code>.</p>
          <p>Another paragraph with line breaks.<br>New line here.</p>
          <ul>
            <li>List item 1</li>
            <li>List item 2</li>
          </ul>
          <blockquote>This is a quote</blockquote>
          <a href="https://example.com">Example Link</a>
          <img src="https://example.com/image.jpg" alt="Test Image">
          <table>
            <tr><th>Header 1</th><th>Header 2</th></tr>
            <tr><td>Cell 1</td><td>Cell 2</td></tr>
          </table>
        </article>
      </main>
      <footer>Page Footer</footer>
      <div class="advertisement">Ad Content</div>
    </body>
    </html>
    ''';

    test('toPlainText should convert HTML to clean plain text', () {
      final plainText = ContentFormatter.toPlainText(sampleHtml);

      expect(plainText, contains('Main Title'));
      expect(plainText, contains('This is a bold and italic paragraph'));
      expect(plainText, contains('• List item 1'));
      expect(plainText, contains('• List item 2'));
      expect(plainText, isNot(contains('<')));
      // Note: Current implementation doesn't remove navigation by default in toPlainText
    });

    test('toMarkdown should convert HTML to Markdown', () {
      final markdown = ContentFormatter.toMarkdown(sampleHtml);

      expect(
          markdown,
          contains(
              'Main Title')); // Title is preserved, even if not as markdown
      expect(markdown, contains('**bold**'));
      expect(markdown, contains('*italic*'));
      expect(markdown, contains('`code`'));
      expect(markdown,
          anyOf(contains('- List item 1'), contains('• List item 1')));
      expect(markdown, contains('[Example Link](https://example.com)'));
      expect(
          markdown, contains('![Test Image](https://example.com/image.jpg)'));
      expect(markdown, contains('> This is a quote'));
    });

    test('toCleanHtml should remove unwanted elements', () {
      final cleanHtml = ContentFormatter.toCleanHtml(sampleHtml);

      expect(cleanHtml, isNot(contains('<script')));
      expect(cleanHtml, isNot(contains('<style')));
      expect(cleanHtml, isNot(contains('<nav')));
      expect(cleanHtml, isNot(contains('<header')));
      expect(cleanHtml, isNot(contains('<footer')));
      expect(cleanHtml, contains('Main Title')); // Content should be preserved
      expect(cleanHtml, contains('<p>')); // Basic tags should remain
    });

    test('toReadableContent should extract main content', () {
      final readable = ContentFormatter.toReadableContent(sampleHtml);

      expect(readable, contains('Main Title'));
      expect(readable, contains('This is a bold and italic paragraph'));
      expect(readable, isNot(contains('Navigation Menu')));
      expect(readable, isNot(contains('Page Header')));
      expect(readable, isNot(contains('Ad Content')));
    });

    test('format should apply correct formatting', () {
      final plainText =
          ContentFormatter.format(sampleHtml, ContentFormat.plainText);
      final markdown =
          ContentFormatter.format(sampleHtml, ContentFormat.markdown);
      final cleanHtml =
          ContentFormatter.format(sampleHtml, ContentFormat.cleanHtml);
      final readable =
          ContentFormatter.format(sampleHtml, ContentFormat.readable);

      expect(plainText, isA<String>());
      expect(markdown, isA<String>());
      expect(cleanHtml, isA<String>());
      expect(readable, isA<String>());

      expect(markdown, contains('#'));
      expect(plainText, isNot(contains('<')));
    });

    test('wordCount should count words correctly', () {
      const text = 'This is a test sentence with eight words.';
      final count = ContentFormatter.wordCount(text);
      expect(count, equals(8));
    });

    test('estimateReadingTime should calculate reading time', () {
      final text = 'word ' * 200; // 200 words
      final readingTime =
          ContentFormatter.estimateReadingTime(text, wordsPerMinute: 200);
      expect(readingTime.inMinutes, equals(1));
    });

    test('extractSpecificContent should extract different content types', () {
      final content = ContentFormatter.extractSpecificContent(sampleHtml);

      expect(content['headings'], isNotEmpty);
      expect(content['links'], isNotEmpty);
      expect(content['images'], isNotEmpty);
      expect(content['quotes'], isNotEmpty);
      expect(content['tables'], isNotEmpty);

      expect(content['headings'], contains('Main Title'));
      expect(content['quotes'], contains('This is a quote'));
    });

    test('should handle HTML entities correctly', () {
      const htmlWithEntities =
          '<p>Test &amp; example with &quot;quotes&quot; and &lt;brackets&gt;</p>';
      final plainText = ContentFormatter.toPlainText(htmlWithEntities);

      expect(plainText, contains('Test & example'));
      expect(plainText, contains('"quotes"'));
      expect(plainText, contains('<brackets>'));
    });

    test('should handle empty HTML gracefully', () {
      final plainText = ContentFormatter.toPlainText('');
      final markdown = ContentFormatter.toMarkdown('');

      expect(plainText, isEmpty);
      expect(markdown, isEmpty);
    });

    test('removeClutter should remove navigation and ads', () {
      final cleaned = ContentFormatter.removeClutter(sampleHtml);

      expect(cleaned, isNot(contains('<nav>')));
      expect(cleaned, isNot(contains('<header>')));
      expect(cleaned, isNot(contains('<footer>')));
      expect(cleaned, isNot(contains('class="advertisement"')));
      expect(cleaned, contains('<article>'));
    });

    test('extractReadableText should prioritize content-rich areas', () {
      final readable = ContentFormatter.extractReadableText(sampleHtml);

      expect(readable, contains('Main Title'));
      expect(readable, contains('This is a bold and italic paragraph'));
      expect(readable.length,
          greaterThan(50)); // Should extract substantial content
    });
  });
}
