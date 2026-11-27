import 'dart:math';

import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';
import 'package:fixer/features/bill/domain/bill_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

Money jod(String s) => Money.parse(s, Currency.jod);

Bill equalBill(
  Map<String, List<String>> people, {
  String service = '0',
  String delivery = '0',
  String discount = '0',
  SplitMode mode = SplitMode.equal,
}) {
  var n = 0;
  return Bill(
    id: 'b',
    currency: Currency.jod,
    splitMode: mode,
    people: [
      for (final e in people.entries)
        Person(
          id: e.key,
          name: e.key,
          items: [
            for (final p in e.value) BillItem(id: 'i${n++}', price: jod(p)),
          ],
        ),
    ],
    serviceFee: jod(service),
    deliveryFee: jod(delivery),
    discount: jod(discount),
  );
}

List<List<int>> rows(BillCalculation c) => [
  for (final s in c.shares)
    [
      s.subtotal.minorUnits,
      s.serviceFee.minorUnits,
      s.deliveryFee.minorUnits,
      s.discount.minorUnits,
      s.total.minorUnits,
    ],
];

void main() {
  const calc = BillCalculator();

  test('a bill without a stored mode (older data) stays proportional', () {
    expect(
      Bill(id: 'x', currency: Currency.jod, people: const []).splitMode,
      SplitMode.proportional,
    );
  });

  test('brief example split equally: fees and discount in equal parts', () {
    final c = calc.calculate(
      equalBill(
        {
          'A': ['1.45', '1.00'],
          'O': ['3.00'],
          'J': ['1.65'],
        },
        service: '0.70',
        discount: '2.13',
      ),
    );
    // Service 700 / 3 -> 234, 233, 233 (leftover fil to the first person).
    // Discount 2130 / 3 -> 710 each.
    expect(rows(c), [
      [2450, 234, 0, 710, 1974],
      [3000, 233, 0, 710, 2523],
      [1650, 233, 0, 710, 1173],
    ]);
    expect(c.total.minorUnits, 5670);
  });

  test('delivery 1.000 over three people: 0.334 / 0.333 / 0.333', () {
    final c = calc.calculate(
      equalBill({
        'A': ['4'],
        'Z': ['4.123'],
        'T': ['4'],
      }, delivery: '1'),
    );
    expect(c.shares.map((s) => s.deliveryFee.minorUnits), [334, 333, 333]);
  });

  test('someone who ordered nothing still pays an equal fee share', () {
    final c = calc.calculate(
      equalBill({
        'A': ['6'],
        'B': [],
      }, delivery: '2'),
    );
    expect(rows(c), [
      [6000, 0, 1000, 0, 7000],
      [0, 0, 1000, 0, 1000],
    ]);
    expect(c.warnings, isEmpty);
  });

  test('a discount bigger than someone\'s bill stops at zero; the rest '
      'goes equally to the others', () {
    final c = calc.calculate(
      equalBill({
        'A': ['0.5'],
        'B': ['4.5'],
        'C': ['5'],
      }, discount: '3'),
    );
    // Equal would be 1000 each, but A only owes 500: A gets 500 and the
    // other 500 is split between B and C (250 each).
    expect(rows(c), [
      [500, 0, 0, 500, 0],
      [4500, 0, 0, 1250, 3250],
      [5000, 0, 0, 1250, 3750],
    ]);
    expect(c.total.minorUnits, 7000);
  });

  test('proportional mode is unchanged (brief example)', () {
    final c = calc.calculate(
      equalBill(
        {
          'A': ['1.45', '1.00'],
          'O': ['3.00'],
          'J': ['1.65'],
        },
        service: '0.70',
        discount: '2.13',
        mode: SplitMode.proportional,
      ),
    );
    expect(c.shares.map((s) => s.total.minorUnits), [1956, 2396, 1318]);
  });

  test('property: 5000 random equal-split bills balance and never go '
      'negative', () {
    final random = Random(7);
    for (var run = 0; run < 5000; run++) {
      final people = <String, List<String>>{
        for (var p = 0; p < 1 + random.nextInt(6); p++)
          'P$p': [
            for (var i = 0; i < random.nextInt(4); i++)
              Money(random.nextInt(20000), Currency.jod).toDecimalString(),
          ],
      };
      String rnd(int max) =>
          Money(random.nextInt(max), Currency.jod).toDecimalString();
      final c = calc.calculate(
        equalBill(
          people,
          service: rnd(3000),
          delivery: rnd(3000),
          discount: rnd(random.nextBool() ? 4000 : 60000),
        ),
      );
      int sum(int Function(PersonShare s) f) =>
          c.shares.fold(0, (a, s) => a + f(s));
      final reason = 'run $run: $people';
      expect(
        sum((s) => s.total.minorUnits),
        c.total.minorUnits,
        reason: reason,
      );
      expect(
        sum((s) => s.discount.minorUnits),
        c.discount.minorUnits,
        reason: reason,
      );
      expect(
        sum((s) => s.serviceFee.minorUnits),
        c.serviceFee.minorUnits,
        reason: reason,
      );
      for (final s in c.shares) {
        expect(s.total.isNegative, isFalse, reason: '$reason -> ${s.total}');
      }
    }
  });
}
