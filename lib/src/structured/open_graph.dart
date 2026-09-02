/// OpenGraph, Twitter Cards and standard meta-tag harvester.
library;

import '../dom/html_document.dart';
import '../dom/url_resolver.dart';

/// Harvester for OpenGraph, Twitter Card and standard HTML meta tags.
abstract final class OpenGraphHarvester {
  /// Extracts OpenGraph, Twitter and meta properties from [document].
  static Map<String, dynamic> extract(HtmlDocument document) {
    final meta = <String, dynamic>{};

    for (final element in document.select('meta[property], meta[name]')) {
      final key = (element.attr('property') ?? element.attr('name'))?.trim();
      final content = element.attr('content')?.trim();

      if (key != null && key.isNotEmpty && content != null && content.isNotEmpty) {
        // Resolve URLs for known image/url properties
        final resolved = (key.contains('image') || key.contains('url'))
            ? (UrlResolver.resolve(content, document.baseUrl) ?? content)
            : content;

        if (meta.containsKey(key)) {
          final existing = meta[key];
          if (existing is List) {
            existing.add(resolved);
          } else {
            meta[key] = [existing, resolved];
          }
        } else {
          meta[key] = resolved;
        }
      }
    }

    final canonical = document.selectFirst('link[rel=canonical]')?.attr('href');
    if (canonical != null && canonical.isNotEmpty) {
      meta['canonical'] = UrlResolver.resolve(canonical, document.baseUrl) ?? canonical;
    }

    final title = document.title;
    if (title != null && title.isNotEmpty && !meta.containsKey('title')) {
      meta['title'] = title;
    }

    return meta;
  }
}
