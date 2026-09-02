/// Field definitions and types for the Schema DSL.
library;

/// Supported primitive types for schema fields.
enum FieldType {
  /// A textual value.
  string,

  /// A numeric floating-point or integer value.
  number,

  /// A whole integer value.
  integer,

  /// A monetary amount with an associated currency code.
  money,

  /// An ISO-8601 date or timestamp.
  date,

  /// A valid URL.
  url,

  /// An email address.
  email,

  /// A phone number.
  phone,

  /// A boolean true/false flag.
  boolean,

  /// A value constrained to a predefined set of strings.
  enumeration,
}

/// Represents a monetary value with an amount and an optional currency code.
class Money {
  /// Creates a [Money] value.
  const Money(this.amount, [this.currency]);

  /// The numeric monetary amount.
  final num amount;

  /// The ISO 4217 currency code (e.g. `USD`, `EUR`, `GBP`, `JPY`), or symbol.
  final String? currency;

  /// Known currency symbol to ISO 4217 code mapping.
  static const Map<String, String> symbolToCode = {
    r'$': 'USD',
    'US\$': 'USD',
    '€': 'EUR',
    '£': 'GBP',
    '¥': 'JPY',
    '₹': 'INR',
    '₩': 'KRW',
    '₽': 'RUB',
    'C\$': 'CAD',
    'A\$': 'AUD',
    'CHF': 'CHF',
    'kr': 'SEK',
  };

  /// Parses a string into a [Money] instance, preserving real currency symbols.
  ///
  /// For instance:
  /// - `"£1,395.00"` -> `Money(1395.00, 'GBP')`
  /// - `"€49,99"` -> `Money(49.99, 'EUR')`
  /// - `"$19.99"` -> `Money(19.99, 'USD')`
  /// - `"1299 JPY"` -> `Money(1299, 'JPY')`
  static Money? tryParse(String input, {String? defaultCurrency}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    String? detectedCurrency = defaultCurrency;

    // Check for standard 3-letter currency codes (e.g. "USD 19.99", "19.99 EUR")
    final codeMatch = RegExp(r'\b([A-Z]{3})\b').firstMatch(trimmed);
    if (codeMatch != null) {
      detectedCurrency = codeMatch.group(1);
    } else {
      // Check for currency symbols
      for (final entry in symbolToCode.entries) {
        if (trimmed.contains(entry.key)) {
          detectedCurrency = entry.value;
          break;
        }
      }
    }

    // Extract the numeric part
    // Handle European formats like "49,99" or "1.395,00" vs standard "1,395.00"
    var numStr = trimmed.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (numStr.isEmpty) return null;

    if (numStr.contains(',') && numStr.contains('.')) {
      if (numStr.lastIndexOf(',') > numStr.lastIndexOf('.')) {
        // European format: 1.395,00
        numStr = numStr.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Standard format: 1,395.00
        numStr = numStr.replaceAll(',', '');
      }
    } else if (numStr.contains(',')) {
      final commaIndex = numStr.indexOf(',');
      final afterComma = numStr.substring(commaIndex + 1);
      if (afterComma.length == 2) {
        // Likely decimal separator: 49,99
        numStr = numStr.replaceAll(',', '.');
      } else {
        // Likely thousands separator: 1,000
        numStr = numStr.replaceAll(',', '');
      }
    }

    final parsedAmount = num.tryParse(numStr);
    if (parsedAmount == null) return null;

    return Money(parsedAmount, detectedCurrency);
  }

  /// Converts this [Money] to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'amount': amount,
        if (currency != null) 'currency': currency,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          amount == other.amount &&
          currency == other.currency;

  @override
  int get hashCode => amount.hashCode ^ currency.hashCode;

  @override
  String toString() =>
      currency != null ? '$currency $amount' : amount.toString();
}

/// A specification for a single property/field within a schema.
class Field {
  const Field._({
    required this.type,
    this.description,
    this.required = true,
    this.pattern,
    this.minLength,
    this.maxLength,
    this.minimum,
    this.maximum,
    this.enumValues,
    this.defaultCurrency,
  });

  /// String field.
  const Field.string({
    String? description,
    bool required = true,
    String? pattern,
    int? minLength,
    int? maxLength,
  }) : this._(
          type: FieldType.string,
          description: description,
          required: required,
          pattern: pattern,
          minLength: minLength,
          maxLength: maxLength,
        );

  /// Numeric (integer or double) field.
  const Field.number({
    String? description,
    bool required = true,
    num? minimum,
    num? maximum,
  }) : this._(
          type: FieldType.number,
          description: description,
          required: required,
          minimum: minimum,
          maximum: maximum,
        );

  /// Integer field.
  const Field.integer({
    String? description,
    bool required = true,
    int? minimum,
    int? maximum,
  }) : this._(
          type: FieldType.integer,
          description: description,
          required: required,
          minimum: minimum,
          maximum: maximum,
        );

  /// Monetary value field with amount and currency code.
  const Field.money({
    String? description,
    bool required = true,
    String? defaultCurrency,
  }) : this._(
          type: FieldType.money,
          description: description,
          required: required,
          defaultCurrency: defaultCurrency,
        );

  /// Date/time field (ISO-8601 string or DateTime).
  const Field.date({
    String? description,
    bool required = true,
  }) : this._(
          type: FieldType.date,
          description: description,
          required: required,
        );

  /// URL field.
  const Field.url({
    String? description,
    bool required = true,
  }) : this._(
          type: FieldType.url,
          description: description,
          required: required,
        );

  /// Email address field.
  const Field.email({
    String? description,
    bool required = true,
  }) : this._(
          type: FieldType.email,
          description: description,
          required: required,
        );

  /// Phone number field.
  const Field.phone({
    String? description,
    bool required = true,
  }) : this._(
          type: FieldType.phone,
          description: description,
          required: required,
        );

  /// Boolean field.
  const Field.bool_({
    String? description,
    bool required = true,
  }) : this._(
          type: FieldType.boolean,
          description: description,
          required: required,
        );

  /// Enumeration field constrained to [values].
  const Field.enum_(
    List<String> values, {
    String? description,
    bool required = true,
  }) : this._(
          type: FieldType.enumeration,
          enumValues: values,
          description: description,
          required: required,
        );

  /// The data type of this field.
  final FieldType type;

  /// Human-readable documentation for AI prompts and schema specs.
  final String? description;

  /// Whether this field is required to be present and non-null.
  final bool required;

  /// Optional regex pattern for string validation.
  final String? pattern;

  /// Optional minimum string length.
  final int? minLength;

  /// Optional maximum string length.
  final int? maxLength;

  /// Optional minimum number value.
  final num? minimum;

  /// Optional maximum number value.
  final num? maximum;

  /// Allowed values when [type] is [FieldType.enumeration].
  final List<String>? enumValues;

  /// Default currency code for [FieldType.money] fields when not detected.
  final String? defaultCurrency;

  /// Generates the Draft-07 JSON Schema definition for this field.
  Map<String, dynamic> toJsonSchema() {
    final map = <String, dynamic>{};

    switch (type) {
      case FieldType.string:
        map['type'] = 'string';
        if (pattern != null) map['pattern'] = pattern;
        if (minLength != null) map['minLength'] = minLength;
        if (maxLength != null) map['maxLength'] = maxLength;

      case FieldType.number:
        map['type'] = 'number';
        if (minimum != null) map['minimum'] = minimum;
        if (maximum != null) map['maximum'] = maximum;

      case FieldType.integer:
        map['type'] = 'integer';
        if (minimum != null) map['minimum'] = minimum;
        if (maximum != null) map['maximum'] = maximum;

      case FieldType.money:
        map['type'] = 'object';
        map['properties'] = <String, dynamic>{
          'amount': {'type': 'number'},
          'currency': {'type': 'string'},
        };
        map['required'] = ['amount'];

      case FieldType.date:
        map['type'] = 'string';
        map['format'] = 'date-time';

      case FieldType.url:
        map['type'] = 'string';
        map['format'] = 'uri';

      case FieldType.email:
        map['type'] = 'string';
        map['format'] = 'email';

      case FieldType.phone:
        map['type'] = 'string';

      case FieldType.boolean:
        map['type'] = 'boolean';

      case FieldType.enumeration:
        map['type'] = 'string';
        map['enum'] = enumValues ?? <String>[];
    }

    if (description != null) {
      map['description'] = description;
    }

    return map;
  }

  /// Attempts to coerce [input] to the expected type for this field.
  ///
  /// Returns the coerced value, or `null` if coercion fails or input is `null`.
  dynamic coerce(dynamic input) {
    if (input == null) return null;

    switch (type) {
      case FieldType.string:
        return input.toString().trim();

      case FieldType.number:
        if (input is num) return input;
        if (input is String) {
          final cleaned = input.replaceAll(',', '').trim();
          return num.tryParse(cleaned);
        }
        return null;

      case FieldType.integer:
        if (input is int) return input;
        if (input is num) return input.toInt();
        if (input is String) {
          final cleaned = input.replaceAll(',', '').trim();
          return int.tryParse(cleaned) ?? double.tryParse(cleaned)?.toInt();
        }
        return null;

      case FieldType.money:
        if (input is Money) return input;
        if (input is num) return Money(input, defaultCurrency);
        if (input is Map) {
          final amt = input['amount'];
          final parsedAmt = amt is num ? amt : num.tryParse(amt.toString());
          if (parsedAmt != null) {
            final cur = input['currency']?.toString() ?? defaultCurrency;
            return Money(parsedAmt, cur);
          }
        }
        if (input is String) {
          return Money.tryParse(input, defaultCurrency: defaultCurrency);
        }
        return null;

      case FieldType.date:
        if (input is DateTime) return input;
        if (input is String) {
          final parsed = DateTime.tryParse(input.trim());
          return parsed;
        }
        return null;

      case FieldType.url:
        if (input is Uri) return input.toString();
        if (input is String) {
          final trimmed = input.trim();
          final uri = Uri.tryParse(trimmed);
          if (uri != null && uri.hasScheme) return trimmed;
        }
        return null;

      case FieldType.email:
        if (input is String) {
          final trimmed = input.trim();
          if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
            return trimmed;
          }
        }
        return null;

      case FieldType.phone:
        if (input is String) {
          final trimmed = input.trim();
          // E.164 or common domestic phone formats
          if (RegExp(r'^\+?[0-9\s\-().]{7,25}$').hasMatch(trimmed)) {
            return trimmed;
          }
        }
        return null;

      case FieldType.boolean:
        if (input is bool) return input;
        if (input is String) {
          final lower = input.trim().toLowerCase();
          if (lower == 'true' || lower == '1' || lower == 'yes') return true;
          if (lower == 'false' || lower == '0' || lower == 'no') return false;
        }
        if (input is num) return input != 0;
        return null;

      case FieldType.enumeration:
        final str = input.toString().trim();
        if (enumValues != null && enumValues!.contains(str)) {
          return str;
        }
        return null;
    }
  }

  /// Validates [value]. Returns an error message if invalid, or `null` if valid.
  String? validate(dynamic value) {
    if (value == null) {
      return required ? 'Field is required and cannot be null.' : null;
    }

    if (type == FieldType.enumeration) {
      final str = value.toString().trim();
      if (enumValues != null && !enumValues!.contains(str)) {
        return 'Value "$str" is not one of allowed values: $enumValues.';
      }
    }

    final coerced = coerce(value);
    if (coerced == null) {
      return 'Cannot coerce "$value" to expected type $type.';
    }

    switch (type) {
      case FieldType.string:
        final s = coerced as String;
        if (minLength != null && s.length < minLength!) {
          return 'Length ${s.length} is less than minimum $minLength.';
        }
        if (maxLength != null && s.length > maxLength!) {
          return 'Length ${s.length} exceeds maximum $maxLength.';
        }
        if (pattern != null && !RegExp(pattern!).hasMatch(s)) {
          return 'Value does not match required pattern "$pattern".';
        }

      case FieldType.number:
      case FieldType.integer:
        final n = coerced as num;
        if (minimum != null && n < minimum!) {
          return 'Value $n is less than minimum $minimum.';
        }
        if (maximum != null && n > maximum!) {
          return 'Value $n exceeds maximum $maximum.';
        }

      case FieldType.enumeration:
        final s = coerced as String;
        if (enumValues != null && !enumValues!.contains(s)) {
          return 'Value "$s" is not one of allowed values: $enumValues.';
        }

      default:
        break;
    }

    return null;
  }
}
