import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

const _article = '''
<!DOCTYPE html>
<html>
<head>
  <title>Fallback Title</title>
  <link rel="canonical" href="/canonical-path">
  <meta name="description" content="Meta description text">
  <meta name="author" content="Jane Writer">
  <meta property="og:title" content="OpenGraph Title">
  <meta property="og:description" content="OpenGraph description">
  <meta property="og:image" content="/og-image.png">
  <meta property="og:site_name" content="Example Site">
  <meta property="article:published_time" content="2024-03-15T10:00:00Z">
</head>
<body>
  <h1>Document Heading</h1>
  <h2>Section One</h2>
  <h3>Detail</h3>
  <article><p>Body paragraph with enough words in it to look like real prose.</p></article>
  <img src="photo.jpg" alt="Photo">
  <img data-src="lazy.jpg" alt="Lazy">
  <img srcset="small.jpg 1x, large.jpg 2x" alt="Responsive">
  <a href="/internal">Internal</a>
  <a href="https://external.example/x">External</a>
  <a href="mailto:hello@example.com">Mail</a>
  <p>Or write to plain@example.com directly.</p>
  <script>var tracked = "buried@inscript.com";</script>
</body>
</html>
''';

HtmlDocument get _doc =>
    HtmlDocument.parse(_article, url: 'https://site.example/dir/page.html');

void main() {
  group('title', () {
    test('prefers OpenGraph over <title>', () {
      expect(SmartExtractor.extractTitle(_doc), 'OpenGraph Title');
    });

    test('falls back to <title>, then to <h1>', () {
      final noOg = HtmlDocument.parse(
        '<html><head><title>Just Title</title></head><body><h1>H</h1></body></html>',
      );
      expect(SmartExtractor.extractTitle(noOg), 'Just Title');

      final onlyH1 = HtmlDocument.parse('<html><body><h1>Only H1</h1></body></html>');
      expect(SmartExtractor.extractTitle(onlyH1), 'Only H1');
    });

    test('is null when the page has no title at all', () {
      expect(
        SmartExtractor.extractTitle(HtmlDocument.parse('<html><body></body></html>')),
        isNull,
      );
    });
  });

  group('description', () {
    test('prefers OpenGraph, then meta description', () {
      expect(SmartExtractor.extractDescription(_doc), 'OpenGraph description');

      final metaOnly = HtmlDocument.parse(
        '<html><head><meta name="description" content="Meta only"></head></html>',
      );
      expect(SmartExtractor.extractDescription(metaOnly), 'Meta only');
    });

    test('falls back to the first substantial paragraph', () {
      final doc = HtmlDocument.parse(
        '<html><body><p>tiny</p>'
        '<p>A paragraph long enough to serve as a page description here.</p>'
        '</body></html>',
      );
      expect(
        SmartExtractor.extractDescription(doc),
        startsWith('A paragraph long enough'),
      );
    });
  });

  group('author and date', () {
    test('reads the author meta tag', () {
      expect(SmartExtractor.extractAuthor(_doc), 'Jane Writer');
    });

    test('reads the published time', () {
      expect(SmartExtractor.extractPublishDate(_doc), '2024-03-15T10:00:00Z');
    });

    test('reads a <time datetime> attribute', () {
      final doc = HtmlDocument.parse('<time datetime="2020-01-02">Jan 2</time>');
      expect(SmartExtractor.extractPublishDate(doc), '2020-01-02');
    });
  });

  group('links', () {
    test('resolves relative hrefs to absolute URLs', () {
      final links = SmartExtractor.extractLinks(_doc);
      expect(links, contains('https://site.example/internal'));
      expect(links, contains('https://external.example/x'));
    });

    test('excludes mailto, which is not a navigable location', () {
      expect(
        SmartExtractor.extractLinks(_doc).any((l) => l.startsWith('mailto:')),
        isFalse,
      );
    });

    test('captures no trailing markup in a URL', () {
      // The 1.x regex returned values like `https://example.com/x"` and
      // `https://example.com/y</p>` because a pattern cannot tell where an
      // attribute ends.
      for (final link in SmartExtractor.extractLinks(_doc)) {
        expect(link, isNot(contains('"')));
        expect(link, isNot(contains('<')));
      }
    });
  });

  group('images', () {
    test('resolves src, lazy-loading attributes and srcset', () {
      final images = SmartExtractor.extractImages(_doc);

      expect(images, contains('https://site.example/dir/photo.jpg'));
      expect(images, contains('https://site.example/dir/lazy.jpg'),
          reason: 'many sites leave src empty until JavaScript runs');
      expect(images, contains('https://site.example/dir/small.jpg'),
          reason: 'first srcset candidate');
      expect(images, contains('https://site.example/og-image.png'));
    });

    test('deduplicates', () {
      final doc = HtmlDocument.parse(
        '<img src="a.png"><img src="a.png">',
        url: 'https://s.example/',
      );
      expect(SmartExtractor.extractImages(doc), hasLength(1));
    });
  });

  group('emails', () {
    test('finds mailto links and addresses printed as text', () {
      final emails = SmartExtractor.extractEmails(_doc);

      expect(emails, contains('hello@example.com'));
      expect(emails, contains('plain@example.com'),
          reason: 'contact pages routinely print an address without linking it');
    });

    test('does not scan script bodies', () {
      // 1.x matched anything @-shaped anywhere in the raw HTML.
      expect(SmartExtractor.extractEmails(_doc),
          isNot(contains('buried@inscript.com')));
    });

    test('rejects asset filenames that merely contain @', () {
      final doc = HtmlDocument.parse(
        '<p>See logo@2x.png and sprite@3x.svg and real@example.com</p>',
      );
      final emails = SmartExtractor.extractEmails(doc);

      expect(emails, ['real@example.com']);
    });
  });

  group('headings', () {
    test('returns level and text in document order', () {
      final headings = SmartExtractor.extractHeadings(_doc);

      expect(headings.map((h) => h.level).toList(), [1, 2, 3]);
      expect(headings.first.text, 'Document Heading');
    });
  });

  group('OpenGraph', () {
    test('reads the fields and resolves the image', () {
      final og = SmartExtractor.extractOpenGraph(_doc)!;

      expect(og.title, 'OpenGraph Title');
      expect(og.siteName, 'Example Site');
      expect(og.image, 'https://site.example/og-image.png');
      expect(og.isEmpty, isFalse);
    });

    test('is null on a page with none', () {
      expect(
        SmartExtractor.extractOpenGraph(HtmlDocument.parse('<html></html>')),
        isNull,
      );
    });
  });

  group('canonical URL', () {
    test('resolves a relative canonical link', () {
      expect(
        SmartExtractor.extractCanonicalUrl(_doc),
        'https://site.example/canonical-path',
      );
    });
  });

  group('extractAll', () {
    test('populates every field in one pass', () {
      final content = SmartExtractor.extractAll(_doc);

      expect(content.title, 'OpenGraph Title');
      expect(content.description, 'OpenGraph description');
      expect(content.author, 'Jane Writer');
      expect(content.content, contains('Body paragraph'));
      expect(content.images, isNotEmpty);
      expect(content.links, isNotEmpty);
      expect(content.emails, isNotEmpty);
      expect(content.headings, hasLength(3));
      expect(content.openGraph, isNotNull);
    });
  });
}
