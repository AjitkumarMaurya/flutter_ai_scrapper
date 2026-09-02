/// Markdown structure-preserving chunker.
library;

import 'token_estimator.dart';

/// A contiguous chunk of document content.
class Chunk {
  /// Creates a [Chunk].
  const Chunk({
    required this.index,
    required this.text,
    this.heading,
    required this.estimatedTokens,
  });

  /// 0-based document position of this chunk.
  final int index;

  /// The markdown text contained within this chunk.
  final String text;

  /// The nearest active section heading above this chunk, if any.
  final String? heading;

  /// Number of tokens estimated to be in [text].
  final int estimatedTokens;

  @override
  String toString() =>
      'Chunk(#$index, tokens: ~$estimatedTokens, heading: $heading)';
}

/// Splits Markdown documents into manageable chunks without breaking atomic structures.
abstract final class Chunker {
  /// Chunks [markdown] into segments up to [maxTokens] each.
  ///
  /// Splits primarily along section headings (`#`, `##`, etc.) and paragraph
  /// boundaries. **Never splits a table, code block, or list mid-structure.**
  static List<Chunk> chunk(
    String markdown, {
    int maxTokens = 400,
    int overlapTokens = 40,
  }) {
    final trimmed = markdown.trim();
    if (trimmed.isEmpty) return const [];

    final blocks = _parseAtomicBlocks(trimmed);
    if (blocks.isEmpty) return const [];

    final chunks = <Chunk>[];
    var currentBlocks = <_Block>[];
    var currentTokens = 0;
    String? currentHeading;
    var chunkIndex = 0;

    for (final block in blocks) {
      if (block.isHeading) {
        currentHeading = block.text;
      }

      final blockTokens = block.tokens;

      // If adding this block exceeds budget and we already have blocks, flush current chunk
      if (currentBlocks.isNotEmpty && (currentTokens + blockTokens > maxTokens)) {
        final chunkText = currentBlocks.map((b) => b.text).join('\n\n').trim();
        chunks.add(Chunk(
          index: chunkIndex++,
          text: chunkText,
          heading: currentBlocks.firstWhere((b) => b.isHeading, orElse: () => currentBlocks.first).heading ?? currentHeading,
          estimatedTokens: TokenEstimator.estimate(chunkText),
        ));

        // Overlap: retain trailing block if it fits within overlapTokens
        final overlapBlocks = <_Block>[];
        if (overlapTokens > 0) {
          var overlapAcc = 0;
          for (final prev in currentBlocks.reversed) {
            if (overlapAcc + prev.tokens <= overlapTokens && !prev.isHeading) {
              overlapBlocks.insert(0, prev);
              overlapAcc += prev.tokens;
            } else {
              break;
            }
          }
        }

        currentBlocks = [...overlapBlocks, block];
        currentTokens = currentBlocks.fold(0, (sum, b) => sum + b.tokens);
      } else {
        currentBlocks.add(block);
        currentTokens += blockTokens;
      }
    }

    if (currentBlocks.isNotEmpty) {
      final chunkText = currentBlocks.map((b) => b.text).join('\n\n').trim();
      chunks.add(Chunk(
        index: chunkIndex,
        text: chunkText,
        heading: currentHeading,
        estimatedTokens: TokenEstimator.estimate(chunkText),
      ));
    }

    return chunks;
  }

  static List<_Block> _parseAtomicBlocks(String markdown) {
    final lines = markdown.split('\n');
    final blocks = <_Block>[];

    var i = 0;
    String? activeHeading;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // 1. Headings
      if (trimmed.startsWith('#')) {
        activeHeading = trimmed;
        blocks.add(_Block(
          text: trimmed,
          tokens: TokenEstimator.estimate(trimmed),
          isHeading: true,
          heading: activeHeading,
        ));
        i++;
        continue;
      }

      // 2. Fenced Code Blocks (```)
      if (trimmed.startsWith('```')) {
        final codeLines = <String>[line];
        i++;
        while (i < lines.length) {
          codeLines.add(lines[i]);
          if (lines[i].trim().startsWith('```')) {
            i++;
            break;
          }
          i++;
        }
        final codeText = codeLines.join('\n');
        blocks.add(_Block(
          text: codeText,
          tokens: TokenEstimator.estimate(codeText),
          heading: activeHeading,
        ));
        continue;
      }

      // 3. Tables (lines starting with |)
      if (trimmed.startsWith('|')) {
        final tableLines = <String>[line];
        i++;
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          tableLines.add(lines[i]);
          i++;
        }
        final tableText = tableLines.join('\n');
        blocks.add(_Block(
          text: tableText,
          tokens: TokenEstimator.estimate(tableText),
          heading: activeHeading,
        ));
        continue;
      }

      // 4. Lists (items starting with -, *, or N.)
      if (_isListLine(trimmed)) {
        final listLines = <String>[line];
        i++;
        while (i < lines.length && (_isListLine(lines[i].trim()) || lines[i].startsWith('  '))) {
          listLines.add(lines[i]);
          i++;
        }
        final listText = listLines.join('\n');
        blocks.add(_Block(
          text: listText,
          tokens: TokenEstimator.estimate(listText),
          heading: activeHeading,
        ));
        continue;
      }

      // 5. Normal paragraphs
      final paraLines = <String>[line];
      i++;
      while (i < lines.length && lines[i].trim().isNotEmpty && !lines[i].trim().startsWith('#') && !lines[i].trim().startsWith('|') && !lines[i].trim().startsWith('```')) {
        paraLines.add(lines[i]);
        i++;
      }
      final paraText = paraLines.join('\n');
      blocks.add(_Block(
        text: paraText,
        tokens: TokenEstimator.estimate(paraText),
        heading: activeHeading,
      ));
    }

    return blocks;
  }

  static bool _isListLine(String trimmed) =>
      trimmed.startsWith('- ') ||
      trimmed.startsWith('* ') ||
      RegExp(r'^\d+\.\s').hasMatch(trimmed);
}

class _Block {
  const _Block({
    required this.text,
    required this.tokens,
    this.isHeading = false,
    this.heading,
  });

  final String text;
  final int tokens;
  final bool isHeading;
  final String? heading;
}
