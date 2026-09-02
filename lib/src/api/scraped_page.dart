/// Scraped page representation providing Tier-1 deterministic extraction.
library;

import '../ai/ai_provider.dart';
import '../ai/extractor.dart';
import '../ai/planner.dart';
import '../dom/html_document.dart';
import '../readability/scorer.dart';
import '../recipe/recipe.dart';
import '../recipe/runner.dart';
import '../recipe/store.dart';
import '../recipe/synthesizer.dart';
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

  /// The page title, from OpenGraph, `<title>` or the first `<h1>`.
  ///
  /// A Tier-1 convenience: the single most-requested field should not require
  /// reaching into [document] or unpacking [metadata].
  String? get title => SmartExtractor.extractTitle(document);

  /// The page summary, from OpenGraph, the description meta tag, or the first
  /// substantial paragraph.
  String? get description => SmartExtractor.extractDescription(document);

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

  /// Extracts data conforming to [schema] synchronously via the Tier-1
  /// deterministic structured-data path.
  ///
  /// Short-circuits with zero inference when structured data satisfies the schema.
  /// If fields are missing, returns [StructuredHarvestResult] with `isPartial: true`.
  StructuredHarvestResult extract(Schema schema) =>
      StructuredMapper.mapToSchema(document, schema);

  /// Extracts data conforming to [schema] using an AI [provider] for any fields
  /// not satisfied by deterministic structured data.
  ///
  /// Deterministic structured data always takes precedence over model guesses.
  Future<StructuredHarvestResult> extractWithAi(
    Schema schema, {
    required AiProvider provider,
    ExtractionOptions options = const ExtractionOptions(),
  }) =>
      Extractor(provider).extract(document, schema, options: options);

  /// Asynchronous extraction: uses structured data first, falling back to [provider]
  /// if provided and fields are missing.
  Future<StructuredHarvestResult> extractAsync(
    Schema schema, {
    AiProvider? provider,
    ExtractionOptions options = const ExtractionOptions(),
  }) async {
    if (provider == null) {
      return extract(schema);
    }
    return extractWithAi(schema, provider: provider, options: options);
  }

  /// Asks a natural-language question against the page, automatically inferring a
  /// typed extraction schema and using cached CSS selector recipes when available.
  Future<AskResult> ask(
    String question, {
    required AiProvider provider,
    RecipeStore? recipeStore,
    ExtractionOptions options = const ExtractionOptions(),
  }) async {
    final planned = await Planner.plan(question, provider: provider);
    final schema = planned.schema;
    final host = Uri.tryParse(url)?.host ?? '';
    final schemaHash = Recipe.hashSchema(schema);

    // 1. Check RecipeStore for zero-AI execution
    if (recipeStore != null && host.isNotEmpty) {
      final cachedRecipe = recipeStore.get(host, schemaHash);
      if (cachedRecipe != null) {
        final runResult = RecipeRunner.run(cachedRecipe, document, schema);
        if (!runResult.driftDetected && runResult.yieldCount > 0) {
          return AskResult(
            data: runResult.harvestResult.data,
            planned: planned,
            harvestResult: runResult.harvestResult,
          );
        }
      }
    }

    // 2. Fall back to AI extraction pipeline
    final harvest = await extractWithAi(schema, provider: provider, options: options);

    // 3. Synthesize and cache recipe for future zero-cost pages
    if (recipeStore != null && host.isNotEmpty && harvest.coverage.satisfiedCount > 0) {
      try {
        final synthesized = await RecipeSynthesizer.synthesize(
          document,
          schema,
          provider: provider,
          host: host,
        );
        if (synthesized != null) {
          recipeStore.put(synthesized);
        }
      } catch (_) {}
    }

    return AskResult(
      data: harvest.data,
      planned: planned,
      harvestResult: harvest,
    );
  }
}

/// Result of a natural-language extraction query.
class AskResult {
  /// Creates an [AskResult].
  const AskResult({
    required this.data,
    required this.planned,
    required this.harvestResult,
  });

  /// The extracted structured data payload.
  final Map<String, dynamic> data;

  /// The inferred schema and extraction plan.
  final PlannedExtraction planned;

  /// Underlying harvest result with provenance metadata.
  final StructuredHarvestResult harvestResult;
}
