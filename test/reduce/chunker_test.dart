import 'package:flutter_ai_scrapper/src/reduce/budget.dart';
import 'package:flutter_ai_scrapper/src/reduce/chunker.dart';
import 'package:flutter_ai_scrapper/src/reduce/token_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TokenEstimator', () {
    test('estimates tokens roughly at 4 characters per token', () {
      expect(TokenEstimator.estimate(''), 0);
      expect(TokenEstimator.estimate('1234'), 1);
      expect(TokenEstimator.estimate('12345678'), 2);
    });
  });

  group('Chunker', () {
    test('never splits a table mid-structure', () {
      const markdown = '''
# Section One

Some introduction text.

| Header A | Header B |
| --- | --- |
| Row 1 | Val 1 |
| Row 2 | Val 2 |
| Row 3 | Val 3 |
| Row 4 | Val 4 |
| Row 5 | Val 5 |

# Section Two

Conclusion.
''';
      // Small chunk size to force chunking
      final chunks = Chunker.chunk(markdown, maxTokens: 25, overlapTokens: 0);

      expect(chunks.length, greaterThanOrEqualTo(2));

      // Assert that if a chunk has '|', it contains the complete table structure
      for (final chunk in chunks) {
        if (chunk.text.contains('| Header A |')) {
          expect(chunk.text, contains('| Row 5 | Val 5 |'));
        }
      }
    });

    test('never splits a list mid-structure', () {
      const markdown = '''
# Instructions

- Step 1: Open the box
- Step 2: Assemble the frame
- Step 3: Tighten the bolts
- Step 4: Inspect the finish

# Next Steps
''';
      final chunks = Chunker.chunk(markdown, maxTokens: 20, overlapTokens: 0);
      for (final chunk in chunks) {
        if (chunk.text.contains('- Step 1')) {
          expect(chunk.text, contains('- Step 4'));
        }
      }
    });
  });

  group('TokenBudget', () {
    test('reserves output headroom from context window', () {
      const budget = TokenBudget(maxContextTokens: 2048, reservedOutputTokens: 512);
      expect(budget.availableInputTokens, 1536);
    });
  });
}
