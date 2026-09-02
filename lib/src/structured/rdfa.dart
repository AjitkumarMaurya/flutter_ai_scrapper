/// W3C RDFa Lite harvester (`vocab`, `typeof`, `property`).
library;

import 'package:html/dom.dart' as dom;

import '../dom/html_document.dart';
import '../dom/url_resolver.dart';

/// Harvester for RDFa Lite attributes.
abstract final class RdfaHarvester {
  /// Extracts all top-level RDFa entities from [document].
  static List<Map<String, dynamic>> extract(HtmlDocument document) {
    final results = <Map<String, dynamic>>[];
    final typedElements = document.raw.querySelectorAll('[typeof]');

    for (final element in typedElements) {
      if (_isTopLevelRdfa(element)) {
        final item = _parseRdfaItem(element, document.baseUrl);
        if (item.isNotEmpty) {
          results.add(item);
        }
      }
    }

    return results;
  }

  static bool _isTopLevelRdfa(dom.Element element) {
    if (element.attributes.containsKey('property')) return false;

    var parent = element.parent;
    while (parent != null) {
      if (parent.attributes.containsKey('typeof')) {
        return false;
      }
      parent = parent.parent;
    }
    return true;
  }

  static Map<String, dynamic> _parseRdfaItem(dom.Element root, String? baseUrl) {
    final item = <String, dynamic>{};

    final typeOf = root.attributes['typeof'];
    if (typeOf != null && typeOf.isNotEmpty) {
      item['@type'] = _cleanPrefix(typeOf);
    }

    final vocab = root.attributes['vocab'];
    if (vocab != null && vocab.isNotEmpty) {
      item['@vocab'] = vocab;
    }

    final about = root.attributes['about'] ?? root.attributes['resource'];
    if (about != null && about.isNotEmpty) {
      item['@id'] = about;
    }

    _collectProperties(root, root, item, baseUrl);

    return item;
  }

  static void _collectProperties(
    dom.Element scopeRoot,
    dom.Element current,
    Map<String, dynamic> item,
    String? baseUrl,
  ) {
    for (final child in current.children) {
      final property = child.attributes['property'];
      final isNestedType = child.attributes.containsKey('typeof');

      if (property != null && property.trim().isNotEmpty) {
        final propNames = property.trim().split(RegExp(r'\s+'));
        final dynamic propValue = isNestedType
            ? _parseRdfaItem(child, baseUrl)
            : _extractValue(child, baseUrl);

        for (final rawProp in propNames) {
          final propName = _cleanPrefix(rawProp);
          if (propName.isEmpty) continue;

          if (item.containsKey(propName)) {
            final existing = item[propName];
            if (existing is List) {
              existing.add(propValue);
            } else {
              item[propName] = [existing, propValue];
            }
          } else {
            item[propName] = propValue;
          }
        }

        if (isNestedType) continue;
      } else if (isNestedType) {
        continue;
      }

      _collectProperties(scopeRoot, child, item, baseUrl);
    }
  }

  static dynamic _extractValue(dom.Element element, String? baseUrl) {
    final content = element.attributes['content'];
    if (content != null) return content.trim();

    final resource = element.attributes['resource'];
    if (resource != null) {
      return UrlResolver.resolve(resource, baseUrl) ?? resource;
    }

    final href = element.attributes['href'];
    if (href != null) {
      return UrlResolver.resolve(href, baseUrl) ?? href;
    }

    final src = element.attributes['src'];
    if (src != null) {
      return UrlResolver.resolve(src, baseUrl) ?? src;
    }

    final datetime = element.attributes['datetime'];
    if (datetime != null && datetime.trim().isNotEmpty) {
      return datetime.trim();
    }

    return element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _cleanPrefix(String name) {
    final trimmed = name.trim();
    if (trimmed.contains(':')) {
      return trimmed.split(':').last;
    }
    if (trimmed.contains('/')) {
      return trimmed.split('/').last;
    }
    return trimmed;
  }
}
