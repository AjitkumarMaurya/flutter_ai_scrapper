import 'dart:convert';
import 'package:html/dom.dart' as dom;

class StructuredExtractor {
  /// Extracts JSON-LD, OpenGraph, and standard Meta tags from a parsed DOM.
  static Map<String, dynamic> extractAll(dom.Document document) {
    return {
      'openGraph': _extractOpenGraph(document),
      'jsonLd': _extractJsonLd(document),
      'meta': _extractMeta(document),
    };
  }

  static Map<String, String> _extractOpenGraph(dom.Document doc) {
    final og = <String, String>{};
    for (final meta in doc.querySelectorAll('meta[property^="og:"]')) {
      final prop = meta.attributes['property']?.substring(3);
      final content = meta.attributes['content']?.trim();
      if (prop != null && content != null && content.isNotEmpty) {
        og[prop] = content;
      }
    }
    return og;
  }

  static Map<String, String> _extractMeta(dom.Document doc) {
    final metaMap = <String, String>{};
    for (final meta in doc.querySelectorAll('meta[name]')) {
      final name = meta.attributes['name']?.toLowerCase().trim();
      final content = meta.attributes['content']?.trim();
      if (name != null && content != null && content.isNotEmpty) {
        metaMap[name] = content;
      }
    }
    return metaMap;
  }

  static List<Map<String, dynamic>> _extractJsonLd(dom.Document doc) {
    final list = <Map<String, dynamic>>[];
    final scripts = doc.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
      final raw = script.text.trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          list.add(decoded);
        } else if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) list.add(item);
          }
        }
      } catch (_) {
        // Ignore malformed JSON-LD blocks on broken sites
      }
    }
    return list;
  }
}
