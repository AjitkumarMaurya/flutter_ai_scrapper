import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsing', () {
    test('applies the wildcard group when no named group matches', () {
      final rules = RobotsPolicy.parse('''
User-agent: *
Disallow: /private
Disallow: /admin
''', 'someagent');

      expect(rules.isAllowed('/public'), isTrue);
      expect(rules.isAllowed('/private'), isFalse);
      expect(rules.isAllowed('/private/data'), isFalse);
      expect(rules.isAllowed('/admin/x'), isFalse);
    });

    test('a named group beats the wildcard', () {
      const content = '''
User-agent: *
Disallow: /

User-agent: flutter_ai_scrapper
Disallow: /secret
''';
      final ours = RobotsPolicy.parse(content, 'flutter_ai_scrapper');
      expect(ours.isAllowed('/anything'), isTrue);
      expect(ours.isAllowed('/secret'), isFalse);

      final other = RobotsPolicy.parse(content, 'randombot');
      expect(other.isAllowed('/anything'), isFalse);
    });

    test('consecutive User-agent lines share one rule block', () {
      final rules = RobotsPolicy.parse('''
User-agent: alpha
User-agent: beta
Disallow: /shared
''', 'beta');

      expect(rules.isAllowed('/shared'), isFalse);
    });

    test('Allow overrides a less specific Disallow', () {
      final rules = RobotsPolicy.parse('''
User-agent: *
Disallow: /folder
Allow: /folder/public
''', 'bot');

      expect(rules.isAllowed('/folder/private'), isFalse);
      expect(rules.isAllowed('/folder/public'), isTrue,
          reason: 'the longer matching rule wins');
    });

    test('an empty Disallow means everything is allowed', () {
      final rules = RobotsPolicy.parse('''
User-agent: *
Disallow:
''', 'bot');

      expect(rules.isAllowed('/anything'), isTrue);
    });

    test('honours wildcards and end anchors', () {
      final rules = RobotsPolicy.parse('''
User-agent: *
Disallow: /*.pdf\$
Disallow: /tmp/*/cache
''', 'bot');

      expect(rules.isAllowed('/docs/manual.pdf'), isFalse);
      expect(rules.isAllowed('/docs/manual.pdf.html'), isTrue,
          reason: r'the $ anchor pins the match to the end');
      expect(rules.isAllowed('/tmp/a/cache'), isFalse);
      expect(rules.isAllowed('/tmp/a/other'), isTrue);
    });

    test('reads crawl-delay', () {
      final rules = RobotsPolicy.parse('''
User-agent: *
Crawl-delay: 2.5
''', 'bot');

      expect(rules.crawlDelay, const Duration(milliseconds: 2500));
    });

    test('collects sitemaps', () {
      final rules = RobotsPolicy.parse('''
Sitemap: https://example.com/sitemap.xml
User-agent: *
Disallow:
''', 'bot');

      expect(rules.sitemaps, ['https://example.com/sitemap.xml']);
    });

    test('ignores comments and blank lines', () {
      final rules = RobotsPolicy.parse('''
# a comment
User-agent: *   # trailing comment

Disallow: /x
''', 'bot');

      expect(rules.isAllowed('/x'), isFalse);
      expect(rules.isAllowed('/y'), isTrue);
    });

    test('an empty file forbids nothing', () {
      expect(RobotsPolicy.parse('', 'bot').isAllowed('/anything'), isTrue);
    });

    test('matches the agent token, not the full User-Agent header', () {
      // Our header is "flutter_ai_scrapper/2.0.0 (+https://…)"; robots.txt
      // names just the token.
      final rules = RobotsPolicy.parse('''
User-agent: flutter_ai_scrapper
Disallow: /nope
''', 'flutter_ai_scrapper');

      expect(rules.isAllowed('/nope'), isFalse);
    });
  });

  group('permissive default', () {
    test('allows everything', () {
      expect(RobotsRules.permissive.isAllowed('/anything'), isTrue);
      expect(RobotsRules.permissive.isAllowed('/'), isTrue);
    });
  });

  group('root path', () {
    test('an empty path is treated as /', () {
      final rules = RobotsPolicy.parse('''
User-agent: *
Disallow: /
''', 'bot');

      expect(rules.isAllowed(''), isFalse);
    });
  });
}
