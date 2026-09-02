// Captures a live page into the golden fixture corpus.
//
//   dart run tool/capture_fixture.dart <url> <name> [--category=commerce]
//
// Fixtures let the corpus tests run offline and deterministically: a site
// redesigning overnight should never turn CI red. Re-capture deliberately,
// review the diff, and update the expectations alongside it.
//
// Be a good citizen. This sends one request, identifies itself honestly, and
// honours robots.txt. Only capture pages you have the right to store, and
// keep the corpus small — these files live in git forever.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';

const _categories = {
  'commerce',
  'article',
  'jobs',
  'docs',
  'listing',
  'malformed',
};

Future<void> main(List<String> args) async {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  if (positional.length < 2) {
    stderr.writeln(
      'Usage: dart run tool/capture_fixture.dart <url> <name> '
      '[--category=${_categories.join('|')}]',
    );
    exitCode = 64; // EX_USAGE
    return;
  }

  final url = positional[0];
  final name = positional[1];
  final category = args
          .firstWhere((a) => a.startsWith('--category='), orElse: () => '')
          .split('=')
          .lastOrNull ??
      '';

  if (category.isNotEmpty && !_categories.contains(category)) {
    stderr.writeln('Unknown category "$category". '
        'Expected one of: ${_categories.join(', ')}');
    exitCode = 64;
    return;
  }

  final directory = Directory('test/fixtures/$name');
  if (directory.existsSync()) {
    stdout.writeln('! test/fixtures/$name already exists — overwriting.');
  } else {
    directory.createSync(recursive: true);
  }

  stdout.writeln('Fetching $url …');

  final fetcher = Fetcher(
    config: const ScraperConfig(timeout: Duration(seconds: 30)),
  );

  try {
    final response = await fetcher.fetch(url);

    File('${directory.path}/page.html').writeAsStringSync(response.body);

    // Expectations start from what the extractor currently reports. Review
    // every value by hand before committing: a golden file that merely
    // records today's behaviour cannot catch tomorrow's regression.
    final document = HtmlDocument.parse(response.body, url: response.url);
    final content = SmartExtractor.extractAll(document);

    final expected = <String, dynamic>{
      'url': response.url,
      'category': category.isEmpty ? 'uncategorised' : category,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
      'bytes': response.bytesReceived,
      'title': content.title,
      'description': content.description,
      'author': content.author,
      'publishDate': content.publishDate,
      'canonicalUrl': content.canonicalUrl,
      'headingCount': content.headings.length,
      'imageCount': content.images.length,
      'linkCount': content.links.length,
      'emailCount': content.emails.length,
      'hasOpenGraph': content.openGraph != null,
      'wordCount': ContentFormatter.wordCount(
        ContentFormatter.toPlainText(document),
      ),
    };

    File('${directory.path}/expected.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(expected)}\n',
    );

    stdout
      ..writeln('✓ Saved test/fixtures/$name/page.html '
          '(${(response.bytesReceived / 1024).toStringAsFixed(1)} KB)')
      ..writeln('✓ Saved test/fixtures/$name/expected.json')
      ..writeln('')
      ..writeln('Now REVIEW expected.json by hand. It currently records what '
          'the extractor does today, which is not the same as what it should do.');
  } on RobotsDisallowedException {
    stderr.writeln('✗ $url disallows scraping in robots.txt. Not captured.');
    exitCode = 77; // EX_NOPERM
  } on ScraperException catch (error) {
    stderr.writeln('✗ ${error.message}');
    exitCode = 1;
  } finally {
    fetcher.dispose();
  }
}
