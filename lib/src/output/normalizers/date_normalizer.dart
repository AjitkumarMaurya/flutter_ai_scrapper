/// Deterministic date parsing and ISO-8601 normalization.
library;

/// Normalizes dates, timestamps, and relative time expressions into standard ISO-8601 strings.
abstract final class DateNormalizer {
  static final _monthNames = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  /// Normalizes [input] to an ISO-8601 UTC string (e.g. `'2026-09-02T00:00:00.000Z'`).
  ///
  /// Returns `null` if the input cannot be deterministically resolved.
  static String? normalize(String input, {DateTime? referenceTime}) {
    final parsed = parse(input, referenceTime: referenceTime);
    return parsed?.toUtc().toIso8601String();
  }

  /// Parses [input] into a [DateTime].
  static DateTime? parse(String input, {DateTime? referenceTime}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final now = referenceTime ?? DateTime.now();

    // 1. Direct ISO-8601 parse
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final lower = trimmed.toLowerCase();

    // 2. Relative date phrases
    if (lower == 'today' || lower == 'just now') {
      return DateTime.utc(now.year, now.month, now.day);
    }
    if (lower == 'yesterday') {
      return DateTime.utc(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
    }
    if (lower == 'tomorrow') {
      return DateTime.utc(now.year, now.month, now.day)
          .add(const Duration(days: 1));
    }

    final agoMatch = RegExp(r'(\d+)\s+(minute|hour|day|week|month|year)s?\s+ago')
        .firstMatch(lower);
    if (agoMatch != null) {
      final amount = int.parse(agoMatch.group(1)!);
      final unit = agoMatch.group(2)!;
      switch (unit) {
        case 'minute':
          return now.subtract(Duration(minutes: amount));
        case 'hour':
          return now.subtract(Duration(hours: amount));
        case 'day':
          return now.subtract(Duration(days: amount));
        case 'week':
          return now.subtract(Duration(days: amount * 7));
        case 'month':
          return now.subtract(Duration(days: amount * 30));
        case 'year':
          return now.subtract(Duration(days: amount * 365));
      }
    }

    // 3. Pattern: "September 2, 2026" or "Sep 2, 2026" or "2 Sep 2026"
    final textDate1 = RegExp(
      r'([a-zA-Z]+)\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})',
    ).firstMatch(trimmed);
    if (textDate1 != null) {
      final monthStr = textDate1.group(1)!.toLowerCase();
      final month = _monthNames[monthStr];
      final day = int.parse(textDate1.group(2)!);
      final year = int.parse(textDate1.group(3)!);
      if (month != null) {
        return DateTime.utc(year, month, day);
      }
    }

    final textDate2 = RegExp(
      r'(\d{1,2})\s+([a-zA-Z]+),?\s+(\d{4})',
    ).firstMatch(trimmed);
    if (textDate2 != null) {
      final day = int.parse(textDate2.group(1)!);
      final monthStr = textDate2.group(2)!.toLowerCase();
      final month = _monthNames[monthStr];
      final year = int.parse(textDate2.group(3)!);
      if (month != null) {
        return DateTime.utc(year, month, day);
      }
    }

    // 4. Pattern: YYYY/MM/DD or DD/MM/YYYY or MM/DD/YYYY
    final slashParts = trimmed.split(RegExp(r'[-/.]'));
    if (slashParts.length == 3) {
      final p0 = int.tryParse(slashParts[0]);
      final p1 = int.tryParse(slashParts[1]);
      final p2 = int.tryParse(slashParts[2]);

      if (p0 != null && p1 != null && p2 != null) {
        if (p0 > 1000) {
          // YYYY-MM-DD
          return DateTime.utc(p0, p1, p2);
        } else if (p2 > 1000) {
          // DD/MM/YYYY or MM/DD/YYYY: if p0 > 12, must be DD/MM/YYYY
          if (p0 > 12) {
            return DateTime.utc(p2, p1, p0);
          } else {
            return DateTime.utc(p2, p0, p1);
          }
        }
      }
    }

    return null;
  }
}
