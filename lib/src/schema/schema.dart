/// Schema definition and validation for the Schema DSL.
library;

import 'field.dart';

/// The result of validating a data structure against a [Schema].
class ValidationResult {
  /// Creates a [ValidationResult].
  const ValidationResult({
    required this.isValid,
    this.errors = const {},
    this.coerced,
  });

  /// Whether the data conforms to the schema.
  final bool isValid;

  /// Per-field error messages, keyed by dot-delimited path (e.g. `offers.price`).
  final Map<String, String> errors;

  /// The data after type coercion has been applied, or `null` if completely invalid.
  final dynamic coerced;

  @override
  String toString() => isValid
      ? 'ValidationResult.valid(coerced: $coerced)'
      : 'ValidationResult.invalid(errors: $errors)';
}

/// Abstract base class for structured schema specifications.
sealed class Schema {
  const Schema._({this.description, this.title});

  /// Defines an object schema consisting of named properties.
  ///
  /// Each property value in [properties] must be either a [Field] or a nested [Schema].
  const factory Schema.object(
    Map<String, dynamic> properties, {
    String? description,
    String? title,
    List<String>? required,
  }) = ObjectSchema;

  /// Defines a list schema containing items conforming to [itemSchema].
  ///
  /// [itemSchema] must be either a [Field] or a nested [Schema].
  const factory Schema.list(
    dynamic itemSchema, {
    String? description,
    String? title,
    int? minItems,
    int? maxItems,
  }) = ListSchema;

  /// Human-readable description.
  final String? description;

  /// Optional title of the schema.
  final String? title;

  /// Generates a Draft-07 JSON Schema representation of this schema.
  Map<String, dynamic> toJsonSchema({bool isRoot = true});

  /// Validates [data] against this schema, returning a [ValidationResult] with
  /// coerced values and any validation errors.
  ValidationResult validate(dynamic data);
}

/// A schema describing a JSON/Dart map object with specific named properties.
class ObjectSchema extends Schema {
  /// Creates an [ObjectSchema].
  const ObjectSchema(
    this.properties, {
    super.description,
    super.title,
    this.required,
  }) : super._();

  /// Map of field names to either [Field] or [Schema] definitions.
  final Map<String, dynamic> properties;

  /// Explicit list of required property names. If `null`, required fields are
  /// inferred from properties with `required: true`.
  final List<String>? required;

  /// Gets the list of required property keys.
  List<String> get effectiveRequired {
    if (required != null) return required!;
    final reqList = <String>[];
    for (final entry in properties.entries) {
      final value = entry.value;
      if (value is Field && value.required) {
        reqList.add(entry.key);
      } else if (value is Schema) {
        reqList.add(entry.key);
      }
    }
    return reqList;
  }

  @override
  Map<String, dynamic> toJsonSchema({bool isRoot = true}) {
    final map = <String, dynamic>{
      if (isRoot) r'$schema': 'http://json-schema.org/draft-07/schema#',
      'type': 'object',
    };

    if (title != null) map['title'] = title;
    if (description != null) map['description'] = description;

    final propsMap = <String, dynamic>{};
    for (final entry in properties.entries) {
      final val = entry.value;
      if (val is Field) {
        propsMap[entry.key] = val.toJsonSchema();
      } else if (val is Schema) {
        propsMap[entry.key] = val.toJsonSchema(isRoot: false);
      }
    }
    map['properties'] = propsMap;

    final req = effectiveRequired;
    if (req.isNotEmpty) {
      map['required'] = req;
    }

    return map;
  }

  @override
  ValidationResult validate(dynamic data) {
    if (data == null) {
      return const ValidationResult(
        isValid: false,
        errors: {'': 'Expected object but got null'},
      );
    }

    if (data is! Map) {
      return ValidationResult(
        isValid: false,
        errors: {'': 'Expected Map/object but got ${data.runtimeType}'},
      );
    }

    final errors = <String, String>{};
    final coerced = <String, dynamic>{};

    for (final entry in properties.entries) {
      final key = entry.key;
      final spec = entry.value;
      final rawValue = data[key];

      if (spec is Field) {
        if (!data.containsKey(key) || rawValue == null) {
          if (spec.required) {
            errors[key] = 'Required field "$key" is missing.';
          }
          continue;
        }

        final err = spec.validate(rawValue);
        if (err != null) {
          errors[key] = err;
        } else {
          final coercedVal = spec.coerce(rawValue);
          if (coercedVal != null || !spec.required) {
            coerced[key] = coercedVal;
          }
        }
      } else if (spec is Schema) {
        if (!data.containsKey(key) || rawValue == null) {
          if (effectiveRequired.contains(key)) {
            errors[key] = 'Required field "$key" is missing.';
          }
        } else {
          final subResult = spec.validate(rawValue);
          if (!subResult.isValid) {
            for (final subErr in subResult.errors.entries) {
              final path = subErr.key.isEmpty ? key : '$key.${subErr.key}';
              errors[path] = subErr.value;
            }
          } else {
            coerced[key] = subResult.coerced;
          }
        }
      }
    }

    // Check for any explicitly required properties not present in data
    for (final reqKey in effectiveRequired) {
      if (!data.containsKey(reqKey) || data[reqKey] == null) {
        if (!errors.containsKey(reqKey)) {
          errors[reqKey] = 'Required field "$reqKey" is missing.';
        }
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      coerced: errors.isEmpty ? coerced : null,
    );
  }
}

/// A schema describing a list/array of items conforming to [itemSchema].
class ListSchema extends Schema {
  /// Creates a [ListSchema].
  const ListSchema(
    this.itemSchema, {
    super.description,
    super.title,
    this.minItems,
    this.maxItems,
  }) : super._();

  /// The specification for elements of this list (either a [Field] or [Schema]).
  final dynamic itemSchema;

  /// Optional minimum item count.
  final int? minItems;

  /// Optional maximum item count.
  final int? maxItems;

  @override
  Map<String, dynamic> toJsonSchema({bool isRoot = true}) {
    final map = <String, dynamic>{
      if (isRoot) r'$schema': 'http://json-schema.org/draft-07/schema#',
      'type': 'array',
    };

    if (title != null) map['title'] = title;
    if (description != null) map['description'] = description;
    if (minItems != null) map['minItems'] = minItems;
    if (maxItems != null) map['maxItems'] = maxItems;

    if (itemSchema is Field) {
      map['items'] = (itemSchema as Field).toJsonSchema();
    } else if (itemSchema is Schema) {
      map['items'] = (itemSchema as Schema).toJsonSchema(isRoot: false);
    }

    return map;
  }

  @override
  ValidationResult validate(dynamic data) {
    if (data == null) {
      return const ValidationResult(
        isValid: false,
        errors: {'': 'Expected list but got null'},
      );
    }

    if (data is! List) {
      return ValidationResult(
        isValid: false,
        errors: {'': 'Expected List but got ${data.runtimeType}'},
      );
    }

    final errors = <String, String>{};
    final coerced = <dynamic>[];

    if (minItems != null && data.length < minItems!) {
      errors[''] = 'Item count ${data.length} is less than minItems $minItems.';
    }
    if (maxItems != null && data.length > maxItems!) {
      errors[''] = 'Item count ${data.length} exceeds maxItems $maxItems.';
    }

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final path = '[$i]';

      if (itemSchema is Field) {
        final field = itemSchema as Field;
        final err = field.validate(item);
        if (err != null) {
          errors[path] = err;
        } else {
          coerced.add(field.coerce(item));
        }
      } else if (itemSchema is Schema) {
        final subResult = (itemSchema as Schema).validate(item);
        if (!subResult.isValid) {
          for (final subErr in subResult.errors.entries) {
            final subPath =
                subErr.key.isEmpty ? path : '$path.${subErr.key}';
            errors[subPath] = subErr.value;
          }
        } else {
          coerced.add(subResult.coerced);
        }
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      coerced: errors.isEmpty ? coerced : null,
    );
  }
}
