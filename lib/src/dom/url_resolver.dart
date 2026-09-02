/// Turns page-relative URLs into absolute ones.
///
/// Scraped `href` and `src` values are usually relative (`/about`, `pic.jpg`,
/// `//cdn.example/x`). Handing those back raw makes results unusable without
/// the caller reimplementing this, so resolution happens once, here.
abstract final class UrlResolver {
  /// Resolves [reference] against [baseUrl].
  ///
  /// [baseUrl] should already account for any `<base href>` on the page — see
  /// [effectiveBase]. Returns `null` for values that are not navigable
  /// locations at all: empty strings, bare fragments, and the `javascript:`,
  /// `mailto:`, `tel:` and `data:` schemes. Callers that want those (an email
  /// harvester, say) should read the raw attribute instead.
  static String? resolve(String? reference, String? baseUrl) {
    if (reference == null) return null;

    final ref = reference.trim();
    if (ref.isEmpty) return null;
    if (ref.startsWith('#')) return null;

    final lower = ref.toLowerCase();
    for (final scheme in const [
      'javascript:',
      'mailto:',
      'tel:',
      'sms:',
      'data:',
      'about:',
      'blob:',
    ]) {
      if (lower.startsWith(scheme)) return null;
    }

    if (baseUrl == null || baseUrl.isEmpty) {
      return _isAbsolute(ref) ? ref : null;
    }

    try {
      return Uri.parse(baseUrl).resolve(ref).toString();
    } on FormatException {
      return _isAbsolute(ref) ? ref : null;
    }
  }

  /// The base a document's relative URLs should resolve against.
  ///
  /// A `<base href>` element wins over the URL the page was fetched from, per
  /// the HTML spec — and a relative `<base href>` is itself resolved against
  /// the fetch URL first.
  static String? effectiveBase({String? baseHref, String? documentUrl}) {
    if (baseHref == null || baseHref.trim().isEmpty) return documentUrl;

    final href = baseHref.trim();
    if (_isAbsolute(href)) return href;

    if (documentUrl == null) return null;
    try {
      return Uri.parse(documentUrl).resolve(href).toString();
    } on FormatException {
      return documentUrl;
    }
  }

  static bool _isAbsolute(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme;
  }
}
