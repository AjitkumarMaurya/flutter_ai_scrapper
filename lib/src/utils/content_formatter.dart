import 'package:html/dom.dart' as dom;

import '../dom/html_document.dart';

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
  static String toMarkdown(HtmlDocument document) {
    final body = _sanitizedCopy(document).body;
    if (body == null) return '';

    final buffer = StringBuffer();
    _writeMarkdown(body.raw, buffer, document.baseUrl);

    return _tidyMarkdown(buffer.toString());
  }

  /// Collapses whitespace **without** flattening list indentation.
  ///
  /// A blanket `' *\n *' -> '\n'` pass would strip the leading spaces that
  /// carry nesting in Markdown, turning a nested list into a flat one. So each
  /// line keeps its indent and is normalised only from the first non-space
  /// character onwards.
  static String _tidyMarkdown(String markdown) {
    final lines = markdown.split('\n').map((line) {
      final trimmedEnd = line.trimRight();
      if (trimmedEnd.trim().isEmpty) return '';

      final indent = trimmedEnd.length - trimmedEnd.trimLeft().length;
      final content = trimmedEnd.trimLeft().replaceAll(RegExp(r'[ \t]+'), ' ');
      return '${' ' * indent}$content';
    });

    return lines
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// The main article body, with navigation, headers and footers removed.
  ///
  /// A first pass at readability: page chrome is dropped, then the densest
  /// content container wins. Full node scoring — link density, paragraph
  /// weight, negative class patterns — lands in Phase 2.
  static String toReadableContent(HtmlDocument document) {
    final clean = _sanitizedCopy(document, removeChrome: true);

    const candidates = [
      'article',
      'main',
      '[role=main]',
      '.post-content',
      '.entry-content',
      '.article-body',
      '#content',
    ];

    String? best;
    var bestLength = 0;

    for (final selector in candidates) {
      for (final node in clean.select(selector)) {
        final text = node.blockText;
        if (text.length > bestLength) {
          bestLength = text.length;
          best = text;
        }
      }
    }

    if (best != null && bestLength >= 200) return best;

    final paragraphs = clean
        .select('p')
        .map((p) => p.text)
        .where((t) => t.length > 40)
        .join('\n\n');

    if (paragraphs.isNotEmpty) return paragraphs;
    return best ?? (clean.body?.blockText ?? '');
  }

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

  // -------------------------------------------------------------------------
  // Markdown walker
  // -------------------------------------------------------------------------

  static void _writeMarkdown(
    dom.Node node,
    StringBuffer buffer,
    String? baseUrl, {
    int listDepth = 0,
  }) {
    for (final child in node.nodes) {
      if (child.nodeType == dom.Node.TEXT_NODE) {
        buffer.write(child.text ?? '');
        continue;
      }
      if (child is! dom.Element) continue;

      switch (child.localName) {
        case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
          final level = int.tryParse(child.localName!.substring(1)) ?? 1;
          buffer.write('\n\n${'#' * level} ${_inline(child)}\n\n');

        case 'p':
          buffer.write('\n\n');
          _writeMarkdown(child, buffer, baseUrl, listDepth: listDepth);
          buffer.write('\n\n');

        case 'br':
          buffer.write('\n');

        case 'hr':
          buffer.write('\n\n---\n\n');

        case 'strong' || 'b':
          final text = _inline(child);
          if (text.isNotEmpty) buffer.write('**$text**');

        case 'em' || 'i':
          final text = _inline(child);
          if (text.isNotEmpty) buffer.write('*$text*');

        case 'code':
          // A <code> inside <pre> is handled by the 'pre' branch.
          if (child.parent?.localName != 'pre') {
            buffer.write('`${_inline(child)}`');
          } else {
            buffer.write(child.text);
          }

        case 'pre':
          buffer.write('\n\n```\n${child.text.trim()}\n```\n\n');

        case 'a':
          final text = _inline(child);
          final href = child.attributes['href'];
          if (href == null || href.isEmpty) {
            buffer.write(text);
          } else {
            final resolved = _resolve(href, baseUrl);
            buffer.write('[$text]($resolved)');
          }

        case 'img':
          final alt = child.attributes['alt'] ?? '';
          final src = child.attributes['src'];
          if (src != null && src.isNotEmpty) {
            buffer.write('![$alt](${_resolve(src, baseUrl)})');
          }

        case 'ul' || 'ol':
          buffer.write('\n');
          final ordered = child.localName == 'ol';
          var index = 1;
          for (final item in child.children) {
            if (item.localName != 'li') continue;
            final marker = ordered ? '${index++}.' : '-';
            buffer.write('\n${'  ' * listDepth}$marker ');
            _writeMarkdown(item, buffer, baseUrl, listDepth: listDepth + 1);
          }
          buffer.write('\n');

        case 'li':
          // Reached only for a stray <li> outside a list.
          buffer.write('\n${'  ' * listDepth}- ');
          _writeMarkdown(child, buffer, baseUrl, listDepth: listDepth + 1);

        case 'blockquote':
          final inner = StringBuffer();
          _writeMarkdown(child, inner, baseUrl, listDepth: listDepth);
          final quoted = inner
              .toString()
              .trim()
              .split('\n')
              .map((line) => '> $line')
              .join('\n');
          buffer.write('\n\n$quoted\n\n');

        case 'table':
          buffer.write('\n\n${_tableToMarkdown(child)}\n\n');

        default:
          _writeMarkdown(child, buffer, baseUrl, listDepth: listDepth);
      }
    }
  }

  static String _tableToMarkdown(dom.Element table) {
    final headers = <String>[];
    final rows = <List<String>>[];

    for (final row in table.querySelectorAll('tr')) {
      final cells = row.querySelectorAll('th, td');
      if (cells.isEmpty) continue;

      final values =
          cells.map((c) => c.text.replaceAll(RegExp(r'\s+'), ' ').trim()).toList();

      if (cells.every((c) => c.localName == 'th') && headers.isEmpty) {
        headers.addAll(values);
      } else {
        rows.add(values);
      }
    }

    return ExtractedTable(headers: headers, rows: rows).toMarkdown();
  }

  /// Inline text of [element], collapsed to a single line.
  static String _inline(dom.Element element) =>
      element.text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _resolve(String reference, String? baseUrl) {
    if (baseUrl == null) return reference;
    try {
      return Uri.parse(baseUrl).resolve(reference).toString();
    } on FormatException {
      return reference;
    }
  }
}
