/// BM25 text ranker for scoring chunks against extraction schemas and queries.
library;

import 'dart:math' as math;

import 'chunker.dart';

/// A chunk scored by [Bm25Ranker].
class RankedChunk {
  /// Creates a [RankedChunk].
  const RankedChunk(this.chunk, this.score);

  /// The underlying document chunk.
  final Chunk chunk;

  /// The BM25 relevance score.
  final double score;

  @override
  String toString() =>
      'RankedChunk(#${chunk.index}, score: ${score.toStringAsFixed(3)})';
}

/// Ranks document chunks against a query or schema field list using BM25.
abstract final class Bm25Ranker {
  /// BM25 parameter governing term frequency saturation.
  static const double k1 = 1.2;

  /// BM25 parameter governing document length normalization.
  static const double b = 0.75;

  /// Common English stopwords to ignore during term matching.
  static const Set<String> stopwords = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'but', 'by', 'for', 'if', 'in',
    'into', 'is', 'it', 'no', 'not', 'of', 'on', 'or', 'such', 'that', 'the',
    'their', 'then', 'there', 'these', 'they', 'this', 'to', 'was', 'will',
    'with',
  };

  /// Common field name synonyms for query term expansion.
  static const Map<String, List<String>> _synonyms = {
    'price': ['cost', 'amount', 'offers', 'pricing', 'gbp', 'usd', 'eur'],
    'title': ['name', 'headline', 'heading', 'product'],
    'name': ['title', 'headline', 'heading', 'product'],
    'author': ['byline', 'writer', 'creator', 'by'],
    'date': ['published', 'time', 'datepublished'],
    'specs': ['specifications', 'attribute', 'details', 'features'],
    'specifications': ['specs', 'attribute', 'details', 'features', 'material'],
    'reviews': ['review', 'rating', 'feedback', 'stars'],
    'rating': ['reviews', 'review', 'score', 'stars'],
    'job': ['role', 'position', 'careers', 'hiring', 'vacancy'],
    'salary': ['pay', 'compensation', 'rate'],
  };

  /// Ranks [chunks] against [query], returning chunks sorted descending by BM25 score.
  static List<RankedChunk> rank(List<Chunk> chunks, String query) {
    if (chunks.isEmpty) return const [];

    final queryTerms = _expandQuery(query);
    if (queryTerms.isEmpty) {
      return chunks.map((c) => RankedChunk(c, 0.0)).toList();
    }

    final N = chunks.length;
    final tokenizedDocs = chunks.map((c) => _tokenize('${c.heading ?? ''} ${c.text}')).toList();

    // Average document length in terms
    final totalLength = tokenizedDocs.fold(0, (sum, terms) => sum + terms.length);
    final avgdl = totalLength > 0 ? totalLength / N : 1.0;

    // Document frequencies: number of documents containing term t
    final docFrequencies = <String, int>{};
    for (final term in queryTerms) {
      var count = 0;
      for (final doc in tokenizedDocs) {
        if (doc.contains(term)) count++;
      }
      docFrequencies[term] = count;
    }

    // Calculate BM25 score per chunk
    final ranked = <RankedChunk>[];
    for (var i = 0; i < N; i++) {
      final docTerms = tokenizedDocs[i];
      final docLength = docTerms.length;

      // Term frequencies in current doc
      final termFreqs = <String, int>{};
      for (final t in docTerms) {
        termFreqs[t] = (termFreqs[t] ?? 0) + 1;
      }

      var score = 0.0;
      for (final term in queryTerms) {
        final f = termFreqs[term] ?? 0;
        if (f == 0) continue;

        final n = docFrequencies[term] ?? 0;
        final idf = math.log(((N - n + 0.5) / (n + 0.5)) + 1.0);

        final numerator = f * (k1 + 1.0);
        final denominator = f + k1 * (1.0 - b + b * (docLength / avgdl));

        score += idf * (numerator / denominator);
      }

      ranked.add(RankedChunk(chunks[i], score));
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked;
  }

  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !stopwords.contains(t))
        .toList();
  }

  static Set<String> _expandQuery(String query) {
    final rawTokens = _tokenize(query);
    final expanded = <String>{...rawTokens};

    for (final token in rawTokens) {
      final syns = _synonyms[token];
      if (syns != null) {
        expanded.addAll(syns);
      }
    }

    return expanded;
  }
}
