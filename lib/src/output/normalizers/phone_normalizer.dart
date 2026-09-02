/// Deterministic phone number parsing and E.164 normalization.
library;

/// Normalizes raw phone numbers into standard E.164 international format (`+1...`).
abstract final class PhoneNormalizer {
  /// Normalizes [input] to an E.164 phone string (e.g. `'+14155552671'`).
  ///
  /// Uses [defaultCountryCode] (defaults to `'+1'`) if the number does not begin with `+`.
  static String? normalize(
    String input, {
    String defaultCountryCode = '+1',
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final startsWithPlus = trimmed.startsWith('+');

    // Extract all digit characters
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
      // E.164 numbers cannot exceed 15 digits or be shorter than 7
      return null;
    }

    if (startsWithPlus) {
      return '+$digitsOnly';
    }

    final cleanPrefix = defaultCountryCode.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.startsWith(cleanPrefix) && digitsOnly.length > cleanPrefix.length + 6) {
      return '+$digitsOnly';
    }

    return '+$cleanPrefix$digitsOnly';
  }
}
