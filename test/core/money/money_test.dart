import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Currency', () {
    test('JOD has 3 minor digits and is the default', () {
      expect(Currency.jod.minorDigits, 3);
      expect(Currency.defaultCurrency, Currency.jod);
    });

    test('looks up supported currencies by code', () {
      expect(Currency.byCode('USD'), Currency.usd);
      expect(Currency.byCode('jpy'), Currency.jpy);
      expect(Currency.byCode('XXX'), isNull);
    });
  });

  group('Money.parse', () {
    test('parses whole and fractional JOD amounts into fils', () {
      expect(Money.parse('1.45', Currency.jod).minorUnits, 1450);
      expect(Money.parse('3', Currency.jod).minorUnits, 3000);
      expect(Money.parse('0.005', Currency.jod).minorUnits, 5);
      expect(Money.parse(' 2.130 ', Currency.jod).minorUnits, 2130);
    });

    test('respects precision of 2-digit and 0-digit currencies', () {
      expect(Money.parse('1.4', Currency.usd).minorUnits, 140);
      expect(Money.parse('1200', Currency.jpy).minorUnits, 1200);
    });

    test('rejects more decimals than the currency allows', () {
      expect(() => Money.parse('1.2345', Currency.jod), throwsFormatException);
      expect(() => Money.parse('1.234', Currency.usd), throwsFormatException);
      expect(() => Money.parse('1.5', Currency.jpy), throwsFormatException);
    });

    test('rejects negative, empty and malformed input', () {
      for (final bad in [
        '-1',
        '',
        ' ',
        'abc',
        '1.2.3',
        '1,5',
        '.',
        '1.',
        '+1',
      ]) {
        expect(
          () => Money.parse(bad, Currency.jod),
          throwsFormatException,
          reason: 'input "$bad" should be rejected',
        );
      }
    });
  });

  group('Money arithmetic', () {
    final a = const Money(1450, Currency.jod);
    final b = const Money(1000, Currency.jod);

    test('adds and subtracts in minor units', () {
      expect(a + b, const Money(2450, Currency.jod));
      expect(a - b, const Money(450, Currency.jod));
    });

    test('refuses to mix currencies', () {
      expect(() => a + const Money(100, Currency.usd), throwsArgumentError);
      expect(() => a - const Money(100, Currency.usd), throwsArgumentError);
    });

    test('compares by value', () {
      expect(a > b, isTrue);
      expect(b < a, isTrue);
      expect(const Money.zero(Currency.jod).isZero, isTrue);
      expect(
        const Money(5, Currency.jod) == const Money(5, Currency.usd),
        isFalse,
      );
    });
  });

  group('Money.toDecimalString', () {
    test('pads to the currency precision', () {
      expect(const Money(1957, Currency.jod).toDecimalString(), '1.957');
      expect(const Money(5, Currency.jod).toDecimalString(), '0.005');
      expect(const Money(5, Currency.usd).toDecimalString(), '0.05');
      expect(const Money(1200, Currency.jpy).toDecimalString(), '1200');
      expect(const Money(0, Currency.jod).toDecimalString(), '0.000');
    });

    test('formats negative amounts with a leading minus', () {
      expect(const Money(-1957, Currency.jod).toDecimalString(), '-1.957');
    });
  });
}
