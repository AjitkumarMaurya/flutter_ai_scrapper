/// Structured data mapper that projects harvested metadata onto a target Schema.
library;

import '../ai/ai_provider.dart';
import '../dom/html_document.dart';
import '../schema/field.dart';
import '../schema/schema.dart';
import 'json_ld.dart';
import 'microdata.dart';
import 'open_graph.dart';
import 'rdfa.dart';

/// Provenance sources for extracted data.
enum ExtractionSource {
  /// Schema.org metadata from `<script type="application/ld+json">`.
  jsonLd,

  /// W3C Microdata attributes (`itemscope`, `itemprop`).
  microdata,

  /// W3C RDFa Lite attributes (`vocab`, `typeof`, `property`).
  rdfa,

  /// OpenGraph or Twitter Card meta tags.
  openGraph,

  /// Standard HTML meta tags or fallback heuristics.
  heuristic,

  /// Host-specific cached selector recipe.
  recipe,

  /// Language model inference (Gemma or cloud).
  ai;

  /// Whether this source is deterministic (structured markup or rule-based)
  /// as opposed to probabilistic AI inference.
  bool get isDeterministic => this != ExtractionSource.ai;
}

/// Report on which requested schema fields were satisfied from structured data.
class ExtractionCoverage {
  /// Creates an [ExtractionCoverage] report.
  const ExtractionCoverage({
    required this.satisfiedFields,
    required this.missingFields,
  });

  /// Map of field name to the [ExtractionSource] that provided its value.
  final Map<String, ExtractionSource> satisfiedFields;

  /// List of field names that could not be satisfied from structured data.
  final List<String> missingFields;

  /// Whether all requested fields were satisfied.
  bool get isComplete => missingFields.isEmpty;

  /// Number of satisfied fields.
  int get satisfiedCount => satisfiedFields.length;

  /// Total number of requested fields evaluated.
  int get totalCount => satisfiedFields.length + missingFields.length;

  /// Percentage of requested fields satisfied (0.0 to 1.0).
  double get ratio => totalCount == 0 ? 1.0 : satisfiedCount / totalCount;

  @override
  String toString() =>
      'ExtractionCoverage(satisfied: $satisfiedCount/$totalCount, missing: $missingFields)';
}

/// Result of mapping harvested structured data onto a target [Schema].
/// What happened when the AI stage was reached.
///
/// Exists because "the AI contributed nothing" and "the AI never finished" look
/// identical in the data, and telling them apart from the outside was
/// impossible until this was recorded.
class AiOutcome {
  /// Creates an outcome.
  const AiOutcome({
    required this.providerId,
    required this.status,
    this.detail,
    this.budget,
    this.usage,
  });

  /// The AI stage completed and its fields were merged.
  const AiOutcome.succeeded(String providerId, {TokenUsage? usage})
      : this(
          providerId: providerId,
          status: AiStatus.succeeded,
          usage: usage,
        );

  /// The AI stage exceeded its wall-clock budget.
  const AiOutcome.timedOut(String providerId, Duration budget)
      : this(
          providerId: providerId,
          status: AiStatus.timedOut,
          budget: budget,
        );

  /// The AI stage threw.
  const AiOutcome.failed(String providerId, String detail)
      : this(
          providerId: providerId,
          status: AiStatus.failed,
          detail: detail,
        );

  /// Which provider was asked.
  final String providerId;

  /// How it ended.
  final AiStatus status;

  /// Error text, when the stage threw.
  final String? detail;

  /// The budget that was exceeded, when it timed out.
  final Duration? budget;

  /// Tokens the stage consumed, so a caller can meter or display real spend
  /// rather than a figure nothing updates.
  final TokenUsage? usage;

  /// A short explanation suitable for a log line or a diagnostics panel.
  String get message => switch (status) {
        AiStatus.succeeded => '$providerId completed',
        AiStatus.timedOut => '$providerId exceeded its '
            '${budget?.inSeconds}s budget. On-device inference on a mid-range '
            'phone can take longer than this; raise ExtractionOptions.timeout '
            'or use a smaller model.',
        AiStatus.failed => '$providerId failed: $detail',
      };

  @override
  String toString() => 'AiOutcome(${status.name}: $message)';
}

/// How an AI stage ended.
enum AiStatus {
  /// Ran to completion.
  succeeded,

  /// Exceeded its wall-clock budget.
  timedOut,

  /// Threw before producing a result.
  failed,
}

class StructuredHarvestResult {
  /// Creates a [StructuredHarvestResult].
  const StructuredHarvestResult({
    required this.data,
    required this.coverage,
    required this.validation,
    this.aiOutcome,
  });

  /// The mapped and coerced data payload.
  final Map<String, dynamic> data;

  /// Coverage report detailing which fields were satisfied and their sources.
  final ExtractionCoverage coverage;

  /// Schema validation and type coercion result.
  final ValidationResult validation;

  /// What happened at the AI stage, or `null` if it was never reached.
  ///
  /// `null` means the deterministic path satisfied the schema and no inference
  /// was needed — the good case. A non-null value with a non-succeeded status
  /// is why fields are missing.
  final AiOutcome? aiOutcome;

  /// Whether this extraction is partial (fields are missing or schema validation failed).
  bool get isPartial => !coverage.isComplete || !validation.isValid;

  /// Returns a copy carrying [outcome].
  StructuredHarvestResult withAiOutcome(AiOutcome outcome) =>
      StructuredHarvestResult(
        data: data,
        coverage: coverage,
        validation: validation,
        aiOutcome: outcome,
      );

  @override
  String toString() =>
      'StructuredHarvestResult(isPartial: $isPartial, satisfied: ${coverage.satisfiedCount})';
}

/// Maps harvested structured data onto a [Schema].
abstract final class StructuredMapper {
  /// Harvests all structured data from [document] and maps it onto [schema].
  static StructuredHarvestResult mapToSchema(
    HtmlDocument document,
    Schema schema,
  ) {
    if (schema is! ObjectSchema) {
      final val = schema.validate(<dynamic>[]);
      return StructuredHarvestResult(
        data: {},
        coverage: const ExtractionCoverage(
          satisfiedFields: {},
          missingFields: ['items'],
        ),
        validation: val,
      );
    }

    final jsonLdItems = JsonLdHarvester.extract(document);
    final microdataItems = MicrodataHarvester.extract(document);
    final rdfaItems = RdfaHarvester.extract(document);
    final openGraph = OpenGraphHarvester.extract(document);

    // Combine candidate entities with their provenance
    final candidateEntities = <_EntityCandidate>[];

    for (final item in jsonLdItems) {
      candidateEntities.add(_EntityCandidate(item, ExtractionSource.jsonLd));
    }
    for (final item in microdataItems) {
      candidateEntities.add(_EntityCandidate(item, ExtractionSource.microdata));
    }
    for (final item in rdfaItems) {
      candidateEntities.add(_EntityCandidate(item, ExtractionSource.rdfa));
    }
    if (openGraph.isNotEmpty) {
      candidateEntities.add(_EntityCandidate(openGraph, ExtractionSource.openGraph));
    }

    // Select the best candidate entity for the requested schema
    final targetType = schema.title?.toLowerCase();
    _EntityCandidate? primaryCandidate;

    if (targetType != null) {
      for (final candidate in candidateEntities) {
        final type = candidate.data['@type']?.toString().toLowerCase();
        if (type != null && (type == targetType || type.endsWith(targetType))) {
          primaryCandidate = candidate;
          break;
        }
      }
    }

    // If no type match, pick the candidate that matches the most fields
    if (primaryCandidate == null && candidateEntities.isNotEmpty) {
      primaryCandidate = _findBestCandidate(candidateEntities, schema.properties.keys);
    }

    final satisfied = <String, ExtractionSource>{};
    final missing = <String>[];
    final mappedData = <String, dynamic>{};

    for (final entry in schema.properties.entries) {
      final fieldName = entry.key;
      final fieldSpec = entry.value;

      _ResolvedValue? resolved;

      // 1. Try primary candidate
      if (primaryCandidate != null) {
        resolved = _resolveProperty(primaryCandidate, fieldName, fieldSpec);
      }

      // 2. Fall back to other candidates if not found
      if (resolved == null) {
        for (final candidate in candidateEntities) {
          if (candidate == primaryCandidate) continue;
          resolved = _resolveProperty(candidate, fieldName, fieldSpec);
          if (resolved != null) break;
        }
      }

      if (resolved != null) {
        mappedData[fieldName] = resolved.value;
        satisfied[fieldName] = resolved.source;
      } else {
        missing.add(fieldName);
      }
    }

    final coverage = ExtractionCoverage(
      satisfiedFields: satisfied,
      missingFields: missing,
    );

    final validation = schema.validate(mappedData);

    return StructuredHarvestResult(
      data: validation.coerced is Map<String, dynamic>
          ? validation.coerced as Map<String, dynamic>
          : mappedData,
      coverage: coverage,
      validation: validation,
    );
  }

  static _EntityCandidate _findBestCandidate(
    List<_EntityCandidate> candidates,
    Iterable<String> requestedKeys,
  ) {
    _EntityCandidate best = candidates.first;
    var bestMatches = -1;

    for (final candidate in candidates) {
      var matches = 0;
      for (final key in requestedKeys) {
        if (_hasPropertyMatch(candidate.data, key)) {
          matches++;
        }
      }
      if (matches > bestMatches) {
        bestMatches = matches;
        best = candidate;
      }
    }

    return best;
  }

  static bool _hasPropertyMatch(Map<String, dynamic> data, String key) {
    if (data.containsKey(key)) return true;
    final synonyms = _synonymsFor(key);
    for (final syn in synonyms) {
      if (data.containsKey(syn)) return true;
    }
    return false;
  }

  static _ResolvedValue? _resolveProperty(
    _EntityCandidate candidate,
    String fieldName,
    dynamic fieldSpec,
  ) {
    final data = candidate.data;
    final synonyms = _synonymsFor(fieldName);

    // Direct match or synonym match
    dynamic rawValue;
    if (data.containsKey(fieldName)) {
      rawValue = data[fieldName];
    } else {
      for (final syn in synonyms) {
        if (data.containsKey(syn)) {
          rawValue = data[syn];
          break;
        }
      }
    }

    // Special handling for Field.money
    if (fieldSpec is Field && fieldSpec.type == FieldType.money) {
      if (rawValue != null) {
        if (rawValue is Map) {
          final amt = rawValue['price'] ?? rawValue['amount'];
          final cur = rawValue['priceCurrency'] ?? rawValue['currency'];
          if (amt != null) {
            final parsedAmt = num.tryParse(amt.toString().replaceAll(',', '').trim());
            if (parsedAmt != null) {
              return _ResolvedValue(
                Money(parsedAmt, cur?.toString() ?? fieldSpec.defaultCurrency),
                candidate.source,
              );
            }
          }
        }
        final parsed = Money.tryParse(rawValue.toString(), defaultCurrency: fieldSpec.defaultCurrency);
        if (parsed != null) {
          return _ResolvedValue(parsed, candidate.source);
        }
      }

      // Check nested offers
      final offers = data['offers'];
      if (offers is Map) {
        final amt = offers['price'] ?? offers['lowPrice'];
        final cur = offers['priceCurrency'] ?? offers['currency'];
        if (amt != null) {
          final parsedAmt = num.tryParse(amt.toString().replaceAll(',', '').trim());
          if (parsedAmt != null) {
            return _ResolvedValue(
              Money(parsedAmt, cur?.toString() ?? fieldSpec.defaultCurrency),
              candidate.source,
            );
          }
        }
      } else if (offers is List && offers.isNotEmpty) {
        final firstOffer = offers.first;
        if (firstOffer is Map) {
          final amt = firstOffer['price'] ?? firstOffer['lowPrice'];
          final cur = firstOffer['priceCurrency'] ?? firstOffer['currency'];
          if (amt != null) {
            final parsedAmt = num.tryParse(amt.toString().replaceAll(',', '').trim());
            if (parsedAmt != null) {
              return _ResolvedValue(
                Money(parsedAmt, cur?.toString() ?? fieldSpec.defaultCurrency),
                candidate.source,
              );
            }
          }
        }
      }
    }

    // Special handling for nested offers or other sub-maps
    if (rawValue == null && fieldSpec is! Field) {
      for (final syn in synonyms) {
        if (syn.contains('.')) {
          final parts = syn.split('.');
          var current = data[parts.first];
          for (var i = 1; i < parts.length && current is Map; i++) {
            current = current[parts[i]];
          }
          if (current != null) {
            rawValue = current;
            break;
          }
        }
      }
    }

    // Check nested offers for plain numbers / strings if price was requested
    if (rawValue == null && (fieldName == 'price' || fieldName == 'cost')) {
      final offers = data['offers'];
      if (offers is Map) {
        rawValue = offers['price'] ?? offers['lowPrice'];
      } else if (offers is List && offers.isNotEmpty && offers.first is Map) {
        rawValue = (offers.first as Map)['price'];
      }
    }

    if (rawValue != null) {
      return _ResolvedValue(rawValue, candidate.source);
    }

    return null;
  }

  static List<String> _synonymsFor(String fieldName) {
    final lower = fieldName.toLowerCase();
    return switch (lower) {
      'name' => const ['title', 'headline', 'name', 'og:title', 'twitter:title'],
      'title' => const ['name', 'headline', 'title', 'og:title', 'twitter:title'],
      'description' => const [
          'description',
          'articleBody',
          'text',
          'summary',
          'og:description',
          'twitter:description'
        ],
      'price' => const ['price', 'offers.price', 'lowPrice', 'highPrice'],
      'currency' => const ['priceCurrency', 'currency', 'offers.priceCurrency'],
      'sku' => const ['sku', 'productID', 'identifier', 'gtin', 'gtin13', 'mpn'],
      'image' || 'images' => const ['image', 'images', 'og:image', 'twitter:image', 'thumbnailUrl'],
      'author' => const ['author', 'creator', 'byline', 'twitter:creator'],
      'publishdate' || 'date' => const [
          'datePublished',
          'publishedTime',
          'dateCreated',
          'article:published_time',
          'date'
        ],
      'url' => const ['url', '@id', 'canonical', 'og:url'],
      'rating' => const ['ratingValue', 'aggregateRating.ratingValue'],
      'reviewcount' => const ['reviewCount', 'aggregateRating.reviewCount'],
      'ingredients' => const ['recipeIngredient', 'ingredients'],
      'instructions' => const ['recipeInstructions', 'instructions'],
      _ => [fieldName],
    };
  }
}

class _EntityCandidate {
  const _EntityCandidate(this.data, this.source);
  final Map<String, dynamic> data;
  final ExtractionSource source;
}

class _ResolvedValue {
  const _ResolvedValue(this.value, this.source);
  final dynamic value;
  final ExtractionSource source;
}
