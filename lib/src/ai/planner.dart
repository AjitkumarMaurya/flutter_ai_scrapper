/// Natural-language schema planning and intent inference.
library;

import '../schema/field.dart';
import '../schema/schema.dart';
import 'ai_provider.dart';

/// Result of planning a typed [Schema] from a natural-language query.
class PlannedExtraction {
  /// Creates a [PlannedExtraction].
  const PlannedExtraction({
    required this.schema,
    required this.isList,
    required this.intent,
  });

  /// The inferred structured schema.
  final Schema schema;

  /// Whether the request targets a list of entities rather than a single entity.
  final bool isList;

  /// Human-readable explanation of the inferred extraction intent.
  final String intent;

  @override
  String toString() => 'PlannedExtraction(isList: $isList, intent: "$intent")';
}

/// Translates natural language prompts into typed extraction schemas.
abstract final class Planner {
  /// Plans a [Schema] from a natural language [prompt].
  ///
  /// Uses rule-based NLP heuristics with optional [provider] refinement.
  static Future<PlannedExtraction> plan(
    String prompt, {
    AiProvider? provider,
  }) async {
    final lower = prompt.toLowerCase();

    // 1. Cardinality inference
    final isList = lower.contains('all') ||
        lower.contains('list of') ||
        lower.contains('every') ||
        lower.contains('each') ||
        lower.contains('table of') ||
        lower.contains('catalog') ||
        lower.contains('jobs') ||
        lower.contains('products') ||
        lower.contains('articles') ||
        lower.contains('events');

    // 2. Field discovery
    final fields = _inferFields(prompt);

    final objectSchema = Schema.object(
      fields,
      title: _inferTitle(prompt),
      description: prompt,
    );

    final schema = isList ? Schema.list(objectSchema) : objectSchema;

    return PlannedExtraction(
      schema: schema,
      isList: isList,
      intent: 'Extracted ${fields.keys.join(", ")} as ${isList ? "list" : "object"}.',
    );
  }

  static Map<String, Field> _inferFields(String prompt) {
    final lower = prompt.toLowerCase();
    final fields = <String, Field>{};

    // Name / Title
    if (lower.contains('title') || lower.contains('headline')) {
      fields['title'] = const Field.string();
    } else if (lower.contains('name')) {
      fields['name'] = const Field.string();
    } else if (lower.contains('product') || lower.contains('article') || lower.contains('job')) {
      fields['title'] = const Field.string();
    }

    // Money / Price
    if (lower.contains('price') ||
        lower.contains('cost') ||
        lower.contains('fee') ||
        lower.contains('rate') ||
        lower.contains('salary')) {
      fields['price'] = const Field.money();
    }

    // Number / Rating
    if (lower.contains('rating') ||
        lower.contains('score') ||
        lower.contains('review')) {
      fields['rating'] = const Field.number();
    }

    // Date
    if (lower.contains('date') ||
        lower.contains('published') ||
        lower.contains('time') ||
        lower.contains('posted')) {
      fields['date'] = const Field.date();
    }

    // URL / Links
    if (lower.contains('link') ||
        lower.contains('url') ||
        lower.contains('image') ||
        lower.contains('href')) {
      fields['url'] = const Field.url();
    }

    // Author / Byline
    if (lower.contains('author') || lower.contains('byline') || lower.contains('writer')) {
      fields['author'] = const Field.string();
    }

    // SKU / ID
    if (lower.contains('sku') || lower.contains('id') || lower.contains('code')) {
      fields['id'] = const Field.string();
    }

    // Description / Summary
    if (lower.contains('description') || lower.contains('summary') || lower.contains('details')) {
      fields['description'] = const Field.string();
    }

    // Fallback defaults if no specific keywords matched
    if (fields.isEmpty) {
      fields['title'] = const Field.string();
      fields['content'] = const Field.string();
    }

    return fields;
  }

  static String _inferTitle(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('product')) return 'Product';
    if (lower.contains('article') || lower.contains('news')) return 'Article';
    if (lower.contains('job')) return 'Job';
    if (lower.contains('event')) return 'Event';
    if (lower.contains('recipe')) return 'Recipe';
    return 'ExtractedItem';
  }
}
