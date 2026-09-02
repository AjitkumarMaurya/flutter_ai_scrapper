/// Pure CSS selector execution engine with zero model inference.
library;

import 'package:html/dom.dart' as dom;

import '../dom/html_document.dart';
import '../schema/schema.dart';
import '../structured/mapper.dart';
import 'recipe.dart';

/// Result of executing a [Recipe] against a document.
class RecipeRunResult {
  /// Creates a [RecipeRunResult].
  const RecipeRunResult({
    required this.harvestResult,
    required this.driftDetected,
    required this.yieldCount,
  });

  /// The mapped and validated structured harvest payload.
  final StructuredHarvestResult harvestResult;

  /// Whether site markup drift was detected (e.g. selectors matching 0 elements).
  final bool driftDetected;

  /// Number of non-empty items or fields extracted.
  final int yieldCount;
}

/// Pure-CSS extraction engine running cached site recipes with zero inference.
abstract final class RecipeRunner {
  /// Executes [recipe] against [document], producing a typed [RecipeRunResult].
  static RecipeRunResult run(
    Recipe recipe,
    HtmlDocument document,
    Schema schema,
  ) {
    if (recipe.containerSelector != null) {
      return _runListRecipe(recipe, document, schema);
    } else {
      return _runObjectRecipe(recipe, document, schema);
    }
  }

  static RecipeRunResult _runListRecipe(
    Recipe recipe,
    HtmlDocument document,
    Schema schema,
  ) {
    final containers = document.raw.querySelectorAll(recipe.containerSelector!);
    if (containers.isEmpty) {
      // Container selector matched nothing: structural site drift detected!
      final val = schema.validate(<dynamic>[]);
      return RecipeRunResult(
        harvestResult: StructuredHarvestResult(
          data: const <String, dynamic>{'items': <dynamic>[]},
          coverage: const ExtractionCoverage(
            satisfiedFields: {},
            missingFields: ['items'],
          ),
          validation: val,
        ),
        driftDetected: true,
        yieldCount: 0,
      );
    }

    final items = <Map<String, dynamic>>[];

    for (final container in containers) {
      final item = <String, dynamic>{};
      for (final entry in recipe.fields.entries) {
        final fieldName = entry.key;
        final selector = entry.value;

        final value = _extractValue(container, selector);
        if (value != null) {
          item[fieldName] = value;
        }
      }
      if (item.isNotEmpty) {
        items.add(item);
      }
    }

    final validation = schema.validate(items);
    final isDrift = items.isEmpty;

    final satisfied = <String, ExtractionSource>{};
    if (items.isNotEmpty) {
      satisfied['items'] = ExtractionSource.recipe;
    }

    return RecipeRunResult(
      harvestResult: StructuredHarvestResult(
        data: {'items': validation.coerced ?? items},
        coverage: ExtractionCoverage(
          satisfiedFields: satisfied,
          missingFields: items.isEmpty ? ['items'] : const [],
        ),
        validation: validation,
      ),
      driftDetected: isDrift,
      yieldCount: items.length,
    );
  }

  static RecipeRunResult _runObjectRecipe(
    Recipe recipe,
    HtmlDocument document,
    Schema schema,
  ) {
    final rawData = <String, dynamic>{};
    final satisfied = <String, ExtractionSource>{};
    final missing = <String>[];

    for (final entry in recipe.fields.entries) {
      final fieldName = entry.key;
      final selector = entry.value;

      final value = _extractValue(document.raw.documentElement, selector);
      if (value != null && value.toString().trim().isNotEmpty) {
        rawData[fieldName] = value;
        satisfied[fieldName] = ExtractionSource.recipe;
      } else {
        missing.add(fieldName);
      }
    }

    final validation = schema.validate(rawData);
    // Drift if all selectors fail to extract any data
    final isDrift = rawData.isEmpty && recipe.fields.isNotEmpty;

    return RecipeRunResult(
      harvestResult: StructuredHarvestResult(
        data: validation.coerced is Map<String, dynamic>
            ? validation.coerced as Map<String, dynamic>
            : rawData,
        coverage: ExtractionCoverage(
          satisfiedFields: satisfied,
          missingFields: missing,
        ),
        validation: validation,
      ),
      driftDetected: isDrift,
      yieldCount: rawData.length,
    );
  }

  static dynamic _extractValue(dom.Element? root, FieldSelector selector) {
    if (root == null) return null;

    final target = selector.selector.isEmpty
        ? root
        : root.querySelector(selector.selector);
    if (target == null) return null;

    String? raw;
    if (selector.attribute == 'text') {
      raw = target.text.trim();
    } else {
      raw = target.attributes[selector.attribute]?.trim();
    }

    if (raw == null || raw.isEmpty) return null;

    if (selector.regex != null) {
      final match = RegExp(selector.regex!).firstMatch(raw);
      if (match != null) {
        if (match.groupCount >= 1) {
          return match.group(1)?.trim();
        }
        return match.group(0)?.trim();
      }
      return null;
    }

    return raw;
  }
}
