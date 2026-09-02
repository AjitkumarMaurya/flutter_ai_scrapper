import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../core/scraper_exceptions.dart';
import 'sanitizer.dart';
import 'selector.dart';
import 'url_resolver.dart';

/// A parsed HTML document.
///
/// Wraps `package:html`'s spec-compliant HTML5 parser. Every extraction path in
/// this package goes through here rather than through regular expressions,
/// which is what fixes the 1.x defects: regex cannot pair an opening tag with
/// its *matching* close, cannot tell where an attribute ends, and cannot decode
/// entities. The parser does all three by construction.
class HtmlDocument {
  HtmlDocument._(this._document, this.url, this._baseUrl);

  /// Parses [html], resolving relative URLs against [url].
  ///
  /// The parser recovers from malformed markup the way a browser does, so this
  /// rarely throws; when it does, the content was almost certainly not HTML.
  factory HtmlDocument.parse(String html, {String? url}) {
    final dom.Document document;
    try {
      document = html_parser.parse(html);
    } on Object catch (error, stackTrace) {
      throw ParseException(
        'Failed to parse HTML',
        url: url,
        cause: error,
        stackTrace: stackTrace,
        snippet: html.length > 200 ? '${html.substring(0, 200)}…' : html,
      );
    }

    final baseHref = document.querySelector('base')?.attributes['href'];
    return HtmlDocument._(
      document,
      url,
      UrlResolver.effectiveBase(baseHref: baseHref, documentUrl: url),
    );
  }

  final dom.Document _document;

  /// The URL this document was fetched from, when known.
  final String? url;

  final String? _baseUrl;

  /// The base that relative URLs on this page resolve against.
  ///
  /// A `<base href>` element takes precedence over [url], per the HTML spec.
  String? get baseUrl => _baseUrl;

  /// The underlying parsed document.
  ///
  /// Exposed for advanced use. Prefer [select] and [selectFirst]; this is an
  /// escape hatch, and code written against it is coupled to `package:html`.
  dom.Document get raw => _document;

  /// The document's `<title>`, trimmed, or `null` when absent or blank.
  String? get title {
    final value = _document.querySelector('title')?.text.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// The `<body>` as an [HtmlNode], or `null` if the document has none.
  HtmlNode? get body {
    final element = _document.body;
    return element == null ? null : HtmlNode._(element, _baseUrl);
  }

  /// Removes scripts, styles and other non-content nodes, in place.
  ///
  /// Returns this document for chaining. **Call this before reading text** —
  /// `Element.text` includes `<script>` bodies otherwise, so unsanitized text
  /// extraction returns JavaScript source mixed into the prose.
  HtmlDocument sanitize({
    bool removeChrome = false,
    Set<String> additionalTags = const {},
  }) {
    Sanitizer.sanitize(
      _document,
      removeChrome: removeChrome,
      additionalTags: additionalTags,
    );
    return this;
  }

  /// All elements matching [cssSelector].
  ///
  /// Throws [InvalidSelectorException] for constructs the parser cannot
  /// evaluate — see [SelectorGuard] for why that is better than the empty list
  /// the parser would otherwise return.
  List<HtmlNode> select(String cssSelector) {
    SelectorGuard.validate(cssSelector);
    try {
      return _document
          .querySelectorAll(cssSelector)
          .map((e) => HtmlNode._(e, _baseUrl))
          .toList(growable: false);
    } on UnimplementedError catch (error) {
      throw InvalidSelectorException(
        cssSelector,
        'the HTML parser does not implement part of this selector. '
        '${InvalidSelectorException.unsupportedSelectorHelp}',
        cause: error,
      );
    } on FormatException catch (error) {
      throw InvalidSelectorException(
        cssSelector,
        'the selector is not valid CSS',
        cause: error,
      );
    }
  }

  /// The first element matching [cssSelector], or `null` if there is none.
  HtmlNode? selectFirst(String cssSelector) {
    final matches = select(cssSelector);
    return matches.isEmpty ? null : matches.first;
  }

  /// The content of a `<meta>` tag, by `name` or `property`.
  ///
  /// Checks `property` first so OpenGraph (`og:title`) resolves, then `name`
  /// for standard and Twitter tags. Matching is case-insensitive because real
  /// pages are inconsistent about it.
  String? meta(String nameOrProperty) {
    final needle = nameOrProperty.toLowerCase();
    for (final element in _document.querySelectorAll('meta')) {
      final attributes = element.attributes;
      final key = (attributes['property'] ?? attributes['name'] ?? '')
          .toString()
          .toLowerCase();
      if (key == needle) {
        final content = attributes['content']?.trim();
        if (content != null && content.isNotEmpty) return content;
      }
    }
    return null;
  }

  /// The whole document's visible text, whitespace-normalised.
  ///
  /// Sanitize first, or script bodies will be included.
  String get text => _normalizeWhitespace(_document.body?.text ?? '');
}

/// A single element in an [HtmlDocument].
class HtmlNode {
  HtmlNode._(this._element, this._baseUrl);

  final dom.Element _element;
  final String? _baseUrl;

  /// The underlying element. An escape hatch; prefer the methods here.
  dom.Element get raw => _element;

  /// The base this element's relative URLs resolve against.
  String? get baseUrl => _baseUrl;

  /// Resolves an arbitrary [reference] against this element's base.
  ///
  /// For values that are not a single attribute — a `srcset` candidate, say.
  String? resolveUrl(String? reference) =>
      UrlResolver.resolve(reference, _baseUrl);

  /// Lowercase tag name, e.g. `div`.
  String get tagName => _element.localName ?? '';

  /// The element's `id`, or `null`.
  String? get id {
    final value = _element.id;
    return value.isEmpty ? null : value;
  }

  /// The element's CSS classes.
  Set<String> get classes => _element.classes;

  /// This element's text and all of its descendants', whitespace-normalised.
  String get text => _normalizeWhitespace(_element.text);

  /// Text with the document's original line structure preserved.
  ///
  /// Unlike [text], block-level boundaries become newlines, so paragraphs and
  /// list items stay separated instead of running together.
  String get blockText {
    final buffer = StringBuffer();
    _writeBlockText(_element, buffer);
    return buffer
        .toString()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// This element's inner HTML.
  String get innerHtml => _element.innerHtml;

  /// This element's outer HTML, including its own tag.
  String get outerHtml => _element.outerHtml;

  /// The value of [name], or `null` when the attribute is absent.
  String? attr(String name) => _element.attributes[name];

  /// Whether [name] is present on this element.
  bool hasAttr(String name) => _element.attributes.containsKey(name);

  /// All attributes on this element.
  Map<String, String> get attributes => {
        for (final entry in _element.attributes.entries)
          entry.key.toString(): entry.value,
      };

  /// The value of [name] resolved to an absolute URL.
  ///
  /// Returns `null` when the attribute is missing, or when it is not a
  /// navigable location (`#fragment`, `javascript:`, `mailto:` and friends).
  /// Use [attr] to read those raw.
  String? absoluteUrl(String name) =>
      UrlResolver.resolve(_element.attributes[name], _baseUrl);

  /// This element's parent, or `null` at the root.
  HtmlNode? get parent {
    final parent = _element.parent;
    return parent == null ? null : HtmlNode._(parent, _baseUrl);
  }

  /// This element's direct element children.
  List<HtmlNode> get children => _element.children
      .map((e) => HtmlNode._(e, _baseUrl))
      .toList(growable: false);

  /// Descendants matching [cssSelector].
  List<HtmlNode> select(String cssSelector) {
    SelectorGuard.validate(cssSelector);
    try {
      return _element
          .querySelectorAll(cssSelector)
          .map((e) => HtmlNode._(e, _baseUrl))
          .toList(growable: false);
    } on UnimplementedError catch (error) {
      throw InvalidSelectorException(
        cssSelector,
        'the HTML parser does not implement part of this selector. '
        '${InvalidSelectorException.unsupportedSelectorHelp}',
        cause: error,
      );
    }
  }

  /// The first descendant matching [cssSelector], or `null`.
  HtmlNode? selectFirst(String cssSelector) {
    final matches = select(cssSelector);
    return matches.isEmpty ? null : matches.first;
  }

  /// Removes this element and its subtree from the document.
  void remove() => _element.remove();

  @override
  String toString() =>
      '<$tagName${id != null ? ' id="$id"' : ''}'
      '${classes.isNotEmpty ? ' class="${classes.join(' ')}"' : ''}>';

  static const Set<String> _blockTags = {
    'address', 'article', 'aside', 'blockquote', 'br', 'dd', 'div', 'dl', 'dt',
    'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3',
    'h4', 'h5', 'h6', 'header', 'hr', 'li', 'main', 'nav', 'ol', 'p', 'pre',
    'section', 'table', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr', 'ul', //
  };

  static void _writeBlockText(dom.Node node, StringBuffer buffer) {
    for (final child in node.nodes) {
      if (child.nodeType == dom.Node.TEXT_NODE) {
        buffer.write(child.text ?? '');
      } else if (child is dom.Element) {
        final isBlock = _blockTags.contains(child.localName);
        if (isBlock) buffer.write('\n');
        _writeBlockText(child, buffer);
        if (isBlock) buffer.write('\n');
      }
    }
  }
}

String _normalizeWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();
