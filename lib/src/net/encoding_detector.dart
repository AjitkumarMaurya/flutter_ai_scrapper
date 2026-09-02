import 'dart:convert';
import 'dart:typed_data';

/// Decodes a response body into text, working out the charset first.
///
/// Order of evidence, strongest first: a byte-order mark, the `Content-Type`
/// header, then a `<meta charset>` in the markup. 1.x consulted only the
/// header and defaulted to UTF-8, so any page declaring its encoding solely in
/// markup — still common on older sites — came back with mojibake.
abstract final class EncodingDetector {
  /// Decodes [bytes] to a string.
  ///
  /// [contentTypeHeader] is the raw `Content-Type` value, when there was one.
  /// Decoding never throws: an undecodable byte becomes U+FFFD, because a
  /// partly-garbled page is far more useful than an exception.
  static String decode(Uint8List bytes, {String? contentTypeHeader}) {
    final charset = detect(bytes, contentTypeHeader: contentTypeHeader);
    return decodeWith(bytes, charset);
  }

  /// The charset name that best fits [bytes].
  static String detect(Uint8List bytes, {String? contentTypeHeader}) {
    final bom = _detectBom(bytes);
    if (bom != null) return bom;

    final fromHeader = charsetFromContentType(contentTypeHeader);
    if (fromHeader != null) return fromHeader;

    final fromMeta = charsetFromMeta(bytes);
    if (fromMeta != null) return fromMeta;

    return 'utf-8';
  }

  /// Decodes [bytes] using [charset], falling back to lenient UTF-8.
  static String decodeWith(Uint8List bytes, String charset) {
    final body = _stripBom(bytes, charset);

    try {
      switch (_normalize(charset)) {
        case 'utf-8':
          return utf8.decode(body, allowMalformed: true);
        case 'ascii':
          return ascii.decode(body, allowInvalid: true);
        case 'iso-8859-1':
        case 'windows-1252':
          // Not identical — windows-1252 fills 0x80–0x9F where Latin-1 has
          // control codes — but close enough that text stays readable, and
          // Dart ships no windows-1252 codec.
          return latin1.decode(body, allowInvalid: true);
        default:
          // UTF-16, Shift_JIS, GB2312, EUC-KR and friends need a codec Dart
          // does not include. Lenient UTF-8 keeps the ASCII structure —
          // tags, attributes, URLs — legible even when the prose is not.
          return utf8.decode(body, allowMalformed: true);
      }
    } on Object {
      return utf8.decode(body, allowMalformed: true);
    }
  }

  /// The charset named in a `Content-Type` header, if any.
  static String? charsetFromContentType(String? header) {
    if (header == null) return null;
    final match = RegExp(
      r'''charset\s*=\s*["']?([^"';\s]+)''',
      caseSensitive: false,
    ).firstMatch(header);
    final value = match?.group(1)?.trim();
    return (value == null || value.isEmpty) ? null : _normalize(value);
  }

  /// The charset declared by a `<meta>` tag in the document head.
  ///
  /// Scans only the first 4 KB: the declaration must appear early to be
  /// honoured by browsers, and scanning further would mean decoding the whole
  /// body before knowing how to decode it.
  static String? charsetFromMeta(Uint8List bytes) {
    final limit = bytes.length < 4096 ? bytes.length : 4096;
    final head = ascii.decode(bytes.sublist(0, limit), allowInvalid: true);

    // HTML5: <meta charset="utf-8">
    final html5 = RegExp(
      r'''<meta[^>]+charset\s*=\s*["']?([^"'>\s;]+)''',
      caseSensitive: false,
    ).firstMatch(head);
    if (html5 != null) return _normalize(html5.group(1)!);

    // HTML4: <meta http-equiv="Content-Type" content="text/html; charset=…">
    final html4 = RegExp(
      r'''<meta[^>]+http-equiv\s*=\s*["']?content-type["']?[^>]+content\s*=\s*["'][^"']*charset\s*=\s*([^"'>\s;]+)''',
      caseSensitive: false,
    ).firstMatch(head);
    if (html4 != null) return _normalize(html4.group(1)!);

    return null;
  }

  static String? _detectBom(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return 'utf-8';
    }
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) return 'utf-16le';
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) return 'utf-16be';
    }
    return null;
  }

  static Uint8List _stripBom(Uint8List bytes, String charset) {
    final normalized = _normalize(charset);
    if (normalized == 'utf-8' &&
        bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return Uint8List.sublistView(bytes, 3);
    }
    if ((normalized == 'utf-16le' || normalized == 'utf-16be') &&
        bytes.length >= 2) {
      return Uint8List.sublistView(bytes, 2);
    }
    return bytes;
  }

  static String _normalize(String charset) {
    final value = charset.toLowerCase().trim();
    return switch (value) {
      'utf8' || 'utf-8' => 'utf-8',
      'latin1' || 'latin-1' || 'iso-8859-1' || 'iso8859-1' || 'l1' =>
        'iso-8859-1',
      'cp1252' || 'windows-1252' || 'win-1252' => 'windows-1252',
      'us-ascii' || 'ascii' => 'ascii',
      _ => value,
    };
  }
}
