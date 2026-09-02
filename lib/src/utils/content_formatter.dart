import '../dom/html_document.dart';
import '../readability/scorer.dart';
import '../reduce/markdown_writer.dart';

/// Output shapes [ContentFormatter] can produce.
enum ContentFormat {
  /// Readable text with block structure preserved as newlines.
  plainText,

  /// Markdown, keeping headings, lists, tables, links and emphasis.
  markdown,

  /// The main article body as text, with page chrome removed.
  readable,
}

/// A table lifted out of a page.
class ExtractedTable {
  /// Creates a table.
  const ExtractedTable({required this.headers, required this.rows});

  /// Header cells, empty when the table has no header row.
  final List<String> headers;

  /// Body rows.
  final List<List<String>> rows;

  /// Whether the table carried a header row.
  bool get hasHeaders => headers.isNotEmpty;

  /// This table as a GitHub-flavoured Markdown table.
  String toMarkdown() {
    if (headers.isEmpty && rows.isEmpty) return '';

    final columnCount = headers.isNotEmpty
        ? headers.length
        : rows.fold(0, (max, row) => row.length > max ? row.length : max);
    if (columnCount == 0) return '';

    final effectiveHeaders = headers.isNotEmpty
        ? headers
        : List.filled(columnCount, '');

    final buffer = StringBuffer()
      ..writeln('| ${effectiveHeaders.map(_escapeCell).join(' | ')} |')
      ..writeln('|${List.filled(columnCount, ' --- ').join('|')}|');

    for (final row in rows) {
      final padded = [
        ...row.take(columnCount),
        ...List.filled(
          columnCount > row.length ? columnCount - row.length : 0,
          '',
        ),
      ];
      buffer.writeln('| ${padded.map(_escapeCell).join(' | ')} |');
    }

    return buffer.toString().trimRight();
  }

  static String _escapeCell(String value) =>
      value.replaceAll('|', r'\|').replaceAll('\n', ' ');

  @override
  String toString() => 'ExtractedTable(${headers.length} cols, '
      '${rows.length} rows)';
}

/// Turns a parsed page into text, Markdown or a readable article.
///
/// Every method walks the DOM. The 1.x formatter chained dozens of
/// `replaceAll(RegExp(...))` calls over raw HTML, which mangled nested lists,
/// flattened tables into pipe soup, and — because it stripped tags before
/// decoding entities — left `&amp;` sequences scattered through its output.
abstract final class ContentFormatter {
  /// Formats [document] as [format].
  static String format(HtmlDocument document, ContentFormat format) =>
      switch (format) {
        ContentFormat.plainText => toPlainText(document),
        ContentFormat.markdown => toMarkdown(document),
        ContentFormat.readable => toReadableContent(document),
      };

  /// The page as readable text, with block structure kept as newlines.
  ///
  /// Sanitizes first, so script and style bodies never reach the output.
  static String toPlainText(HtmlDocument document) {
    final body = _sanitizedCopy(document).body;
    return body?.blockText ?? '';
  }

  /// The page as Markdown.
  ///
  /// Headings, paragraphs, lists (including nesting), links, images, emphasis,
  /// code, blockquotes, horizontal rules and tables are all preserved.
  static String toMarkdown(HtmlDocument document) =>
      MarkdownWriter.convert(document);

  /// The main article body, with navigation, headers and footers removed.
  static String toReadableContent(HtmlDocument document) =>
      ReadabilityScorer.extractArticle(document).text;

  /// Every table on the page, as structured rows rather than flattened text.
  static List<ExtractedTable> extractTables(HtmlDocument document) {
    final tables = <ExtractedTable>[];

    for (final table in document.select('table')) {
      final headers = <String>[];
      final rows = <List<String>>[];

      for (final row in table.select('tr')) {
        final cells = row.select('th, td');
        if (cells.isEmpty) continue;

        final values = cells.map((c) => c.text).toList();
        final isHeaderRow = cells.every((c) => c.tagName == 'th');

        if (isHeaderRow && headers.isEmpty) {
          headers.addAll(values);
        } else {
          rows.add(values);
        }
      }

      if (headers.isNotEmpty || rows.isNotEmpty) {
        tables.add(ExtractedTable(headers: headers, rows: rows));
      }
    }

    return tables;
  }

  /// Headings, links, images, lists, quotes and tables, grouped by kind.
  static Map<String, List<String>> extractSpecificContent(
    HtmlDocument document,
  ) =>
      {
        'headings': document
            .select('h1, h2, h3, h4, h5, h6')
            .map((n) => n.text)
            .where((t) => t.isNotEmpty)
            .toList(),
        'links': document
            .select('a[href]')
            .map((n) => '${n.text}: ${n.absoluteUrl('href') ?? n.attr('href')}')
            .toList(),
        'images': document
            .select('img')
            .map((n) => '${n.attr('alt') ?? ''}: ${n.absoluteUrl('src') ?? ''}')
            .toList(),
        'lists': document
            .select('ul, ol')
            .map((list) =>
                list.select('li').map((li) => '• ${li.text}').join('\n'))
            .where((t) => t.isNotEmpty)
            .toList(),
        'quotes': document
            .select('blockquote')
            .map((n) => n.text)
            .where((t) => t.isNotEmpty)
            .toList(),
        'tables': extractTables(document).map((t) => t.toMarkdown()).toList(),
      };

  /// Words in [text], by whitespace.
  static int wordCount(String text) =>
      text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  /// How long [text] would take to read.
  static Duration estimateReadingTime(String text, {int wordsPerMinute = 200}) {
    final words = wordCount(text);
    if (words == 0) return Duration.zero;
    return Duration(seconds: (words / wordsPerMinute * 60).ceil());
  }

  /// A sanitized clone, so formatting never mutates the caller's document.
  static HtmlDocument _sanitizedCopy(
    HtmlDocument document, {
    bool removeChrome = false,
  }) =>
      HtmlDocument.parse(document.raw.outerHtml, url: document.url)
          .sanitize(removeChrome: removeChrome);
}
