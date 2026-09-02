/// Deterministic currency and monetary value normalization.
library;

import '../../schema/field.dart';

/// Normalizes currency symbols, 3-letter ISO codes, and formatted amounts into [Money].
abstract final class MoneyNormalizer {
  static final Map<String, String> _symbolToCode = {
    r'$': 'USD',
    '€': 'EUR',
    '£': 'GBP',
    '¥': 'JPY',
    '₹': 'INR',
    '₽': 'RUB',
    '₩': 'KRW',
    '₪': 'ILS',
    '₺': 'TRY',
    '₴': 'UAH',
    'C\$': 'CAD',
    'A\$': 'AUD',
    'NZ\$': 'NZD',
    'HK\$': 'HKD',
    'S\$': 'SGD',
  };

  static final Set<String> _knownCodes = {
    'USD', 'EUR', 'GBP', 'JPY', 'INR', 'CAD', 'AUD', 'CHF', 'CNY', 'SEK',
    'NZD', 'MXN', 'SGD', 'HKD', 'NOK', 'KRW', 'TRY', 'RUB', 'BRL', 'ZAR',
  };

  /// Normalizes a price string into [Money].
  ///
  /// Correctly extracts currency without fabricating a `$` symbol when none exists.
  static Money? normalize(String input, {String? defaultCurrency}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    String? detectedCurrency;

    // 1. Detect 3-letter currency code (e.g. "120.00 EUR", "USD 49.99")
    final codeMatch = RegExp(r'\b([A-Z]{3})\b').firstMatch(trimmed);
    if (codeMatch != null && _knownCodes.contains(codeMatch.group(1))) {
      detectedCurrency = codeMatch.group(1);
    }

    // 2. Detect currency symbol
    if (detectedCurrency == null) {
      for (final entry in _symbolToCode.entries) {
        if (trimmed.contains(entry.key)) {
          detectedCurrency = entry.value;
          break;
        }
      }
    }

    // Fall back to specified default currency if provided, but never fabricate
    final currency = detectedCurrency ?? defaultCurrency;

    // 3. Extract and parse numeric amount
    // Strips out all currency symbols and letters
    final cleaned = trimmed
        .replaceAll(RegExp(r'[^\d.,\s-]'), '')
        .replaceAll(' ', '')
        .trim();

    if (cleaned.isEmpty) return null;

    final amount = _parseAmount(cleaned);
    if (amount == null) return null;

    return Money(amount, currency);
  }

  static double? _parseAmount(String input) {
    var s = input;

    final hasComma = s.contains(',');
    final hasDot = s.contains('.');

    if (hasComma && hasDot) {
      final lastComma = s.lastIndexOf(',');
      final lastDot = s.lastIndexOf('.');
      if (lastDot > lastComma) {
        // Standard US: 1,234.56 -> remove commas
        s = s.replaceAll(',', '');
      } else {
        // European: 1.234,56 -> remove dots and replace comma with dot
        s = s.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (hasComma) {
      final commaIndex = s.lastIndexOf(',');
      final digitsAfter = s.length - commaIndex - 1;
      if (digitsAfter == 2) {
        // Decimal comma: 12,99 -> 12.99
        s = s.replaceAll(',', '.');
      } else {
        // Thousands separator: 1,000 -> 1000
        s = s.replaceAll(',', '');
      }
    }

    return double.tryParse(s);
  }
}
