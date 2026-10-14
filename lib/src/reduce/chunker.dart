class Chunker {
  /// Splits text or markdown into chunks within the token budget (~4 chars/token).
  static List<String> chunkText(
    String text, {
    int maxTokensPerChunk = 3000,
  }) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return const [];

    final maxChars = maxTokensPerChunk * 4;
    if (cleaned.length <= maxChars) return [cleaned];

    final chunks = <String>[];
    final paragraphs = cleaned.split(RegExp(r'\n\s*\n'));
    final buffer = StringBuffer();

    for (final para in paragraphs) {
      final trimmedPara = para.trim();
      if (trimmedPara.isEmpty) continue;

      if (buffer.length + trimmedPara.length + 2 > maxChars) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }
        if (trimmedPara.length > maxChars) {
          for (var i = 0; i < trimmedPara.length; i += maxChars) {
            final end = (i + maxChars < trimmedPara.length)
                ? i + maxChars
                : trimmedPara.length;
            chunks.add(trimmedPara.substring(i, end));
          }
        } else {
          buffer.write(trimmedPara);
        }
      } else {
        if (buffer.isNotEmpty) buffer.write('\n\n');
        buffer.write(trimmedPara);
      }
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }

    return chunks;
  }

  /// Ranks chunks by relevance to an extraction query so only top relevant chunks hit the LLM.
  static List<String> rankChunksByQuery(
    List<String> chunks,
    String query, {
    int topK = 3,
  }) {
    if (chunks.length <= topK) return chunks;

    final terms = query
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((t) => t.length > 2)
        .toSet();

    if (terms.isEmpty) return chunks.take(topK).toList();

    final scored = <({String chunk, double score})>[];
    for (final chunk in chunks) {
      final lower = chunk.toLowerCase();
      double score = 0;
      for (final term in terms) {
        final matches = RegExp(RegExp.escape(term)).allMatches(lower).length;
        score += matches * (1.0 + (term.length * 0.1));
      }
      scored.add((chunk: chunk, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).map((e) => e.chunk).toList();
  }
}
