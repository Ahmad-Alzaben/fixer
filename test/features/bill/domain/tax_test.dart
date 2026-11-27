import 'dart:math';

import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';
import 'package:fixer/features/bill/domain/bill_calculator.dart';
import 'package:fixer/features/bill/domain/tax.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a bill from readable decimal strings. Person ids equal their names.
Bill taxBill(
  Map<String, List<String>> people, {
  TaxMode mode = TaxMode.added,
  int rate = 1600,
  String service = '0',
  String delivery = '0',
  String discount = '0',
  SplitMode split = SplitMode.equal,
  Currency currency = Currency.jod,
}) {
  Money m(String s) => Money.parse(s, currency);
  var itemId = 0;
  return Bill(
    id: 'b1',
    currency: currency,
    splitMode: split,
    taxMode: mode,
    taxRate: rate,
    people: [
      for (final entry in people.entries)
        Person(
          id: entry.key,
          name: entry.key,
          items: [
            for (final price in entry.value)
              BillItem(id: 'i${itemId++}', price: m(price)),
          ],
        ),
    ],
    serviceFee: m(service),
    deliveryFee: m(delivery),
    discount: m(discount),
  );
}

List<int> taxes(BillCalculation c) => [
  for (final s in c.shares) s.tax.minorUnits,
];

List<int> totals(BillCalculation c) => [
  for (final s in c.shares) s.total.minorUnits,
];

void main() {
  const calculator = BillCalculator();

  group('tax rate text', () {
    test('parses whole and decimal percentages into basis points', () {
      expect(parseTaxPercent('16'), 1600);
      expect(parseTaxPercent(' 7.5 '), 750);
      expect(parseTaxPercent('16.25'), 1625);
      expect(parseTaxPercent('0'), 0);
      expect(parseTaxPercent('100'), 10000);
    });

    test('rejects blank, negative, over-precise or over 100%', () {
      for (final bad in ['', '-1', '16.255', '100.01', '101', 'abc', '.']) {
        expect(() => parseTaxPercent(bad), throwsFormatException, reason: bad);
      }
    });

    test('formats basis points without trailing zeros', () {
      expect(formatTaxPercent(1600), '16');
      expect(formatTaxPercent(750), '7.5');
      expect(formatTaxPercent(1625), '16.25');
      expect(formatTaxPercent(5), '0.05');
    });
  });

  group('tax added on top', () {
    test('is charged on items and split by what each person ordered', () {
      final c = calculator.calculate(
        taxBill({
          'A': ['10'],
          'B': ['5'],
        }),
      );
      expect(c.tax.minorUnits, 2400);
      expect(taxes(c), [1600, 800]);
      expect(totals(c), [11600, 5800]);
      expect(c.total.minorUnits, 17400);
    });

    test('taxes the service fee but not the delivery fee', () {
      final c = calculator.calculate(
        taxBill(
          {
            'A': ['10'],
            'B': ['5'],
          },
          service: '1.5',
          delivery: '1',
        ),
      );
      // Taxed: A 10 + 0.750, B 5 + 0.750 = 16.500 → 2.640.
      expect(c.tax.minorUnits, 2640);
      expect(taxes(c), [1720, 920]);
      expect(totals(c), [12970, 7170]);
      expect(c.total.minorUnits, 20140);
    });

    test('is calculated after the discount', () {
      final c = calculator.calculate(
        taxBill(
          {
            'A': ['10'],
            'B': ['10'],
          },
          discount: '2',
        ),
      );
      // 20 − 2 = 18 taxed → 2.880.
      expect(c.tax.minorUnits, 2880);
      expect(taxes(c), [1440, 1440]);
      expect(c.total.minorUnits, 20880);
    });

    test('is zero when the discount covers everything taxable', () {
      final c = calculator.calculate(
        taxBill(
          {
            'A': ['1'],
          },
          delivery: '2',
          discount: '2',
        ),
      );
      expect(c.tax.isZero, isTrue);
      expect(c.total.minorUnits, 1000);
    });

    test('rounds the bill tax half up to the minor unit', () {
      // 0.025 × 10% = 0.0025 → 0.003.
      final up = calculator.calculate(
        taxBill({
          'A': ['0.025'],
        }, rate: 1000),
      );
      expect(up.tax.minorUnits, 3);
      // 1.003 × 16% = 0.16048 → 0.160.
      final down = calculator.calculate(
        taxBill({
          'A': ['1.003'],
        }),
      );
      expect(down.tax.minorUnits, 160);
    });

    test('a person with nothing taxable pays no tax', () {
      final c = calculator.calculate(
        taxBill({
          'A': ['10'],
          'B': [],
        }, split: SplitMode.proportional),
      );
      expect(taxes(c), [1600, 0]);
    });

    test('a 0% rate adds nothing', () {
      final c = calculator.calculate(
        taxBill({
          'A': ['10'],
        }, rate: 0),
      );
      expect(c.tax.isZero, isTrue);
      expect(c.total.minorUnits, 10000);
    });
  });

  group('tax included in prices', () {
    test('does not change any total and shows the tax part', () {
      final people = {
        'A': ['11.6'],
        'B': ['5.8'],
      };
      final included = calculator.calculate(
        taxBill(people, mode: TaxMode.included),
      );
      final none = calculator.calculate(taxBill(people, mode: TaxMode.none));
      expect(totals(included), totals(none));
      expect(included.total, none.total);
      // 17.400 × 16 / 116 = 2.400.
      expect(included.tax.minorUnits, 2400);
      expect(taxes(included), [1600, 800]);
    });
  });

  test('no tax: tax is zero even with a rate set', () {
    final c = calculator.calculate(
      taxBill({
        'A': ['10'],
      }, mode: TaxMode.none),
    );
    expect(c.tax.isZero, isTrue);
    expect(c.taxMode, TaxMode.none);
    expect(c.total.minorUnits, 10000);
  });

  test('rejects a rate below 0% or above 100%', () {
    expect(() => taxBill({}, rate: -1), throwsArgumentError);
    expect(() => taxBill({}, rate: 10001), throwsArgumentError);
  });

  test('property: 3000 random taxed bills balance exactly, never negative', () {
    final random = Random(7);
    String amount(int max) {
      final minor = random.nextInt(max);
      return Money(minor, Currency.jod).toDecimalString();
    }

    for (var n = 0; n < 3000; n++) {
      final people = {
        for (var p = 0; p < 1 + random.nextInt(5); p++)
          'P$p': [for (var i = 0; i < random.nextInt(4); i++) amount(20000)],
      };
      final mode = TaxMode.values[random.nextInt(TaxMode.values.length)];
      final b = taxBill(
        people,
        mode: mode,
        rate: random.nextInt(3001),
        service: amount(3000),
        delivery: amount(3000),
        discount: amount(30000),
        split: SplitMode.values[random.nextInt(SplitMode.values.length)],
      );
      final c = calculator.calculate(b);
      final reason = 'bill $n';
      int sum(Money Function(PersonShare) f) =>
          c.shares.fold(0, (s, p) => s + f(p).minorUnits);

      expect(sum((s) => s.tax), c.tax.minorUnits, reason: reason);
      expect(sum((s) => s.total), c.total.minorUnits, reason: reason);
      for (final s in c.shares) {
        final added = mode == TaxMode.added ? s.tax.minorUnits : 0;
        expect(
          s.subtotal.minorUnits +
              s.serviceFee.minorUnits +
              s.deliveryFee.minorUnits -
              s.discount.minorUnits +
              added,
          s.total.minorUnits,
          reason: reason,
        );
        expect(s.total.isNegative, isFalse, reason: reason);
        expect(s.tax.isNegative, isFalse, reason: reason);
      }
      final preTax =
          c.subtotal.minorUnits +
          c.serviceFee.minorUnits +
          c.deliveryFee.minorUnits -
          c.discount.minorUnits;
      expect(
        c.total.minorUnits,
        preTax + (mode == TaxMode.added ? c.tax.minorUnits : 0),
        reason: reason,
      );
    }
  });
}
