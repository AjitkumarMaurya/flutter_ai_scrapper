/// Deterministic URL resolution and tracking query parameter sanitization.
library;

/// Normalizes URLs to absolute addresses and removes marketing tracking parameters.
abstract final class UrlNormalizer {
  static const _trackingParams = {
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'fbclid',
    'gclid',
    'msclkid',
    'mc_cid',
    'mc_eid',
    '_hsenc',
    '_hsmi',
    'igshid',
  };

  /// Normalizes [input] URL:
  ///
  /// - Resolves relative paths against [baseUrl]
  /// - Strips tracking and analytics query parameters (`utm_*`, `fbclid`, `gclid`)
  /// - Normalizes host to lowercase
  static String? normalize(
    String input, {
    String? baseUrl,
    bool removeFragment = false,
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final Uri parsed;
    try {
      final initialUri = Uri.parse(trimmed);
      if (!initialUri.hasScheme && baseUrl != null && baseUrl.isNotEmpty) {
        final base = Uri.parse(baseUrl);
        parsed = base.resolveUri(initialUri);
      } else {
        parsed = initialUri;
      }
    } catch (_) {
      return null;
    }

    if (!parsed.hasScheme || !parsed.hasAuthority) {
      return null;
    }

    // Clean tracking query parameters
    final cleanQuery = Map<String, String>.from(parsed.queryParameters)
      ..removeWhere((key, _) => _trackingParams.contains(key.toLowerCase()));

    final normalized = Uri(
      scheme: parsed.scheme.toLowerCase(),
      userInfo: parsed.userInfo,
      host: parsed.host.toLowerCase(),
      port: parsed.hasPort ? parsed.port : null,
      path: parsed.path.isEmpty ? '/' : parsed.path,
      queryParameters: cleanQuery.isNotEmpty ? cleanQuery : null,
      fragment: removeFragment ? null : (parsed.hasFragment ? parsed.fragment : null),
    );

    return normalized.toString();
  }
}
