/// JSON-LD parser and harvester for Schema.org metadata.
library;

import 'dart:convert';

import '../dom/html_document.dart';

/// Harvester for `<script type="application/ld+json">` data blocks.
abstract final class JsonLdHarvester {
  /// Extracts and parses all JSON-LD blocks from [document].
  ///
  /// Unpacks `@graph` structures and top-level arrays into a flat list of
  /// JSON-LD object maps. Skips malformed blocks gracefully without throwing.
  static List<Map<String, dynamic>> extract(HtmlDocument document) {
    final results = <Map<String, dynamic>>[];

    for (final script in document.select('script[type="application/ld+json"]')) {
      final text = script.text.trim();
      if (text.isEmpty) continue;

      try {
        final decoded = jsonDecode(text);
        _collectObjects(decoded, results);
      } on FormatException {
        // Skip unparseable JSON-LD blocks silently
        continue;
      }
    }

    return results;
  }

  static void _collectObjects(dynamic node, List<Map<String, dynamic>> target) {
    if (node is List) {
      for (final item in node) {
        _collectObjects(item, target);
      }
    } else if (node is Map<String, dynamic>) {
      // Check for @graph
      final graph = node['@graph'];
      if (graph is List) {
        for (final item in graph) {
          _collectObjects(item, target);
        }
      } else {
        target.add(node);
      }
    } else if (node is Map) {
      final stringKeyed = node.map((k, v) => MapEntry(k.toString(), v));
      final graph = stringKeyed['@graph'];
      if (graph is List) {
        for (final item in graph) {
          _collectObjects(item, target);
        }
      } else {
        target.add(stringKeyed);
      }
    }
  }
}
