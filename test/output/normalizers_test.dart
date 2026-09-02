import 'package:flutter_ai_scrapper/flutter_ai_scrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateNormalizer', () {
    test('parses ISO-8601 and returns normalized UTC string', () {
      final res = DateNormalizer.normalize('2026-09-02T14:30:00Z');
      expect(res, '2026-09-02T14:30:00.000Z');
    });

    test('parses common human-readable dates', () {
      final res1 = DateNormalizer.parse('September 2, 2026');
      expect(res1?.year, 2026);
      expect(res1?.month, 9);
      expect(res1?.day, 2);

      final res2 = DateNormalizer.parse('15 October 2025');
      expect(res2?.year, 2025);
      expect(res2?.month, 10);
      expect(res2?.day, 15);
    });

    test('resolves relative dates accurately against reference time', () {
      final ref = DateTime.utc(2026, 9, 2, 12, 0, 0);

      final yesterday = DateNormalizer.parse('yesterday', referenceTime: ref);
      expect(yesterday?.day, 1);
      expect(yesterday?.month, 9);

      final hoursAgo = DateNormalizer.parse('3 hours ago', referenceTime: ref);
      expect(hoursAgo?.hour, 9);

      final daysAgo = DateNormalizer.parse('2 days ago', referenceTime: ref);
      expect(daysAgo?.day, 31);
      expect(daysAgo?.month, 8);
    });
  });

  group('MoneyNormalizer', () {
    test('detects real currency symbols and codes without fabricating \$', () {
      final usd = MoneyNormalizer.normalize('\$49.99');
      expect(usd?.amount, 49.99);
      expect(usd?.currency, 'USD');

      final eur = MoneyNormalizer.normalize('€ 120.50');
      expect(eur?.amount, 120.50);
      expect(eur?.currency, 'EUR');

      final gbp = MoneyNormalizer.normalize('£15.00');
      expect(gbp?.amount, 15.00);
      expect(gbp?.currency, 'GBP');

      final jpy = MoneyNormalizer.normalize('¥ 5,000');
      expect(jpy?.amount, 5000.0);
      expect(jpy?.currency, 'JPY');

      final inr = MoneyNormalizer.normalize('₹ 999.00');
      expect(inr?.amount, 999.0);
      expect(inr?.currency, 'INR');

      // Closes fabricated-$ bug: no symbol -> no currency unless default passed
      final noSymbol = MoneyNormalizer.normalize('350.00');
      expect(noSymbol?.amount, 350.0);
      expect(noSymbol?.currency, isNull);
    });

    test('handles European decimal comma and thousands separators', () {
      // European: 1.499,95 €
      final eur = MoneyNormalizer.normalize('1.499,95 €');
      expect(eur?.amount, 1499.95);
      expect(eur?.currency, 'EUR');

      // US: $1,499.95
      final us = MoneyNormalizer.normalize('\$1,499.95');
      expect(us?.amount, 1499.95);
      expect(us?.currency, 'USD');
    });
  });

  group('PhoneNormalizer', () {
    test('normalizes domestic and international phone numbers to E.164', () {
      final us = PhoneNormalizer.normalize('(415) 555-2671');
      expect(us, '+14155552671');

      final intl = PhoneNormalizer.normalize('+44 20 7946 0958');
      expect(intl, '+442079460958');
    });

    test('rejects numbers that are too short or invalid', () {
      expect(PhoneNormalizer.normalize('1234'), isNull);
    });
  });

  group('UrlNormalizer', () {
    test('resolves relative URLs and strips tracking parameters', () {
      const raw = '/products/item?id=10&utm_source=newsletter&utm_medium=email&fbclid=abc123xyz';
      final clean = UrlNormalizer.normalize(raw, baseUrl: 'https://shop.example.com');

      expect(clean, 'https://shop.example.com/products/item?id=10');
      expect(clean, isNot(contains('utm_source')));
      expect(clean, isNot(contains('fbclid')));
    });
  });

  group('NumberNormalizer', () {
    test('normalizes locale-aware numbers, shorthand suffixes and percentages', () {
      expect(NumberNormalizer.normalize('1,234.50'), 1234.50);
      expect(NumberNormalizer.normalize('1.234,50'), 1234.50);
      expect(NumberNormalizer.normalize('25k'), 25000);
      expect(NumberNormalizer.normalize('1.5M'), 1500000);
      expect(NumberNormalizer.normalize('20%'), 0.20);
    });
  });
}
