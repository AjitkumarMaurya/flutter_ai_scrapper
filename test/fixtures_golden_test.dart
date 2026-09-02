import 'dart:convert';
import 'dart:io';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the whole fixture corpus through the extraction stack.
///
/// Every fixture is a saved page plus an `expected.json` of hand-reviewed
/// assertions. Fixtures run **offline**: a site redesigning overnight must
/// never turn CI red, and a test that needs the network is a test that fails
/// on a train.
///
/// Add one with `dart run tool/capture_fixture.dart <url> <name>`, then review
/// the generated expectations by hand — a golden file that only records
/// today's behaviour cannot catch tomorrow's regression.
void main() {
  final fixturesDir = Directory('test/fixtures');

  if (!fixturesDir.existsSync()) {
    test('fixture corpus exists', () {
      fail('test/fixtures is missing');
    });
    return;
  }

  final fixtures = fixturesDir
      .listSync()
      .whereType<Directory>()
      .where((d) => File('${d.path}/page.html').existsSync())
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the corpus covers every category the plan calls for', () {
    final categories = fixtures.map((dir) {
      final json = jsonDecode(File('${dir.path}/expected.json').readAsStringSync())
          as Map<String, dynamic>;
      return json['category'] as String;
    }).toSet();

    expect(categories, containsAll(['commerce', 'article', 'jobs', 'docs', 'malformed']));
    expect(fixtures.length, greaterThanOrEqualTo(10));
  });

  for (final dir in fixtures) {
    final name = dir.path.split(Platform.pathSeparator).last;

    group('fixture: $name', () {
      late HtmlDocument document;
      late Map<String, dynamic> expected;
      late MobileScraper scraper;

      setUp(() {
        final html = File('${dir.path}/page.html').readAsStringSync();
        expected = jsonDecode(
          File('${dir.path}/expected.json').readAsStringSync(),
        ) as Map<String, dynamic>;

        final url = expected['url'] as String? ?? 'https://fixture.example/page';
        document = HtmlDocument.parse(html, url: url);
        scraper = MobileScraper.fromHtml(html, url: url);
      });

      tearDown(() => scraper.dispose());

      test('parses without throwing', () {
        expect(document.raw.outerHtml, isNotEmpty);
      });

      test('extraction never leaks script or style bodies', () {
        final text = ContentFormatter.toPlainText(document);
        expect(text, isNot(contains('SHOULD_NOT_APPEAR')));
        expect(text, isNot(contains('window.__DATA__')));
        expect(text, isNot(contains('function(')));
      });

      test('every extracted URL is clean and absolute', () {
        for (final url in [
          ...SmartExtractor.extractLinks(document),
          ...SmartExtractor.extractImages(document),
        ]) {
          // The 1.x regex returned values with the closing quote or the next
          // tag captured into them.
          expect(url, isNot(contains('"')), reason: url);
          expect(url, isNot(contains('<')), reason: url);
          expect(url, isNot(contains('>')), reason: url);
          expect(Uri.parse(url).hasScheme, isTrue, reason: url);
        }
      });

      test('markdown round-trips without raw entities', () {
        final markdown = ContentFormatter.toMarkdown(document);
        for (final entity in const ['&amp;', '&lt;', '&quot;', '&nbsp;', '&mdash;']) {
          expect(markdown, isNot(contains(entity)), reason: entity);
        }
      });

      test('matches its recorded expectations', () {
        final content = SmartExtractor.extractAll(document);

        if (expected['title'] case final String title) {
          expect(content.title, title);
        }
        if (expected['author'] case final String author) {
          expect(content.author, author);
        }
        if (expected['publishDate'] case final String date) {
          expect(content.publishDate, date);
        }
        if (expected['canonicalUrl'] case final String canonical) {
          expect(content.canonicalUrl, canonical);
        }
        if (expected['hasOpenGraph'] case final bool hasOg) {
          expect(content.openGraph != null, hasOg);
        }
        if (expected['headingCount'] case final int count) {
          expect(content.headings, hasLength(count));
        }
        if (expected['emails'] case final List<dynamic> emails) {
          expect(content.emails..sort(), emails.cast<String>().toList()..sort());
        }
      });

      test('matches its structural expectations', () {
        if (expected['tableCount'] case final int count) {
          expect(ContentFormatter.extractTables(document), hasLength(count));
        }
        if (expected['tableRowCount'] case final int rows) {
          expect(ContentFormatter.extractTables(document).first.rows, hasLength(rows));
        }
        if (expected['tableHeaders'] case final List<dynamic> headers) {
          expect(ContentFormatter.extractTables(document).first.headers,
              headers.cast<String>());
        }
        if (expected['listItemCount'] case final int count) {
          expect(document.select('li'), hasLength(count));
        }
        if (expected['cardCount'] case final int count) {
          expect(document.select('ul.product-grid > li.card'), hasLength(count));
        }
        if (expected['cardTitles'] case final List<dynamic> titles) {
          // The decoy .card-title outside the grid must not be picked up.
          expect(
            document
                .select('ul.product-grid h3.card-title')
                .map((n) => n.text)
                .toList(),
            titles.cast<String>(),
          );
        }
        if (expected['jobCount'] case final int count) {
          expect(document.select('div.job'), hasLength(count));
        }
        if (expected['jobTitles'] case final List<dynamic> titles) {
          expect(
            document.select('.job-title').map((n) => n.text).toList(),
            titles.cast<String>(),
          );
        }
      });

      test('matches its content expectations', () {
        final text = ContentFormatter.toPlainText(document);

        if (expected['mustContain'] case final List<dynamic> needles) {
          for (final needle in needles.cast<String>()) {
            expect(text, contains(needle), reason: needle);
          }
        }
        if (expected['mustNotContain'] case final List<dynamic> needles) {
          for (final needle in needles.cast<String>()) {
            expect(text, isNot(contains(needle)), reason: needle);
          }
        }

        if (expected['readableMustContain'] case final List<dynamic> needles) {
          final readable = ContentFormatter.toReadableContent(document);
          for (final needle in needles.cast<String>()) {
            expect(readable, contains(needle), reason: needle);
          }
        }
        if (expected['readableMustNotContain'] case final List<dynamic> needles) {
          final readable = ContentFormatter.toReadableContent(document);
          for (final needle in needles.cast<String>()) {
            expect(readable, isNot(contains(needle)), reason: needle);
          }
        }

        if (expected['markdownMustContain'] case final List<dynamic> needles) {
          final markdown = ContentFormatter.toMarkdown(document);
          for (final needle in needles.cast<String>()) {
            expect(markdown, contains(needle), reason: needle);
          }
        }
      });
    });
  }
}
