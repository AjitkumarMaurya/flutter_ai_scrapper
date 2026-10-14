import 'dart:isolate';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../structured/structured_extractor.dart';

class ParsedDocumentData {
  final String title;
  final String cleanText;
  final String markdown;
  final List<String> links;
  final Map<String, List<String>> selectorMatches;
  final Map<String, dynamic> structuredData;

  const ParsedDocumentData({
    required this.title,
    required this.cleanText,
    required this.markdown,
    required this.links,
    required this.selectorMatches,
    required this.structuredData,
  });
}

class HtmlDocumentParser {
  static const List<String> _noiseSelectors = [
    'script',
    'style',
    'noscript',
    'iframe',
    'svg',
    'canvas',
    'nav',
    'footer',
    'header',
    'aside',
    '.ads',
    '.advertisement',
    '.cookie-banner',
    '#cookie-banner',
  ];

  /// Parses HTML, strips noise, extracts Markdown & Structured Data inside a background Isolate.
  static Future<ParsedDocumentData> parseInBackground(
    String rawHtml, {
    String? baseUrl,
    List<String> customSelectors = const [],
    bool stripBoilerplate = true,
  }) async {
    return Isolate.run(() {
      final document = html_parser.parse(rawHtml);

      final title = document.querySelector('title')?.text.trim() ??
          document
              .querySelector('meta[property="og:title"]')
              ?.attributes['content']
              ?.trim() ??
          '';

      // Extract structured metadata before mutating DOM
      final structured = StructuredExtractor.extractAll(document);

      // Run custom selectors before stripping boilerplate in case user targets nav/footer
      final selectorResults = <String, List<String>>{};
      for (final selector in customSelectors) {
        final nodes = document.querySelectorAll(selector);
        selectorResults[selector] = nodes
            .map((e) => e.text.replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }

      // Extract resolved links
      final baseUri = baseUrl != null ? Uri.tryParse(baseUrl) : null;
      final links = <String>{};
      for (final a in document.querySelectorAll('a[href]')) {
        final href = a.attributes['href']?.trim();
        if (href == null || href.isEmpty || href.startsWith('javascript:')) {
          continue;
        }
        if (baseUri != null) {
          final resolved = baseUri.resolveUri(Uri.tryParse(href) ?? Uri());
          links.add(resolved.toString());
        } else {
          links.add(href);
        }
      }

      // Strip scripts, styles, and boilerplate noise
      if (stripBoilerplate) {
        for (final sel in _noiseSelectors) {
          document.querySelectorAll(sel).forEach((el) => el.remove());
        }
      } else {
        document
            .querySelectorAll('script, style, noscript')
            .forEach((el) => el.remove());
      }

      final root = document.querySelector('main') ??
          document.querySelector('article') ??
          document.body;

      final markdown = _convertToMarkdown(root);
      final cleanText =
          (root?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

      return ParsedDocumentData(
        title: title,
        cleanText: cleanText,
        markdown: markdown,
        links: links.toList(),
        selectorMatches: selectorResults,
        structuredData: structured,
      );
    });
  }

  static String _convertToMarkdown(dom.Element? root) {
    if (root == null) return '';
    final buffer = StringBuffer();

    void walk(dom.Node node) {
      if (node is dom.Text) {
        final text = node.text.replaceAll(RegExp(r'[ \t]+'), ' ');
        if (text.trim().isNotEmpty) {
          buffer.write(text);
        }
        return;
      }

      if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        switch (tag) {
          case 'h1':
            buffer.write('\n\n# ');
            node.nodes.forEach(walk);
            buffer.write('\n\n');
            break;
          case 'h2':
            buffer.write('\n\n## ');
            node.nodes.forEach(walk);
            buffer.write('\n\n');
            break;
          case 'h3':
          case 'h4':
            buffer.write('\n\n### ');
            node.nodes.forEach(walk);
            buffer.write('\n\n');
            break;
          case 'p':
          case 'div':
          case 'section':
          case 'article':
            buffer.write('\n\n');
            node.nodes.forEach(walk);
            buffer.write('\n\n');
            break;
          case 'li':
            buffer.write('\n- ');
            node.nodes.forEach(walk);
            break;
          case 'br':
            buffer.write('\n');
            break;
          default:
            node.nodes.forEach(walk);
        }
      }
    }

    walk(root);
    return buffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}
