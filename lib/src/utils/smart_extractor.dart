import '../dom/html_document.dart';
import '../dom/url_resolver.dart';

/// OpenGraph metadata from a page.
class OpenGraphData {
  /// Creates an OpenGraph record.
  const OpenGraphData({
    this.title,
    this.description,
    this.image,
    this.url,
    this.type,
    this.siteName,
  });

  /// `og:title`.
  final String? title;

  /// `og:description`.
  final String? description;

  /// `og:image`, resolved to an absolute URL.
  final String? image;

  /// `og:url`.
  final String? url;

  /// `og:type`.
  final String? type;

  /// `og:site_name`.
  final String? siteName;

  /// Whether any field was found.
  bool get isEmpty =>
      title == null &&
      description == null &&
      image == null &&
      url == null &&
      type == null &&
      siteName == null;

  @override
  String toString() => 'OpenGraphData(title: $title, siteName: $siteName)';
}

/// What [SmartExtractor] found on a page.
class SmartContent {
  /// Creates a content record.
  const SmartContent({
    this.title,
    this.description,
    this.content,
    this.author,
    this.publishDate,
    this.canonicalUrl,
    this.images = const [],
    this.links = const [],
    this.emails = const [],
    this.headings = const [],
    this.openGraph,
  });

  /// Best available page title.
  final String? title;

  /// Best available summary.
  final String? description;

  /// Main body text.
  final String? content;

  /// Author, when the page names one.
  final String? author;

  /// Publication date as the page stated it, unparsed.
  ///
  /// Normalising this to a `DateTime` is Phase 6's `date_normalizer`; handing
  /// back the raw value keeps the information the page actually carried.
  final String? publishDate;

  /// `<link rel="canonical">`, resolved absolute.
  final String? canonicalUrl;

  /// Absolute image URLs.
  final List<String> images;

  /// Absolute link URLs.
  final List<String> links;

  /// Email addresses found in `mailto:` links.
  final List<String> emails;

  /// Headings in document order.
  final List<Heading> headings;

  /// OpenGraph metadata, when present.
  final OpenGraphData? openGraph;

  @override
  String toString() => 'SmartContent(title: $title, images: ${images.length}, '
      'links: ${links.length}, headings: ${headings.length})';
}

/// A heading and its level.
class Heading {
  /// Creates a heading.
  const Heading(this.level, this.text);

  /// 1 for `<h1>` through 6 for `<h6>`.
  final int level;

  /// The heading's text.
  final String text;

  @override
  String toString() => '${'#' * level} $text';
}

/// Pulls common fields out of a page using layered fallbacks.
///
/// Every method here reads the DOM. The 1.x implementation matched raw HTML
/// with regular expressions, which produced values like
/// `https://example.com/pic.jpg"` — the closing quote captured into the URL —
/// because a pattern has no idea where an attribute ends.
///
/// Two 1.x features are deliberately absent:
///
/// - **Price extraction** stamped a `$` on every match regardless of the real
///   currency, so `€99` came back as `$99`. Fabricating currency is worse than
///   returning nothing; proper money parsing arrives with Phase 2's structured
///   data and Phase 6's `money_normalizer`.
/// - **Phone extraction** used a pattern loose enough to match dates, SKUs and
///   IDs. It is gone until it can be done with real region-aware parsing.
abstract final class SmartExtractor {
  /// Extracts every supported field from [document].
  static SmartContent extractAll(HtmlDocument document) {
    final openGraph = extractOpenGraph(document);
    return SmartContent(
      title: extractTitle(document, openGraph: openGraph),
      description: extractDescription(document, openGraph: openGraph),
      content: extractMainContent(document),
      author: extractAuthor(document),
      publishDate: extractPublishDate(document),
      canonicalUrl: extractCanonicalUrl(document),
      images: extractImages(document),
      links: extractLinks(document),
      emails: extractEmails(document),
      headings: extractHeadings(document),
      openGraph: openGraph?.isEmpty ?? true ? null : openGraph,
    );
  }

  /// The page title: OpenGraph, then `<title>`, then the first `<h1>`.
  static String? extractTitle(
    HtmlDocument document, {
    OpenGraphData? openGraph,
  }) {
    final og = (openGraph ?? extractOpenGraph(document))?.title;
    if (_isUseful(og)) return og;

    final title = document.title;
    if (_isUseful(title)) return title;

    final heading = document.selectFirst('h1')?.text;
    return _isUseful(heading) ? heading : null;
  }

  /// The page summary: OpenGraph, `<meta name="description">`, Twitter, then
  /// the first substantial paragraph.
  static String? extractDescription(
    HtmlDocument document, {
    OpenGraphData? openGraph,
  }) {
    final og = (openGraph ?? extractOpenGraph(document))?.description;
    if (_isUseful(og)) return og;

    for (final name in const ['description', 'twitter:description']) {
      final value = document.meta(name);
      if (_isUseful(value)) return value;
    }

    for (final paragraph in document.select('p')) {
      final text = paragraph.text;
      if (text.length >= 50) return text;
    }
    return null;
  }

  /// The main body text.
  ///
  /// Tries the semantic containers first, then the conventional class names,
  /// and keeps whichever candidate holds the most text. Full readability
  /// scoring — link density, paragraph weight, negative class patterns —
  /// arrives in Phase 2.
  static String? extractMainContent(HtmlDocument document) {
    const candidates = [
      'article',
      'main',
      '[role=main]',
      '.post-content',
      '.entry-content',
      '.article-body',
      '.content',
      '#content',
    ];

    String? best;
    var bestLength = 0;

    for (final selector in candidates) {
      for (final node in document.select(selector)) {
        final text = node.blockText;
        if (text.length > bestLength) {
          bestLength = text.length;
          best = text;
        }
      }
    }

    if (best != null && bestLength >= 100) return best;

    // Nothing structural stood out: fall back to the paragraphs themselves.
    final paragraphs = document
        .select('p')
        .map((p) => p.text)
        .where((t) => t.length > 40)
        .toList();

    return paragraphs.isEmpty ? best : paragraphs.join('\n\n');
  }

  /// The author, when the page names one.
  static String? extractAuthor(HtmlDocument document) {
    for (final name in const ['author', 'article:author', 'twitter:creator']) {
      final value = document.meta(name);
      if (_isUseful(value)) return value;
    }

    for (final selector in const [
      '[rel=author]',
      '[itemprop=author]',
      '.author-name',
      '.author',
      '.byline',
    ]) {
      final text = document.selectFirst(selector)?.text;
      if (_isUseful(text) && text!.length < 120) return text;
    }
    return null;
  }

  /// The publication date, as the page stated it.
  static String? extractPublishDate(HtmlDocument document) {
    for (final name in const [
      'article:published_time',
      'datePublished',
      'date',
    ]) {
      final value = document.meta(name);
      if (_isUseful(value)) return value;
    }

    final time = document.selectFirst('time');
    final dateTime = time?.attr('datetime');
    if (_isUseful(dateTime)) return dateTime;
    if (_isUseful(time?.text)) return time!.text;

    final itemProp = document.selectFirst('[itemprop=datePublished]');
    final content = itemProp?.attr('content') ?? itemProp?.text;
    return _isUseful(content) ? content : null;
  }

  /// The canonical URL, resolved absolute.
  static String? extractCanonicalUrl(HtmlDocument document) =>
      document.selectFirst('link[rel=canonical]')?.absoluteUrl('href') ??
      extractOpenGraph(document)?.url;

  /// Absolute image URLs, deduplicated and in document order.
  ///
  /// Reads `srcset` and the common lazy-loading attributes too, since a great
  /// many sites put nothing useful in `src` until JavaScript runs.
  static List<String> extractImages(HtmlDocument document) {
    final images = <String>{};

    for (final img in document.select('img')) {
      for (final attribute in const [
        'src',
        'data-src',
        'data-original',
        'data-lazy-src',
      ]) {
        final url = img.absoluteUrl(attribute);
        if (url != null) {
          images.add(url);
          break;
        }
      }

      // srcset: "url 1x, url 2x" — take the first candidate.
      final srcset = img.attr('srcset');
      if (srcset != null && srcset.isNotEmpty) {
        final first = srcset.split(',').first.trim().split(RegExp(r'\s+')).first;
        final resolved = img.resolveUrl(first);
        if (resolved != null) images.add(resolved);
      }
    }

    final ogImage = extractOpenGraph(document)?.image;
    if (ogImage != null) images.add(ogImage);

    return images.toList(growable: false);
  }

  /// Absolute link URLs, deduplicated and in document order.
  static List<String> extractLinks(HtmlDocument document) {
    final links = <String>{};
    for (final anchor in document.select('a[href]')) {
      final url = anchor.absoluteUrl('href');
      if (url != null) links.add(url);
    }
    return links.toList(growable: false);
  }

  /// Email addresses, from `mailto:` links first and then from visible text.
  ///
  /// Contact pages routinely print an address as plain text rather than
  /// linking it, so text is scanned too — but only *visible* text, taken from
  /// a sanitized copy, and filtered against [_assetExtensions]. 1.x matched
  /// anything `@`-shaped anywhere in the raw HTML, which swept up asset
  /// filenames like `logo@2x.png` and strings inside `<script>` blocks.
  static List<String> extractEmails(HtmlDocument document) {
    final emails = <String>{};

    for (final anchor in document.select('a[href]')) {
      final href = anchor.attr('href');
      if (href == null || !href.toLowerCase().startsWith('mailto:')) continue;

      final address = Uri.decodeFull(href.substring(7).split('?').first).trim();
      if (_looksLikeEmail(address)) emails.add(address);
    }

    // A sanitized copy, so script and style bodies are never scanned.
    final visibleText =
        HtmlDocument.parse(document.raw.outerHtml).sanitize().text;
    for (final match in _emailPattern.allMatches(visibleText)) {
      final address = match.group(0)!;
      if (_looksLikeEmail(address)) emails.add(address);
    }

    return emails.toList(growable: false);
  }

  static final RegExp _emailPattern = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,24}',
  );

  /// File extensions that make an `@`-shaped string an asset, not an address.
  ///
  /// `logo@2x.png` and `sprite@3x.svg` are the common offenders.
  static const Set<String> _assetExtensions = {
    'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'avif', 'ico', 'bmp',
    'css', 'js', 'mjs', 'json', 'xml', 'map',
    'woff', 'woff2', 'ttf', 'otf', 'eot',
    'mp4', 'webm', 'mp3', 'wav', 'pdf', 'zip', 'gz', //
  };

  static bool _looksLikeEmail(String value) {
    if (!_emailPattern.hasMatch(value)) return false;
    if (value.length > 254) return false;

    final tld = value.split('.').last.toLowerCase();
    return !_assetExtensions.contains(tld);
  }

  /// Headings in document order.
  static List<Heading> extractHeadings(HtmlDocument document) => document
      .select('h1, h2, h3, h4, h5, h6')
      .map((node) {
        final level = int.tryParse(node.tagName.substring(1)) ?? 1;
        return Heading(level, node.text);
      })
      .where((h) => h.text.isNotEmpty)
      .toList(growable: false);

  /// OpenGraph metadata, or `null` when the page has none.
  static OpenGraphData? extractOpenGraph(HtmlDocument document) {
    final image = document.meta('og:image');

    final data = OpenGraphData(
      title: document.meta('og:title'),
      description: document.meta('og:description'),
      image: image == null
          ? null
          : UrlResolver.resolve(image, document.baseUrl) ?? image,
      url: document.meta('og:url'),
      type: document.meta('og:type'),
      siteName: document.meta('og:site_name'),
    );

    return data.isEmpty ? null : data;
  }

  static bool _isUseful(String? value) =>
      value != null && value.trim().isNotEmpty;
}
