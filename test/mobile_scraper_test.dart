import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

const _page = '''
<!DOCTYPE html>
<html><head><title>Shop</title></head>
<body>
  <div class="outer"><div class="inner">INNER</div>TAIL</div>
  <span>plain-span</span>
  <div class="product featured" id="p1">Widget</div>
  <div class="product">Gadget</div>
  <h1>Main Heading</h1>
  <h2>Sub A</h2><h2>Sub B</h2>
  <p>Contact us at <a href="mailto:sales@example.com">sales</a>.</p>
  <a href="/about">About</a>
  <script>window.SKU = "SKU-12345";</script>
</body></html>
''';

void main() {
  group('BUG-5 — regex group handling', () {
    late MobileScraper scraper;
    setUp(() => scraper = MobileScraper.fromHtml(_page));
    tearDown(() => scraper.dispose());

    test('a pattern with only non-capturing groups works', () {
      // 1.x always read group 1. A pattern built entirely from `(?:…)` has no
      // group 1, so match.group(1) threw RangeError — which the broad catch
      // relabelled "Failed to parse HTML with regex pattern", pointing the
      // caller at their markup instead of at the group index.
      const pattern = r'(?:Sub A|Sub B)';
      expect(
        () => scraper.queryWithRegex(pattern: pattern),
        returnsNormally,
      );
      expect(scraper.queryWithRegex(pattern: pattern), ['Sub A', 'Sub B']);
    });

    test('group defaults to 1 when the pattern does capture', () {
      final result = scraper.queryWithRegex(pattern: r'<h1[^>]*>(.*?)</h1>');
      expect(result, ['Main Heading']);
    });

    test('group 0 returns the whole match', () {
      final result =
          scraper.queryWithRegex(pattern: r'SKU-\d+', group: 0);
      expect(result, ['SKU-12345']);
    });

    test('an out-of-range group names the real limit', () {
      try {
        scraper.queryWithRegex(pattern: r'<h1>(.*?)</h1>', group: 7);
        fail('should have thrown');
      } on InvalidParameterException catch (e) {
        expect(e.parameterName, 'group');
        expect(e.message, contains('1 capture group'));
        expect(e.message, contains('0 to 1'));
      }
    });

    test('asking for a group in a group-less pattern explains why', () {
      try {
        scraper.queryWithRegex(pattern: r'(?:abc|Sub A)', group: 1);
        fail('should have thrown');
      } on InvalidParameterException catch (e) {
        expect(e.message, contains('no capture groups'));
        expect(e.message, contains('(?:...)'),
            reason: 'the message must name the actual mistake');
      }
    });

    test('an invalid pattern is a parameter error, not a parse error', () {
      // 1.x wrapped everything as ParseException, blaming the HTML.
      expect(
        () => scraper.queryWithRegex(pattern: '[unclosed'),
        throwsA(isA<InvalidParameterException>()),
      );
    });

    test('no matches gives an empty list, not an error', () {
      expect(scraper.queryWithRegex(pattern: 'nothing-matches-this'), isEmpty);
      expect(scraper.queryWithRegexFirst(pattern: 'nope'), isNull);
    });
  });

  group('queryAll on the DOM', () {
    late MobileScraper scraper;
    setUp(() => scraper = MobileScraper.fromHtml(_page));
    tearDown(() => scraper.dispose());

    test('nested containers keep all their text (BUG-1)', () {
      final result = scraper.queryAll(tag: 'div', className: 'outer');
      expect(result.single, allOf(contains('INNER'), contains('TAIL')));
    });

    test('a class filter does not leak to other elements (BUG-2)', () {
      expect(scraper.queryAll(tag: 'span', className: 'product'), isEmpty);
      expect(scraper.queryAll(tag: 'div', className: 'product'),
          ['Widget', 'Gadget']);
    });

    test('filters by id', () {
      expect(scraper.queryAll(tag: 'div', id: 'p1'), ['Widget']);
    });

    test('multiple classes require all of them', () {
      expect(
        scraper.queryAll(tag: 'div', className: 'product featured'),
        ['Widget'],
      );
    });

    test('an empty tag is rejected', () {
      expect(
        () => scraper.queryAll(tag: '  '),
        throwsA(isA<InvalidParameterException>()),
      );
    });

    test('query returns the first match or null', () {
      expect(scraper.query(tag: 'h2'), 'Sub A');
      expect(scraper.query(tag: 'article'), isNull);
    });
  });

  group('lifecycle', () {
    test('querying before load throws', () {
      final scraper = MobileScraper(
        url: 'https://example.com',
        platformInfo: const FakePlatformInfo.android(),
      );
      addTearDown(scraper.dispose);

      expect(scraper.isLoaded, isFalse);
      expect(
        () => scraper.queryAll(tag: 'h1'),
        throwsA(isA<ScraperNotInitializedException>()),
      );
    });

    test('dispose is idempotent', () {
      final scraper = MobileScraper.fromHtml(_page);
      expect(scraper.dispose, returnsNormally);
      expect(scraper.dispose, returnsNormally);
    });

    test('load after dispose is a StateError', () async {
      final scraper = MobileScraper(
        url: 'https://example.com',
        platformInfo: const FakePlatformInfo.android(),
      )..dispose();

      await expectLater(scraper.load(), throwsA(isA<StateError>()));
    });
  });

  group('URL validation', () {
    test('rejects addresses that are not http(s)', () {
      for (final url in const ['not-a-url', 'ftp://example.com', 'file:///x']) {
        expect(
          () => MobileScraper(
            url: url,
            platformInfo: const FakePlatformInfo.android(),
          ),
          throwsA(isA<InvalidUrlException>()),
          reason: url,
        );
      }
    });

    test('accepts http and https', () {
      for (final url in const ['http://example.com', 'https://example.com/a?b=c']) {
        final scraper = MobileScraper(
          url: url,
          platformInfo: const FakePlatformInfo.android(),
        );
        expect(scraper.url, url);
        scraper.dispose();
      }
    });
  });

  group('platform gate', () {
    test('Android and iOS are allowed', () {
      for (final platform in const [
        FakePlatformInfo.android(),
        FakePlatformInfo.ios(),
      ]) {
        final scraper = MobileScraper(
          url: 'https://example.com',
          platformInfo: platform,
        );
        expect(scraper.url, 'https://example.com');
        scraper.dispose();
      }
    });

    test('every other platform is refused', () {
      for (final os in const ['macos', 'windows', 'linux', 'fuchsia']) {
        expect(
          () => MobileScraper(
            url: 'https://example.com',
            platformInfo: FakePlatformInfo(os),
          ),
          throwsA(isA<UnsupportedPlatformException>()),
          reason: os,
        );
      }
    });

    test('the error names the offending platform', () {
      try {
        MobileScraper(
          url: 'https://example.com',
          platformInfo: const FakePlatformInfo('windows'),
        );
        fail('should have thrown');
      } on UnsupportedPlatformException catch (e) {
        expect(e.platform, 'windows');
        expect(e.message, contains('windows'));
      }
    });
  });

  group('select', () {
    late MobileScraper scraper;
    setUp(() => scraper = MobileScraper.fromHtml(
          _page,
          url: 'https://shop.example/catalog/',
        ));
    tearDown(() => scraper.dispose());

    test('reaches the DOM directly', () {
      expect(scraper.select('.product').length, 2);
      expect(scraper.selectFirst('h1')?.text, 'Main Heading');
    });

    test('resolves relative links against the page URL', () {
      final about = scraper.select('a[href]').firstWhere(
            (a) => a.text == 'About',
          );
      expect(about.absoluteUrl('href'), 'https://shop.example/about');
    });

    test('unsupported selectors are refused, not silently empty', () {
      expect(
        () => scraper.select('div:nth-child(2)'),
        throwsA(isA<InvalidSelectorException>()),
      );
    });
  });
}
