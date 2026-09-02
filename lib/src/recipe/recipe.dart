import '../schema/schema.dart';

/// Rule for extracting a single schema field via CSS selector.
class FieldSelector {
  /// Creates a [FieldSelector].
  const FieldSelector({
    required this.selector,
    this.attribute = 'text',
    this.regex,
  });

  /// Creates a [FieldSelector] from JSON.
  factory FieldSelector.fromJson(Map<String, dynamic> json) => FieldSelector(
        selector: json['selector'] as String? ?? '',
        attribute: json['attribute'] as String? ?? 'text',
        regex: json['regex'] as String?,
      );

  /// CSS selector relative to the parent container or document root.
  final String selector;

  /// Target attribute to read: `'text'`, `'href'`, `'src'`, etc.
  final String attribute;

  /// Optional regular expression to isolate a specific value substring.
  final String? regex;

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
        'selector': selector,
        if (attribute != 'text') 'attribute': attribute,
        if (regex != null) 'regex': regex,
      };

  @override
  String toString() => 'FieldSelector(selector: "$selector", attr: "$attribute")';
}

/// A cached, site-specific extraction recipe mapping CSS selectors to schema properties.
class Recipe {
  /// Creates a [Recipe].
  Recipe({
    required this.id,
    required this.host,
    required this.schemaHash,
    this.containerSelector,
    required this.fields,
    this.confidence = 0.95,
    DateTime? createdAt,
    this.ttl = const Duration(days: 7),
  }) : createdAt = createdAt ?? DateTime.now();

  /// Computes a deterministic hash signature for [schema].
  static String hashSchema(Schema schema) {
    if (schema is ObjectSchema) {
      final sortedKeys = schema.properties.keys.toList()..sort();
      return 'obj_${sortedKeys.join("_")}';
    } else if (schema is ListSchema) {
      if (schema.itemSchema is ObjectSchema) {
        final sortedKeys =
            (schema.itemSchema as ObjectSchema).properties.keys.toList()..sort();
        return 'list_${sortedKeys.join("_")}';
      }
      return 'list_primitive';
    }
    return 'generic';
  }

  /// Deserializes a [Recipe] from JSON.
  factory Recipe.fromJson(Map<String, dynamic> json) {
    final fieldsMap = <String, FieldSelector>{};
    final rawFields = json['fields'] as Map<String, dynamic>? ?? {};
    for (final entry in rawFields.entries) {
      if (entry.value is Map<String, dynamic>) {
        fieldsMap[entry.key] =
            FieldSelector.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    return Recipe(
      id: json['id'] as String? ?? '',
      host: json['host'] as String? ?? '',
      schemaHash: json['schemaHash'] as String? ?? '',
      containerSelector: json['containerSelector'] as String?,
      fields: fieldsMap,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.95,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      ttl: json['ttlSeconds'] != null
          ? Duration(seconds: json['ttlSeconds'] as int)
          : const Duration(days: 7),
    );
  }

  /// Unique identifier for this recipe.
  final String id;

  /// Host domain this recipe applies to (e.g. `'shop.example'`).
  final String host;

  /// Hash signature of the target schema.
  final String schemaHash;

  /// Container selector for list items, or null for single-entity object schemas.
  final String? containerSelector;

  /// Per-property field selectors.
  final Map<String, FieldSelector> fields;

  /// Model-assigned or verified confidence score.
  final double confidence;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Time-to-live duration before the recipe requires re-validation.
  final Duration ttl;

  /// Whether the recipe has exceeded its time-to-live.
  bool get isExpired => DateTime.now().isAfter(createdAt.add(ttl));

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'host': host,
        'schemaHash': schemaHash,
        if (containerSelector != null) 'containerSelector': containerSelector,
        'fields': fields.map((k, v) => MapEntry(k, v.toJson())),
        'confidence': confidence,
        'createdAt': createdAt.toIso8601String(),
        'ttlSeconds': ttl.inSeconds,
      };
}
