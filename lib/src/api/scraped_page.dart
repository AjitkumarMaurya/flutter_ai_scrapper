/// Scraped page representation providing Tier-1 deterministic extraction.
library;

import '../dom/html_document.dart';
import '../readability/scorer.dart';
import '../schema/schema.dart';
import '../structured/json_ld.dart';
import '../structured/mapper.dart';
import '../structured/microdata.dart';
import '../structured/open_graph.dart';
import '../structured/rdfa.dart';
import '../utils/content_formatter.dart';
import '../utils/smart_extractor.dart';

/// A loaded and parsed web page, exposing Tier-1 deterministic extraction methods.
class ScrapedPage {
  /// Creates a [ScrapedPage].
  const ScrapedPage({
    required this.url,
    required this.document,
    this.statusCode = 200,
    this.headers = const {},
  });

  /// The final URL of the page after any redirects.
  final String url;

  /// The parsed HTML DOM document.
  final HtmlDocument document;

  /// HTTP status code from the fetch response.
  final int statusCode;

  /// Response headers.
  final Map<String, String> headers;

  /// The main article body, extracted using the Readability scoring engine.
  Article article() => ReadabilityScorer.extractArticle(document);

  /// The page rendered as GitHub-Flavoured Markdown.
  String get markdown => ContentFormatter.toMarkdown(document);

  /// The page rendered as clean, block-structured plain text.
  String get plainText => ContentFormatter.toPlainText(document);

  /// All harvested structured metadata (JSON-LD, Microdata, RDFa, OpenGraph).
  Map<String, dynamic> get metadata => {
        'openGraph': OpenGraphHarvester.extract(document),
        'jsonLd': JsonLdHarvester.extract(document),
        'microdata': MicrodataHarvester.extract(document),
        'rdfa': RdfaHarvester.extract(document),
      };

  /// Absolute link URLs discovered across the page.
  List<String> get links => SmartExtractor.extractLinks(document);

  /// Absolute image URLs discovered across the page.
  List<String> get images => SmartExtractor.extractImages(document);

  /// Structured tables on the page.
  List<ExtractedTable> get tables => ContentFormatter.extractTables(document);

  /// Extracts data conforming to [schema] via the deterministic structured-data path.
  ///
  /// Short-circuits with zero inference when structured data satisfies the schema.
  /// If fields are missing, returns [StructuredHarvestResult] with `isPartial: true`.
  StructuredHarvestResult extract(Schema schema) =>
      StructuredMapper.mapToSchema(document, schema);
}
