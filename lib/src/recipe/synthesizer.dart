/// AI-driven selector recipe synthesizer with candidate self-verification.
library;

import '../ai/ai_provider.dart';
import '../dom/html_document.dart';
import '../schema/field.dart';
import '../schema/schema.dart';
import 'recipe.dart';
import 'runner.dart';
import 'skeleton.dart';

/// Synthesizes CSS extraction recipes using structural DOM skeletons and language models.
abstract final class RecipeSynthesizer {
  /// Synthesizes and self-verifies a [Recipe] for [document] conforming to [schema].
  ///
  /// Returns `null` if the model's candidate selectors fail verification against the source page.
  static Future<Recipe?> synthesize(
    HtmlDocument document,
    Schema schema, {
    required AiProvider provider,
    String? host,
  }) async {
    final skeleton = StructuralSkeleton.build(document);
    final targetHost = host ?? _extractHost(document.url ?? '');
    final schemaHash = Recipe.hashSchema(schema);

    final recipeSchema = _buildRecipeMetaSchema(schema);
    final result = await provider.extract(recipeSchema, skeleton);

    if (!result.isSuccessful || result.data == null) {
      return null;
    }

    final data = result.data as Map<String, dynamic>;
    final containerSelector = data['containerSelector']?.toString();
    final fieldsRaw = data['fields'] as Map<String, dynamic>? ?? {};

    final fields = <String, FieldSelector>{};
    for (final entry in fieldsRaw.entries) {
      if (entry.value is Map) {
        final fMap = entry.value as Map;
        fields[entry.key] = FieldSelector(
          selector: fMap['selector']?.toString() ?? '',
          attribute: fMap['attribute']?.toString() ?? 'text',
          regex: fMap['regex']?.toString(),
        );
      }
    }

    if (fields.isEmpty) return null;

    final candidate = Recipe(
      id: 'recipe_${DateTime.now().millisecondsSinceEpoch}',
      host: targetHost,
      schemaHash: schemaHash,
      containerSelector:
          containerSelector != null && containerSelector.trim().isNotEmpty
              ? containerSelector.trim()
              : null,
      fields: fields,
      confidence: result.confidence ?? 0.90,
    );

    // Verify before storing: execute candidate against source page
    final verification = RecipeRunner.run(candidate, document, schema);

    if (verification.driftDetected || verification.yieldCount == 0) {
      // Candidate recipe failed verification on the source page itself
      return null;
    }

    return candidate;
  }

  static Schema _buildRecipeMetaSchema(Schema targetSchema) {
    final Map<String, dynamic> targetProperties;

    if (targetSchema is ObjectSchema) {
      targetProperties = targetSchema.properties;
    } else if (targetSchema is ListSchema &&
        targetSchema.itemSchema is ObjectSchema) {
      targetProperties =
          (targetSchema.itemSchema as ObjectSchema).properties;
    } else {
      targetProperties = {'item': const Field.string()};
    }

    final fieldSpecs = <String, dynamic>{};
    for (final key in targetProperties.keys) {
      fieldSpecs[key] = Schema.object({
        'selector': const Field.string(
          description: 'CSS selector relative to container or document',
        ),
        'attribute': const Field.string(
          description: 'Attribute name (text, href, src)',
          required: false,
        ),
        'regex': const Field.string(
          description: 'Optional regex pattern to isolate text',
          required: false,
        ),
      }, required: const ['selector']);
    }

    return Schema.object({
      'containerSelector': const Field.string(
        description: 'CSS selector matching each repeating list item element',
        required: false,
      ),
      'fields': Schema.object(
        fieldSpecs,
        description: 'Selectors for each target schema property',
      ),
    }, title: 'synthesize_recipe', description: 'CSS selector extraction recipe');
  }

  static String _extractHost(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty) return uri.host;
    } catch (_) {}
    return 'default.host';
  }
}
