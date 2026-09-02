/// Token budgeting and top-K chunk selection with output headroom reservation.
library;

import 'dart:math' as math;

import '../ai/ai_provider.dart';
import 'bm25_ranker.dart';
import 'chunker.dart';

/// Manages context window token allocation between input chunks and generation headroom.
class TokenBudget {
  /// Creates a [TokenBudget].
  const TokenBudget({
    this.maxContextTokens = 2048,
    this.reservedOutputTokens = 512,
  });

  /// Derives budget constraints directly from [capabilities].
  factory TokenBudget.fromCapabilities(AiCapabilities capabilities) =>
      TokenBudget(
        maxContextTokens: capabilities.maxContextTokens,
        reservedOutputTokens: capabilities.maxOutputTokens,
      );

  /// Derives budget constraints directly from an [AiProvider].
  factory TokenBudget.fromProvider(AiProvider provider) =>
      TokenBudget.fromCapabilities(provider.capabilities);

  /// The total context window limit of the model.
  final int maxContextTokens;

  /// Number of tokens reserved exclusively for model output/generation.
  final int reservedOutputTokens;

  /// Available tokens for input prompt and document chunks.
  int get availableInputTokens =>
      math.max(0, maxContextTokens - reservedOutputTokens);

  /// Selects top-ranked chunks that fit within [availableInputTokens].
  ///
  /// If [preserveDocumentOrder] is `true`, the selected chunks are returned in
  /// their original document order rather than by descending rank score.
  List<Chunk> select(
    List<RankedChunk> rankedChunks, {
    bool preserveDocumentOrder = true,
  }) {
    final budget = availableInputTokens;
    final selected = <Chunk>[];
    var usedTokens = 0;

    for (final ranked in rankedChunks) {
      final chunk = ranked.chunk;
      if (usedTokens + chunk.estimatedTokens <= budget) {
        selected.add(chunk);
        usedTokens += chunk.estimatedTokens;
      }
    }

    if (preserveDocumentOrder && selected.length > 1) {
      selected.sort((a, b) => a.index.compareTo(b.index));
    }

    return selected;
  }
}
