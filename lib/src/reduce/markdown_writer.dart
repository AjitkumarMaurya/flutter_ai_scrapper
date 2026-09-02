/// DOM to GitHub-Flavoured Markdown serializer with reduction options.
library;

import 'package:html/dom.dart' as dom;

import '../dom/html_document.dart';
import '../dom/url_resolver.dart';

/// Configuration options for [MarkdownWriter].
class MarkdownOptions {
  /// Creates [MarkdownOptions].
  const MarkdownOptions({
    this.includeImages = true,
    this.includeLinks = true,
    this.maxDepth,
    this.preserveTables = true,
    this.baseUrl,
  });

  /// Whether to render `<img>` tags as Markdown `![alt](url)`.
  final bool includeImages;

  /// Whether to render `<a>` tags as Markdown `[text](url)`.
  final bool includeLinks;

  /// Maximum DOM traversal depth before stopping recursion.
  final int? maxDepth;

  /// Whether to format HTML `<table>` as GFM markdown tables.
  final bool preserveTables;

  /// Base URL to resolve relative image and link targets against.
  final String? baseUrl;
}

/// Serializes DOM nodes into clean, readable GitHub-Flavoured Markdown.
abstract final class MarkdownWriter {
  /// Converts [document] into Markdown according to [options].
  static String convert(
    HtmlDocument document, {
    MarkdownOptions options = const MarkdownOptions(),
  }) {
    final sanitized =
        HtmlDocument.parse(document.raw.outerHtml, url: document.url)
            .sanitize(removeChrome: false);
    final body = sanitized.body?.raw ?? sanitized.raw.body ?? sanitized.raw;

    final effectiveOptions = options.baseUrl != null
        ? options
        : MarkdownOptions(
            includeImages: options.includeImages,
            includeLinks: options.includeLinks,
            maxDepth: options.maxDepth,
            preserveTables: options.preserveTables,
            baseUrl: document.baseUrl,
          );

    final buffer = StringBuffer();
    _writeNode(body, buffer, effectiveOptions, currentDepth: 0, listDepth: 0);

    return _tidyMarkdown(buffer.toString());
  }

  static void _writeNode(
    dom.Node node,
    StringBuffer buffer,
    MarkdownOptions options, {
    required int currentDepth,
    required int listDepth,
  }) {
    if (options.maxDepth != null && currentDepth > options.maxDepth!) {
      return;
    }

    for (final child in node.nodes) {
      if (child.nodeType == dom.Node.TEXT_NODE) {
        buffer.write(child.text ?? '');
        continue;
      }

      if (child is! dom.Element) continue;

      switch (child.localName?.toLowerCase()) {
        case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
          final level = int.tryParse(child.localName!.substring(1)) ?? 1;
          final text = _inlineText(child);
          if (text.isNotEmpty) {
            buffer.write('\n\n${'#' * level} $text\n\n');
          }

        case 'p':
          buffer.write('\n\n');
          _writeNode(
            child,
            buffer,
            options,
            currentDepth: currentDepth + 1,
            listDepth: listDepth,
          );
          buffer.write('\n\n');

        case 'br':
          buffer.write('\n');

        case 'hr':
          buffer.write('\n\n---\n\n');

        case 'strong' || 'b':
          final text = _inlineText(child);
          if (text.isNotEmpty) buffer.write('**$text**');

        case 'em' || 'i':
          final text = _inlineText(child);
          if (text.isNotEmpty) buffer.write('*$text*');

        case 'code':
          if (child.parent?.localName?.toLowerCase() != 'pre') {
            final code = _inlineText(child);
            if (code.isNotEmpty) buffer.write('`$code`');
          } else {
            buffer.write(child.text);
          }

        case 'pre':
          final code = child.text.trim();
          if (code.isNotEmpty) {
            buffer.write('\n\n```\n$code\n```\n\n');
          }

        case 'a':
          final text = _inlineText(child);
          final href = child.attributes['href'];
          if (!options.includeLinks || href == null || href.isEmpty) {
            buffer.write(text);
          } else {
            final resolved = UrlResolver.resolve(href, options.baseUrl) ?? href;
            buffer.write('[$text]($resolved)');
          }

        case 'img':
          if (options.includeImages) {
            final alt = child.attributes['alt'] ?? '';
            final src = child.attributes['src'] ??
                child.attributes['data-src'] ??
                child.attributes['data-original'];
            if (src != null && src.isNotEmpty) {
              final resolved = UrlResolver.resolve(src, options.baseUrl) ?? src;
              buffer.write('![$alt]($resolved)');
            }
          }

        case 'ul' || 'ol':
          buffer.write('\n');
          final ordered = child.localName?.toLowerCase() == 'ol';
          var index = 1;
          for (final item in child.children) {
            if (item.localName?.toLowerCase() != 'li') continue;
            final marker = ordered ? '${index++}.' : '-';
            buffer.write('\n${'  ' * listDepth}$marker ');
            _writeNode(
              item,
              buffer,
              options,
              currentDepth: currentDepth + 1,
              listDepth: listDepth + 1,
            );
          }
          buffer.write('\n');

        case 'li':
          buffer.write('\n${'  ' * listDepth}- ');
          _writeNode(
            child,
            buffer,
            options,
            currentDepth: currentDepth + 1,
            listDepth: listDepth + 1,
          );

        case 'blockquote':
          final inner = StringBuffer();
          _writeNode(
            child,
            inner,
            options,
            currentDepth: currentDepth + 1,
            listDepth: listDepth,
          );
          final quoted = inner
              .toString()
              .trim()
              .split('\n')
              .map((line) => '> $line')
              .join('\n');
          buffer.write('\n\n$quoted\n\n');

        case 'table':
          if (options.preserveTables) {
            buffer.write('\n\n${_renderTable(child)}\n\n');
          } else {
            _writeNode(
              child,
              buffer,
              options,
              currentDepth: currentDepth + 1,
              listDepth: listDepth,
            );
          }

        default:
          _writeNode(
            child,
            buffer,
            options,
            currentDepth: currentDepth + 1,
            listDepth: listDepth,
          );
      }
    }
  }

  static String _renderTable(dom.Element table) {
    final headers = <String>[];
    final rows = <List<String>>[];

    for (final row in table.querySelectorAll('tr')) {
      final cells = row.querySelectorAll('th, td');
      if (cells.isEmpty) continue;

      final values = cells.map((c) => _cleanCell(c.text)).toList();
      final isHeader = cells.every((c) => c.localName?.toLowerCase() == 'th');

      if (isHeader && headers.isEmpty) {
        headers.addAll(values);
      } else {
        rows.add(values);
      }
    }

    if (headers.isEmpty && rows.isEmpty) return '';

    final colCount = headers.isNotEmpty
        ? headers.length
        : rows.fold(0, (max, r) => r.length > max ? r.length : max);
    if (colCount == 0) return '';

    final effectiveHeaders =
        headers.isNotEmpty ? headers : List.filled(colCount, '');

    final buffer = StringBuffer()
      ..writeln('| ${effectiveHeaders.map(_escapeCell).join(' | ')} |')
      ..writeln('|${List.filled(colCount, ' --- ').join('|')}|');

    for (final row in rows) {
      final padded = [
        ...row.take(colCount),
        ...List.filled(
          colCount > row.length ? colCount - row.length : 0,
          '',
        ),
      ];
      buffer.writeln('| ${padded.map(_escapeCell).join(' | ')} |');
    }

    return buffer.toString().trimRight();
  }

  static String _cleanCell(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _escapeCell(String text) =>
      text.replaceAll('|', r'\|').replaceAll('\n', ' ');

  static String _inlineText(dom.Element element) =>
      element.text.replaceAll(RegExp(r'\s+'), ' ').trim();

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
}
