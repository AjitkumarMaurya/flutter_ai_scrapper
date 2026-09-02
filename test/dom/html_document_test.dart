import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Markup exercising every failure mode the 1.x regex engine had.
const _fixture = '''
<!DOCTYPE html>
<html>
<head>
  <title>Caf&eacute; &amp; Bar</title>
  <base href="https://cdn.example/assets/">
  <meta name="description" content="A &mdash; description">
  <meta property="og:title" content="OG Title">
</head>
<body>
  <div class="outer"><div class="inner">INNER</div>TAIL</div>
  <span>no-class-span</span>
  <div class="target extra">REAL TARGET</div>
  <p>Caf&eacute; &#x2014; &#8212; &nbsp;done</p>
  <a href="/relative">rel</a>
  <a href="pic.html">doc-relative</a>
  <a href="https://absolute.example/x">abs</a>
  <a href="#fragment">frag</a>
  <a href="mailto:someone@example.com">mail</a>
  <img src="pic.jpg" alt="a &mdash; b">
  <ul><li>one</li><li>two</li></ul>
  <script>var leaked = "SCRIPTLEAK";</script>
  <style>.x { content: "STYLELEAK"; }</style>
  <div hidden>HIDDENLEAK</div>
  <div aria-hidden="true">ARIALEAK</div>
  <div style="display:none">DISPLAYLEAK</div>
  <!-- COMMENTLEAK -->
  <p>unclosed paragraph
  <div class=noquote>UNQUOTED</div>
</body>
</html>
''';

void main() {
  group('BUG-1 — nested same-tag extraction', () {
    test('captures the full outer element, not up to the first close', () {
      final doc = HtmlDocument.parse(_fixture);
      final outer = doc.selectFirst('div.outer');

      // The 1.x pattern `<div[^>]*>(.*?)</div>` stopped at the *inner*
      // closing tag, returning `<div class="inner">INNER` and silently
      // dropping TAIL. Both must now be present.
      expect(outer, isNotNull);
      expect(outer!.text, contains('INNER'));
      expect(outer.text, contains('TAIL'));
    });

    test('inner element is still addressable on its own', () {
      final doc = HtmlDocument.parse(_fixture);
      expect(doc.selectFirst('div.inner')?.text, 'INNER');
    });
  });

  group('BUG-2 — class filter must not leak across the document', () {
    test('an element without the class never matches it', () {
      final doc = HtmlDocument.parse(_fixture);

      // The 1.x lookahead `(?=.*class="target")` ran with dotAll, so it
      // scanned the rest of the document and matched this <span> purely
      // because an unrelated later <div> carried that class.
      expect(doc.select('span.target'), isEmpty);
    });

    test('the element that does have the class still matches', () {
      final doc = HtmlDocument.parse(_fixture);
      expect(doc.selectFirst('div.target')?.text, 'REAL TARGET');
    });

    test('matches one class out of several on the same element', () {
      final doc = HtmlDocument.parse(_fixture);
      expect(doc.selectFirst('.extra')?.text, 'REAL TARGET');
    });
  });

  group('entity decoding', () {
    test('named, hex and decimal entities all decode', () {
      final doc = HtmlDocument.parse(_fixture);
      final paragraph = doc.select('p').first.text;

      expect(paragraph, contains('Café')); // &eacute;
      expect(paragraph, contains('—')); // &#x2014; and &#8212;
      expect(paragraph, isNot(contains('&')));
    });

    test('decodes entities in the title and in attributes', () {
      final doc = HtmlDocument.parse(_fixture);
      expect(doc.title, 'Café & Bar');
      expect(doc.selectFirst('img')?.attr('alt'), 'a — b');
    });
  });

  group('sanitize', () {
    test('script and style bodies do not leak into text', () {
      // Without sanitizing, Element.text concatenates script source too.
      final dirty = HtmlDocument.parse(_fixture);
      expect(dirty.text, contains('SCRIPTLEAK'),
          reason: 'guards the assumption this test exists to fix');

      final clean = HtmlDocument.parse(_fixture).sanitize();
      expect(clean.text, isNot(contains('SCRIPTLEAK')));
      expect(clean.text, isNot(contains('STYLELEAK')));
    });

    test('hidden elements are dropped', () {
      final doc = HtmlDocument.parse(_fixture).sanitize();
      expect(doc.text, isNot(contains('HIDDENLEAK')));
      expect(doc.text, isNot(contains('ARIALEAK')));
      expect(doc.text, isNot(contains('DISPLAYLEAK')));
    });

    test('real content survives sanitizing', () {
      final doc = HtmlDocument.parse(_fixture).sanitize();
      expect(doc.text, contains('REAL TARGET'));
      expect(doc.text, contains('INNER'));
    });
  });

  group('URL resolution', () {
    test('<base href> wins over the document URL', () {
      final doc =
          HtmlDocument.parse(_fixture, url: 'https://page.example/dir/page.html');
      expect(doc.baseUrl, 'https://cdn.example/assets/');
    });

    test('root-relative and doc-relative hrefs both resolve', () {
      final doc = HtmlDocument.parse(_fixture);
      final links = doc.select('a');

      expect(links[0].absoluteUrl('href'), 'https://cdn.example/relative');
      expect(links[1].absoluteUrl('href'), 'https://cdn.example/assets/pic.html');
      expect(links[2].absoluteUrl('href'), 'https://absolute.example/x');
    });

    test('non-navigable hrefs resolve to null but stay readable raw', () {
      final doc = HtmlDocument.parse(_fixture);
      final links = doc.select('a');

      expect(links[3].absoluteUrl('href'), isNull, reason: 'fragment');
      expect(links[4].absoluteUrl('href'), isNull, reason: 'mailto');
      expect(links[4].attr('href'), 'mailto:someone@example.com');
    });

    test('falls back to the document URL with no <base>', () {
      final doc = HtmlDocument.parse(
        '<html><body><a href="/x">l</a></body></html>',
        url: 'https://site.example/deep/page.html',
      );
      expect(doc.selectFirst('a')?.absoluteUrl('href'), 'https://site.example/x');
    });
  });

  group('malformed markup', () {
    test('unclosed tags and unquoted attributes still parse', () {
      final doc = HtmlDocument.parse(_fixture);
      expect(doc.selectFirst('div.noquote')?.text, 'UNQUOTED');
      expect(doc.select('p').any((p) => p.text.contains('unclosed')), isTrue);
    });

    test('comments never appear in text', () {
      final doc = HtmlDocument.parse(_fixture);
      expect(doc.text, isNot(contains('COMMENTLEAK')));
    });
  });

  group('selector guard', () {
    test('rejects pseudo-classes the parser answers wrongly', () {
      final doc = HtmlDocument.parse(_fixture);

      // package:html returns ZERO matches for `li:nth-child(2)` on markup that
      // plainly has one. A confidently empty result is worse than a refusal,
      // so these are rejected with a message naming the workaround.
      for (final selector in const [
        'li:nth-child(2)',
        'p:first-child',
        'div:has(p)',
        'div:not(.x)',
      ]) {
        expect(
          () => doc.select(selector),
          throwsA(isA<InvalidSelectorException>()),
          reason: selector,
        );
      }
    });

    test('the error explains what to do instead', () {
      final doc = HtmlDocument.parse(_fixture);
      try {
        doc.select('li:nth-child(2)');
        fail('should have thrown');
      } on InvalidSelectorException catch (e) {
        expect(e.message, contains('index the returned list'));
        expect(e.selector, 'li:nth-child(2)');
        expect(e.userMessage, isNot(contains('nth-child')),
            reason: 'user message stays non-technical');
      }
    });

    test('does not mistake an attribute operator for a combinator', () {
      final doc = HtmlDocument.parse(_fixture);
      expect(() => doc.select('[class~=target]'), returnsNormally);
      expect(() => doc.select('div ~ p'), throwsA(isA<InvalidSelectorException>()));
    });

    test('rejects an empty selector', () {
      final doc = HtmlDocument.parse(_fixture);
      expect(() => doc.select('  '), throwsA(isA<InvalidSelectorException>()));
    });
  });

  group('supported selectors', () {
    test('tag, class, id, attribute, descendant and child all work', () {
      final doc = HtmlDocument.parse(_fixture);
      expect(doc.select('li').length, 2);
      expect(doc.select('.target').length, 1);
      expect(doc.select('a[href]').length, 5);
      expect(doc.select('ul li').length, 2);
      expect(doc.select('ul > li').length, 2);
      expect(doc.select('div.outer div').length, 1);
    });
  });

  group('meta', () {
    test('reads both name and property, case-insensitively', () {
      final doc = HtmlDocument.parse(_fixture);
      expect(doc.meta('description'), 'A — description');
      expect(doc.meta('og:title'), 'OG Title');
      expect(doc.meta('OG:TITLE'), 'OG Title');
      expect(doc.meta('absent'), isNull);
    });
  });

  group('blockText', () {
    test('keeps block boundaries that text collapses', () {
      final doc = HtmlDocument.parse(
        '<div><p>one</p><p>two</p><li>three</li></div>',
      );
      final node = doc.selectFirst('div')!;

      expect(node.text, 'onetwothree');
      expect(node.blockText.split('\n').where((l) => l.isNotEmpty).toList(),
          ['one', 'two', 'three']);
    });
  });
}
