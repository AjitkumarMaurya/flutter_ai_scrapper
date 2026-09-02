/// Orchestrates multi-stage extraction across structured harvesting and model inference.
library;

import 'dart:async';

import '../dom/html_document.dart';
import '../reduce/bm25_ranker.dart';
import '../reduce/budget.dart';
import '../reduce/chunker.dart';
import '../reduce/markdown_writer.dart';
import '../schema/schema.dart';
import '../structured/mapper.dart';
import 'ai_provider.dart';

/// Configuration options for the AI extraction pipeline.
class ExtractionOptions {
  /// Creates extraction options.
  const ExtractionOptions({
    this.timeout = const Duration(seconds: 30),
    this.listDeduplicationKey,
    this.maxListChunks = 5,
  });

  /// Wall-clock timeout after which partial results are gracefully returned.
  final Duration timeout;

  /// Property key to use for list item deduplication (e.g. `'id'`, `'sku'`, `'name'`).
  final String? listDeduplicationKey;

  /// Maximum number of document chunks to evaluate in map-reduce list extraction.
  final int maxListChunks;
}

/// Orchestrates multi-stage extraction: deterministic harvesting first, AI inference fallback.
class Extractor {
  /// Creates an [Extractor] with the specified [provider].
  const Extractor(this.provider);

  /// The underlying language model provider.
  final AiProvider provider;

  /// Extracts structured data conforming to [schema] from [document].
  ///
  /// Stages:
  /// 1. **Structured Data Harvesting**: JSON-LD, Microdata, RDFa Lite, OpenGraph.
  ///    If this satisfies all required fields, returns immediately with zero AI inference.
  /// 2. **AI Inference Fallback**: Missing fields are extracted via [provider] using
  ///    structure-preserving Markdown chunks ranked by BM25.
  /// 3. **Provenance Merging**: Deterministic sources always take precedence over AI guesses.
  Future<StructuredHarvestResult> extract(
    HtmlDocument document,
    Schema schema, {
    ExtractionOptions options = const ExtractionOptions(),
  }) async {
    // Stage 1: Deterministic harvest (always runs first, zero inference)
    final harvestResult = StructuredMapper.mapToSchema(document, schema);
    if (harvestResult.coverage.isComplete) {
      return harvestResult;
    }

    try {
      return await _runAiExtraction(
        document,
        schema,
        harvestResult,
        options,
      ).timeout(
        options.timeout,
        onTimeout: () => harvestResult, // Gracefully return partial harvest on timeout
      );
    } catch (_) {
      // If AI extraction throws, degrade gracefully to the deterministic result
      return harvestResult;
    }
  }

  Future<StructuredHarvestResult> _runAiExtraction(
    HtmlDocument document,
    Schema schema,
    StructuredHarvestResult harvestResult,
    ExtractionOptions options,
  ) async {
    final markdown = MarkdownWriter.convert(document);
    final budget = TokenBudget.fromProvider(provider);

    if (schema is ObjectSchema) {
      return _extractObject(
        markdown,
        schema,
        harvestResult,
        budget,
      );
    } else if (schema is ListSchema) {
      return _extractList(
        markdown,
        schema,
        harvestResult,
        budget,
        options,
      );
    }

    return harvestResult;
  }

  Future<StructuredHarvestResult> _extractObject(
    String markdown,
    ObjectSchema schema,
    StructuredHarvestResult harvestResult,
    TokenBudget budget,
  ) async {
    final missingFields = harvestResult.coverage.missingFields;
    if (missingFields.isEmpty) return harvestResult;

    // Build sub-schema for only missing fields
    final missingProperties = <String, dynamic>{};
    for (final field in missingFields) {
      if (schema.properties.containsKey(field)) {
        missingProperties[field] = schema.properties[field]!;
      }
    }

    final query = missingFields.join(' ');
    final chunks = Chunker.chunk(
      markdown,
      maxTokens: 300,
      overlapTokens: 50,
    );

    final ranked = Bm25Ranker.rank(chunks, query);
    final selectedChunks = budget.select(ranked, preserveDocumentOrder: true);
    final contextText = selectedChunks.map((c) => c.text).join('\n\n---\n\n');

    final subSchema = Schema.object(
      missingProperties,
      title: schema.title,
      description: schema.description,
    );

    final aiResult = await provider.extract(subSchema, contextText);
    if (!aiResult.isSuccessful || aiResult.data == null) {
      return harvestResult;
    }

    final aiData = aiResult.data;
    final mergedData = Map<String, dynamic>.from(harvestResult.data);
    final satisfied = Map<String, ExtractionSource>.from(
      harvestResult.coverage.satisfiedFields,
    );
    final missing = List<String>.from(harvestResult.coverage.missingFields);

    if (aiData is Map) {
      for (final entry in aiData.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        // Invariant: deterministic sources ALWAYS win over AI guesses
        if (!satisfied.containsKey(key) && value != null) {
          mergedData[key] = value;
          satisfied[key] = ExtractionSource.ai;
          missing.remove(key);
        }
      }
    }

    final newCoverage = ExtractionCoverage(
      satisfiedFields: satisfied,
      missingFields: missing,
    );
    final validation = schema.validate(mergedData);

    return StructuredHarvestResult(
      data: mergedData,
      coverage: newCoverage,
      validation: validation,
    );
  }

  Future<StructuredHarvestResult> _extractList(
    String markdown,
    ListSchema schema,
    StructuredHarvestResult harvestResult,
    TokenBudget budget,
    ExtractionOptions options,
  ) async {
    final chunks = Chunker.chunk(
      markdown,
      maxTokens: 350,
      overlapTokens: 50,
    );

    if (chunks.isEmpty) return harvestResult;

    // Map-reduce across document chunks
    final evaluatedChunks = chunks.take(options.maxListChunks);
    final collectedItems = <dynamic>[];

    for (final chunk in evaluatedChunks) {
      final aiResult = await provider.extract(schema, chunk.text);
      if (aiResult.isSuccessful && aiResult.data is List) {
        collectedItems.addAll(aiResult.data as List);
      }
    }

    // Deduplicate items by key
    final deduplicated = _deduplicateList(
      collectedItems,
      options.listDeduplicationKey,
    );

    final satisfied = <String, ExtractionSource>{};
    if (deduplicated.isNotEmpty) {
      satisfied['items'] = ExtractionSource.ai;
    }

    final validation = schema.validate(deduplicated);
    final fullData = <String, dynamic>{'items': validation.coerced ?? deduplicated};

    return StructuredHarvestResult(
      data: fullData,
      coverage: ExtractionCoverage(
        satisfiedFields: satisfied,
        missingFields: deduplicated.isEmpty ? ['items'] : const [],
      ),
      validation: validation,
    );
  }

  List<dynamic> _deduplicateList(List<dynamic> items, String? userKey) {
    if (items.isEmpty) return items;

    final seen = <dynamic>{};
    final result = <dynamic>[];

    for (final item in items) {
      if (item is Map) {
        final key = userKey ?? _inferItemKey(item);
        final val = key != null ? item[key] : null;
        final identifier = val ?? item.toString();

        if (seen.add(identifier)) {
          result.add(item);
        }
      } else {
        if (seen.add(item)) {
          result.add(item);
        }
      }
    }

    return result;
  }

  String? _inferItemKey(Map<dynamic, dynamic> item) {
    for (final candidate in const ['id', 'sku', 'title', 'name', 'url']) {
      if (item.containsKey(candidate) && item[candidate] != null) {
        return candidate;
      }
    }
    return null;
  }
}
