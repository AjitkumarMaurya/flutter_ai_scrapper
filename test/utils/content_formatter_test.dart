import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

HtmlDocument _doc(String html, {String? url}) =>
    HtmlDocument.parse(html, url: url);

void main() {
  group('toPlainText', () {
    test('keeps block boundaries instead of running text together', () {
      final doc = _doc('<h1>Title</h1><p>First para.</p><p>Second para.</p>');
      final lines = ContentFormatter.toPlainText(doc)
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();

      expect(lines, ['Title', 'First para.', 'Second para.']);
    });

    test('drops script and style bodies', () {
      final doc = _doc('''
        <p>Real content</p>
        <script>var secret = "SCRIPTLEAK";</script>
        <style>.a { content: "STYLELEAK"; }</style>
      ''');
      final text = ContentFormatter.toPlainText(doc);

      expect(text, contains('Real content'));
      expect(text, isNot(contains('SCRIPTLEAK')));
      expect(text, isNot(contains('STYLELEAK')));
    });

    test('decodes entities rather than leaving them raw', () {
      // 1.x stripped tags before decoding entities, so &amp; survived into
      // the output. The parser decodes during parsing, so this cannot recur.
      final doc = _doc('<p>Ben &amp; Jerry&rsquo;s &mdash; caf&eacute;</p>');
      final text = ContentFormatter.toPlainText(doc);

      expect(text, contains('Ben & Jerry'));
      expect(text, contains('café'));
      expect(text, isNot(contains('&amp;')));
      expect(text, isNot(contains('&eacute;')));
    });

    test('leaves the source document untouched', () {
      final doc = _doc('<p>Keep</p><script>x</script>');
      ContentFormatter.toPlainText(doc);

      // Formatting works on a copy: the caller's document keeps its scripts.
      expect(doc.select('script'), isNotEmpty);
    });
  });

  group('toMarkdown', () {
    test('renders headings at the right level', () {
      final doc = _doc('<h1>One</h1><h2>Two</h2><h3>Three</h3>');
      final md = ContentFormatter.toMarkdown(doc);

      expect(md, contains('# One'));
      expect(md, contains('## Two'));
      expect(md, contains('### Three'));
    });

    test('renders emphasis, code and links', () {
      final doc = _doc(
        '<p><strong>bold</strong> <em>italic</em> <code>x=1</code> '
        '<a href="https://e.example/p">link</a></p>',
      );
      final md = ContentFormatter.toMarkdown(doc);

      expect(md, contains('**bold**'));
      expect(md, contains('*italic*'));
      expect(md, contains('`x=1`'));
      expect(md, contains('[link](https://e.example/p)'));
    });

    test('resolves relative link targets', () {
      final doc = _doc(
        '<a href="/about">About</a>',
        url: 'https://site.example/dir/page.html',
      );
      expect(
        ContentFormatter.toMarkdown(doc),
        contains('[About](https://site.example/about)'),
      );
    });

    test('renders ordered and unordered lists', () {
      final doc = _doc('<ul><li>a</li><li>b</li></ul><ol><li>x</li><li>y</li></ol>');
      final md = ContentFormatter.toMarkdown(doc);

      expect(md, contains('- a'));
      expect(md, contains('- b'));
      expect(md, contains('1. x'));
      expect(md, contains('2. y'));
    });

    test('renders nested lists with indentation', () {
      // The 1.x regex approach flattened nesting entirely.
      final doc = _doc('<ul><li>outer<ul><li>inner</li></ul></li></ul>');
      final md = ContentFormatter.toMarkdown(doc);

      expect(md, contains('- outer'));
      expect(md, contains('  - inner'));
    });

    test('renders a real table, not pipe soup', () {
      final doc = _doc('''
        <table>
          <tr><th>Name</th><th>Price</th></tr>
          <tr><td>Widget</td><td>10</td></tr>
          <tr><td>Gadget</td><td>20</td></tr>
        </table>
      ''');
      final md = ContentFormatter.toMarkdown(doc);

      expect(md, contains('| Name | Price |'));
      expect(md, contains('| --- | --- |'));
      expect(md, contains('| Widget | 10 |'));
      expect(md, contains('| Gadget | 20 |'));
    });

    test('renders blockquotes and rules', () {
      final doc = _doc('<blockquote><p>quoted</p></blockquote><hr>');
      final md = ContentFormatter.toMarkdown(doc);

      expect(md, contains('> quoted'));
      expect(md, contains('---'));
    });

    test('renders images with their alt text', () {
      final doc = _doc('<img src="https://e.example/p.png" alt="A picture">');
      expect(
        ContentFormatter.toMarkdown(doc),
        contains('![A picture](https://e.example/p.png)'),
      );
    });

    test('renders preformatted blocks as fenced code', () {
      final doc = _doc('<pre><code>void main() {}</code></pre>');
      final md = ContentFormatter.toMarkdown(doc);

      expect(md, contains('```'));
      expect(md, contains('void main() {}'));
    });
  });

  group('toReadableContent', () {
    test('prefers the article body and drops page chrome', () {
      final doc = _doc('''
        <body>
          <nav>Home Products About Contact Careers Blog Support</nav>
          <header>Site banner with a good deal of navigational text here</header>
          <article>
            <p>${'This is the real article body that a reader came for. ' * 4}</p>
          </article>
          <footer>Copyright notice and a long list of footer links here</footer>
        </body>
      ''');
      final readable = ContentFormatter.toReadableContent(doc);

      expect(readable, contains('real article body'));
      expect(readable, isNot(contains('Site banner')));
      expect(readable, isNot(contains('Copyright notice')));
    });

    test('falls back to paragraphs when nothing structural stands out', () {
      final doc = _doc(
        '<body><div><p>${'Substantial prose in a plain div. ' * 5}</p></div></body>',
      );
      expect(ContentFormatter.toReadableContent(doc), contains('Substantial prose'));
    });
  });

  group('extractTables', () {
    test('separates headers from body rows', () {
      final doc = _doc('''
        <table>
          <thead><tr><th>A</th><th>B</th></tr></thead>
          <tbody><tr><td>1</td><td>2</td></tr></tbody>
        </table>
      ''');
      final tables = ContentFormatter.extractTables(doc);

      expect(tables, hasLength(1));
      expect(tables.single.headers, ['A', 'B']);
      expect(tables.single.rows, [
        ['1', '2'],
      ]);
      expect(tables.single.hasHeaders, isTrue);
    });

    test('handles a table with no header row', () {
      final doc = _doc('<table><tr><td>x</td><td>y</td></tr></table>');
      final table = ContentFormatter.extractTables(doc).single;

      expect(table.hasHeaders, isFalse);
      expect(table.rows, [
        ['x', 'y'],
      ]);
    });

    test('escapes pipes so a cell cannot break the markdown row', () {
      final doc = _doc('<table><tr><th>H</th></tr><tr><td>a|b</td></tr></table>');
      expect(ContentFormatter.extractTables(doc).single.toMarkdown(),
          contains(r'a\|b'));
    });
  });

  group('extractSpecificContent', () {
    test('groups content by kind', () {
      final doc = _doc('''
        <h1>Heading</h1>
        <a href="https://e.example">Link</a>
        <img src="https://e.example/i.png" alt="Img">
        <ul><li>item</li></ul>
        <blockquote>quote</blockquote>
        <table><tr><th>H</th></tr><tr><td>c</td></tr></table>
      ''');
      final grouped = ContentFormatter.extractSpecificContent(doc);

      expect(grouped['headings'], contains('Heading'));
      expect(grouped['links']!.single, contains('https://e.example'));
      expect(grouped['images']!.single, contains('Img'));
      expect(grouped['lists']!.single, contains('item'));
      expect(grouped['quotes'], ['quote']);
      expect(grouped['tables']!.single, contains('| H |'));
    });
  });

  group('word count and reading time', () {
    test('counts words by whitespace', () {
      expect(ContentFormatter.wordCount('one two three'), 3);
      expect(ContentFormatter.wordCount('  spaced   out  '), 2);
      expect(ContentFormatter.wordCount(''), 0);
    });

    test('reports reading time in seconds, not rounded-up minutes', () {
      // 100 words at 200 wpm is 30 seconds. Reporting that as "1 minute", as
      // 1.x did, overstates it; callers who want minutes can round themselves.
      final text = List.filled(100, 'word').join(' ');
      final duration = ContentFormatter.estimateReadingTime(text);

      expect(duration.inSeconds, 30);
    });

    test('empty text takes no time', () {
      expect(ContentFormatter.estimateReadingTime(''), Duration.zero);
    });

    test('honours a custom reading speed', () {
      final text = List.filled(100, 'word').join(' ');
      expect(
        ContentFormatter.estimateReadingTime(text, wordsPerMinute: 100).inSeconds,
        60,
      );
    });
  });

  group('format', () {
    test('dispatches to the right renderer', () {
      final doc = _doc('<h1>Title</h1><p>Body text here.</p>');

      expect(ContentFormatter.format(doc, ContentFormat.markdown),
          contains('# Title'));
      expect(ContentFormatter.format(doc, ContentFormat.plainText),
          isNot(contains('#')));
    });
  });
}
