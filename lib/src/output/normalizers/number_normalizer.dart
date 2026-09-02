/// Deterministic number normalization handling locale formatting and metric abbreviations.
library;

/// Normalizes numeric strings, percentages, and shorthand multipliers (`k`, `M`, `B`).
abstract final class NumberNormalizer {
  /// Parses and normalizes [input] into a [num].
  static num? normalize(String input) {
    var trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    var multiplier = 1.0;

    // Check for metric suffixes (k, M, B)
    if (trimmed.endsWith('k') || trimmed.endsWith('K')) {
      multiplier = 1000.0;
      trimmed = trimmed.substring(0, trimmed.length - 1).trim();
    } else if (trimmed.endsWith('m') || trimmed.endsWith('M')) {
      multiplier = 1000000.0;
      trimmed = trimmed.substring(0, trimmed.length - 1).trim();
    } else if (trimmed.endsWith('b') || trimmed.endsWith('B')) {
      multiplier = 1000000000.0;
      trimmed = trimmed.substring(0, trimmed.length - 1).trim();
    }

    // Check for percentage
    final isPercent = trimmed.endsWith('%');
    if (isPercent) {
      trimmed = trimmed.substring(0, trimmed.length - 1).trim();
    }

    final hasComma = trimmed.contains(',');
    final hasDot = trimmed.contains('.');

    if (hasComma && hasDot) {
      final lastComma = trimmed.lastIndexOf(',');
      final lastDot = trimmed.lastIndexOf('.');
      if (lastDot > lastComma) {
        // Standard US: 1,234.56
        trimmed = trimmed.replaceAll(',', '');
      } else {
        // European: 1.234,56
        trimmed = trimmed.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (hasComma) {
      final commaIndex = trimmed.lastIndexOf(',');
      final digitsAfter = trimmed.length - commaIndex - 1;
      if (digitsAfter == 2) {
        trimmed = trimmed.replaceAll(',', '.');
      } else {
        trimmed = trimmed.replaceAll(',', '');
      }
    }

    trimmed = trimmed.replaceAll(' ', '');
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return null;

    final value = isPercent ? (parsed / 100.0) : (parsed * multiplier);

    if (value == value.roundToDouble() && multiplier == 1.0 && !isPercent) {
      return value.toInt();
    }
    return value;
  }
}
