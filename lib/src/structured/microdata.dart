/// W3C HTML Microdata harvester (`itemscope`, `itemtype`, `itemprop`).
library;

import 'package:html/dom.dart' as dom;

import '../dom/html_document.dart';
import '../dom/url_resolver.dart';

/// Harvester for HTML Microdata attributes.
abstract final class MicrodataHarvester {
  /// Extracts all top-level Microdata items from [document].
  static List<Map<String, dynamic>> extract(HtmlDocument document) {
    final results = <Map<String, dynamic>>[];
    final rootElements = document.raw.querySelectorAll('[itemscope]');

    for (final element in rootElements) {
      // Only extract top-level items (not nested inside another item unless without itemprop)
      if (_isTopLevelItem(element)) {
        final item = _parseItem(element, document.baseUrl);
        if (item.isNotEmpty) {
          results.add(item);
        }
      }
    }

    return results;
  }

  static bool _isTopLevelItem(dom.Element element) {
    if (element.attributes.containsKey('itemprop')) return false;

    var parent = element.parent;
    while (parent != null) {
      if (parent.attributes.containsKey('itemscope')) {
        return false;
      }
      parent = parent.parent;
    }
    return true;
  }

  static Map<String, dynamic> _parseItem(dom.Element scopeElement, String? baseUrl) {
    final item = <String, dynamic>{};

    final itemType = scopeElement.attributes['itemtype'];
    if (itemType != null && itemType.isNotEmpty) {
      item['@type'] = _simplifyType(itemType);
    }

    final itemId = scopeElement.attributes['itemid'];
    if (itemId != null && itemId.isNotEmpty) {
      item['@id'] = itemId;
    }

    // Collect item properties within this scope (not descending into child scopes unless they are properties)
    _collectProperties(scopeElement, scopeElement, item, baseUrl);

    return item;
  }

  static void _collectProperties(
    dom.Element scopeRoot,
    dom.Element current,
    Map<String, dynamic> item,
    String? baseUrl,
  ) {
    for (final child in current.children) {
      final itemprop = child.attributes['itemprop'];
      final isNestedScope = child.attributes.containsKey('itemscope');

      if (itemprop != null && itemprop.trim().isNotEmpty) {
        final propNames = itemprop.trim().split(RegExp(r'\s+'));
        final dynamic propValue = isNestedScope
            ? _parseItem(child, baseUrl)
            : _extractValue(child, baseUrl);

        for (final propName in propNames) {
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

        // If it was a nested scope, do not descend further into it for the parent item
        if (isNestedScope) continue;
      } else if (isNestedScope) {
        // Child has itemscope but no itemprop — it is an independent item, do not descend
        continue;
      }

      // Recurse into child elements
      _collectProperties(scopeRoot, child, item, baseUrl);
    }
  }

  static dynamic _extractValue(dom.Element element, String? baseUrl) {
    final tag = element.localName?.toLowerCase();

    switch (tag) {
      case 'meta':
        return element.attributes['content']?.trim() ?? '';

      case 'audio' || 'embed' || 'iframe' || 'img' || 'source' || 'track' || 'video':
        final src = element.attributes['src'];
        if (src != null) {
          return UrlResolver.resolve(src, baseUrl) ?? src;
        }
        return '';

      case 'a' || 'area' || 'link':
        final href = element.attributes['href'];
        if (href != null) {
          return UrlResolver.resolve(href, baseUrl) ?? href;
        }
        return '';

      case 'object':
        final data = element.attributes['data'];
        if (data != null) {
          return UrlResolver.resolve(data, baseUrl) ?? data;
        }
        return '';

      case 'data' || 'meter':
        return element.attributes['value']?.trim() ?? element.text.trim();

      case 'time':
        final datetime = element.attributes['datetime'];
        if (datetime != null && datetime.trim().isNotEmpty) {
          return datetime.trim();
        }
        return element.text.trim();

      default:
        return element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }

  static String _simplifyType(String typeUri) {
    final trimmed = typeUri.trim();
    if (trimmed.contains('/')) {
      return trimmed.split('/').last;
    }
    if (trimmed.contains('#')) {
      return trimmed.split('#').last;
    }
    return trimmed;
  }
}
