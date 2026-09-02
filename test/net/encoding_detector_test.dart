import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  group('charset from Content-Type', () {
    test('reads a quoted or bare charset', () {
      expect(
        EncodingDetector.charsetFromContentType('text/html; charset=utf-8'),
        'utf-8',
      );
      expect(
        EncodingDetector.charsetFromContentType('text/html; charset="UTF-8"'),
        'utf-8',
      );
      expect(
        EncodingDetector.charsetFromContentType('text/html;charset=ISO-8859-1'),
        'iso-8859-1',
      );
    });

    test('normalises the common aliases', () {
      expect(EncodingDetector.charsetFromContentType('x; charset=utf8'), 'utf-8');
      expect(EncodingDetector.charsetFromContentType('x; charset=latin1'),
          'iso-8859-1');
      expect(EncodingDetector.charsetFromContentType('x; charset=cp1252'),
          'windows-1252');
    });

    test('is null when the header says nothing', () {
      expect(EncodingDetector.charsetFromContentType('text/html'), isNull);
      expect(EncodingDetector.charsetFromContentType(null), isNull);
    });
  });

  group('charset from markup', () {
    test('reads the HTML5 meta charset', () {
      final bytes = _bytes(
        utf8.encode('<html><head><meta charset="ISO-8859-1"></head>'),
      );
      expect(EncodingDetector.charsetFromMeta(bytes), 'iso-8859-1');
    });

    test('reads the HTML4 http-equiv form', () {
      final bytes = _bytes(utf8.encode(
        '<html><head><meta http-equiv="Content-Type" '
        'content="text/html; charset=windows-1252"></head>',
      ));
      expect(EncodingDetector.charsetFromMeta(bytes), 'windows-1252');
    });

    test('is null when the markup declares nothing', () {
      expect(
        EncodingDetector.charsetFromMeta(_bytes(utf8.encode('<html></html>'))),
        isNull,
      );
    });
  });

  group('detection order', () {
    test('a BOM outranks everything', () {
      final bytes = _bytes([
        0xEF, 0xBB, 0xBF, // UTF-8 BOM
        ...utf8.encode('<meta charset="iso-8859-1">'),
      ]);
      expect(
        EncodingDetector.detect(bytes, contentTypeHeader: 'text/html; charset=latin1'),
        'utf-8',
      );
    });

    test('the header outranks the markup', () {
      final bytes = _bytes(utf8.encode('<meta charset="iso-8859-1">'));
      expect(
        EncodingDetector.detect(bytes, contentTypeHeader: 'text/html; charset=utf-8'),
        'utf-8',
      );
    });

    test('markup is consulted when the header is silent', () {
      // 1.x looked only at the header and defaulted to UTF-8, so a page
      // declaring its encoding solely in markup came back as mojibake.
      final bytes = _bytes(utf8.encode('<meta charset="iso-8859-1">'));
      expect(EncodingDetector.detect(bytes, contentTypeHeader: 'text/html'),
          'iso-8859-1');
    });

    test('falls back to UTF-8 when nothing says otherwise', () {
      expect(EncodingDetector.detect(_bytes(utf8.encode('<html>'))), 'utf-8');
    });
  });

  group('decoding', () {
    test('round-trips UTF-8 including multi-byte characters', () {
      final bytes = _bytes(utf8.encode('Café — 日本語 — emoji 🎉'));
      expect(
        EncodingDetector.decode(bytes, contentTypeHeader: 'text/html; charset=utf-8'),
        'Café — 日本語 — emoji 🎉',
      );
    });

    test('strips a UTF-8 BOM from the output', () {
      final bytes = _bytes([0xEF, 0xBB, 0xBF, ...utf8.encode('Hello')]);
      expect(EncodingDetector.decode(bytes), 'Hello');
    });

    test('decodes Latin-1 high bytes', () {
      // 0xE9 is é in ISO-8859-1.
      final bytes = _bytes([0x43, 0x61, 0x66, 0xE9]);
      expect(
        EncodingDetector.decode(bytes,
            contentTypeHeader: 'text/html; charset=iso-8859-1'),
        'Café',
      );
    });

    test('never throws on malformed bytes', () {
      // An invalid UTF-8 sequence must degrade, not explode: a partly garbled
      // page is far more useful than an exception.
      final bytes = _bytes([0xFF, 0xFE, 0x41, 0xC3, 0x28, 0x42]);
      expect(
        () => EncodingDetector.decode(bytes,
            contentTypeHeader: 'text/html; charset=utf-8'),
        returnsNormally,
      );
    });

    test('an unsupported charset keeps the ASCII structure legible', () {
      // Dart ships no Shift_JIS codec. Lenient UTF-8 at least keeps tags,
      // attributes and URLs readable even when the prose is not.
      final bytes = _bytes(utf8.encode('<a href="/x">link</a>'));
      final decoded = EncodingDetector.decode(
        bytes,
        contentTypeHeader: 'text/html; charset=shift_jis',
      );
      expect(decoded, contains('href="/x"'));
    });

    test('an empty body decodes to an empty string', () {
      expect(EncodingDetector.decode(_bytes([])), '');
    });
  });
}
