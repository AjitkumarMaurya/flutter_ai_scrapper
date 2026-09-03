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
    this.timeout,
    this.listDeduplicationKey,
    this.maxListChunks = 5,
  });

  /// Wall-clock budget for the AI stage, or `null` to derive it from the
  /// provider.
  ///
  /// Leave this unset. A single constant cannot serve both paths: measured on a
  /// mid-range Android phone, a 0.6B model spent **38.6 seconds** on prefill
  /// alone, so the old fixed 30-second default meant on-device extraction could
  /// never finish — it timed out on every run and silently returned the
  /// deterministic result, which looked exactly like "the AI contributed
  /// nothing". See [budgetFor].
  final Duration? timeout;

  /// The budget to allow a given provider.
  ///
  /// An explicit [timeout] always wins. Otherwise a local model gets
  /// [localBudget], because it is slow but free and cannot leave the device;
  /// a network provider gets [remoteBudget], because a request that hangs that
  /// long is a request worth abandoning.
  Duration budgetFor(AiProvider provider) =>
      timeout ??
      (provider.capabilities.isLocal ? localBudget : remoteBudget);

  /// Default budget for on-device inference.
  ///
  /// Generous on purpose: a phone doing a cold model load plus prefill can
  /// legitimately take a minute or more, and cutting it off wastes the work
  /// already done.
  static const Duration localBudget = Duration(minutes: 5);

  /// Default budget for a network provider.
  static const Duration remoteBudget = Duration(seconds: 45);

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

    final budget = options.budgetFor(provider);

    try {
      return await _runAiExtraction(
        document,
        schema,
        harvestResult,
        options,
      ).timeout(
        budget,
        onTimeout: () => harvestResult.withAiOutcome(
          AiOutcome.timedOut(provider.id, budget),
        ),
      );
    } on Object catch (error) {
      // Degrading to the deterministic result is right — a failed model must
      // never fail the whole extraction. Discarding *why* is not: the previous
      // bare `catch (_)` made an AI stage that never completed look identical
      // to one that ran and found nothing, which is undebuggable from the
      // outside and cost real time to diagnose on a device.
      return harvestResult.withAiOutcome(
        AiOutcome.failed(provider.id, error.toString()),
      );
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
      // Ran, but produced nothing usable — distinct from never running.
      return harvestResult.withAiOutcome(
        AiOutcome.failed(
          provider.id,
          aiResult.error ?? 'returned no usable data',
        ),
      );
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
      aiOutcome: AiOutcome.succeeded(provider.id, usage: aiResult.usage),
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
