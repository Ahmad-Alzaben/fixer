import 'dart:math';

import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';
import 'package:fixer/features/bill/domain/bill_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a bill from readable decimal strings. Person ids equal their names.
Bill bill(
  Map<String, List<String>> people, {
  String service = '0',
  String delivery = '0',
  String discount = '0',
  Currency currency = Currency.jod,
  String? me,
}) {
  Money m(String s) => Money.parse(s, currency);
  var itemId = 0;
  return Bill(
    id: 'b1',
    currency: currency,
    people: [
      for (final entry in people.entries)
        Person(
          id: entry.key,
          name: entry.key,
          isMe: entry.key == me,
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

/// Per-person (subtotal, service, delivery, discount, total) in minor units.
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

List<int> totals(BillCalculation c) => [
  for (final s in c.shares) s.total.minorUnits,
];

void main() {
  const calculator = BillCalculator();

  test('brief example: A 2.450, O 3.000, J 1.650, service 0.700, '
      'discount 2.130 -> 5.670 JOD', () {
    final c = calculator.calculate(
      bill(
        {
          'A': ['1.45', '1.00'],
          'O': ['3.00'],
          'J': ['1.65'],
        },
        service: '0.70',
        discount: '2.13',
      ),
    );
    expect(c.subtotal.minorUnits, 7100);
    expect(c.total.minorUnits, 5670);
    expect(rows(c), [
      [2450, 241, 0, 735, 1956],
      [3000, 296, 0, 900, 2396],
      [1650, 163, 0, 495, 1318],
    ]);
    expect(c.warnings, isEmpty);
  });

  test('1. one person with multiple items gets everything', () {
    final c = calculator.calculate(
      bill({
        'A': ['1.450', '1.000', '0.550'],
      }, service: '0.500'),
    );
    expect(rows(c), [
      [3000, 500, 0, 0, 3500],
    ]);
    expect(c.total.minorUnits, 3500);
  });

  test('2. several people with different subtotals', () {
    final c = calculator.calculate(
      bill({
        'A': ['1'],
        'B': ['3'],
        'C': ['4'],
      }, service: '0.800'),
    );
    expect(totals(c), [1100, 3300, 4400]);
  });

  test('3. equal subtotals split evenly; leftover goes to first person', () {
    final even = calculator.calculate(
      bill({
        'A': ['2'],
        'B': ['2'],
      }, delivery: '1'),
    );
    expect(totals(even), [2500, 2500]);

    final uneven = calculator.calculate(
      bill({
        'A': ['1'],
        'B': ['1'],
        'C': ['1'],
      }, service: '0.100'),
    );
    expect(totals(uneven), [1034, 1033, 1033]);
  });

  test('4. service fee only', () {
    final c = calculator.calculate(
      bill({
        'A': ['1'],
        'B': ['3'],
      }, service: '0.400'),
    );
    expect(rows(c), [
      [1000, 100, 0, 0, 1100],
      [3000, 300, 0, 0, 3300],
    ]);
  });

  test('5. delivery fee only', () {
    final c = calculator.calculate(
      bill({
        'A': ['1'],
        'B': ['3'],
      }, delivery: '1'),
    );
    expect(rows(c), [
      [1000, 0, 250, 0, 1250],
      [3000, 0, 750, 0, 3750],
    ]);
  });

  test('6. discount only', () {
    final c = calculator.calculate(
      bill({
        'A': ['1'],
        'B': ['3'],
      }, discount: '0.800'),
    );
    expect(rows(c), [
      [1000, 0, 0, 200, 800],
      [3000, 0, 0, 600, 2400],
    ]);
    expect(c.total.minorUnits, 3200);
  });

  test('7. all adjustments together', () {
    final c = calculator.calculate(
      bill(
        {
          'A': ['2'],
          'B': ['6'],
        },
        service: '0.800',
        delivery: '1.200',
        discount: '1',
      ),
    );
    expect(rows(c), [
      [2000, 200, 300, 250, 2250],
      [6000, 600, 900, 750, 6750],
    ]);
    expect(c.total.minorUnits, 9000);
  });

  test('8. no adjustments: everyone pays their subtotal', () {
    final c = calculator.calculate(
      bill({
        'A': ['1.250'],
        'B': ['0.750'],
      }),
    );
    expect(totals(c), [1250, 750]);
    expect(c.total.minorUnits, 2000);
    expect(c.warnings, isEmpty);
  });

  group('9. zero subtotal', () {
    test('with no fees: all zero, no error', () {
      final c = calculator.calculate(bill({'A': [], 'B': []}));
      expect(totals(c), [0, 0]);
      expect(c.total.minorUnits, 0);
      expect(c.warnings, isEmpty);
    });

    test('with fees: fees split equally and a warning is raised', () {
      final c = calculator.calculate(
        bill({
          'A': [],
          'B': ['0'],
        }, delivery: '1.001'),
      );
      expect(totals(c), [501, 500]);
      expect(c.total.minorUnits, 1001);
      expect(c.warnings, contains(CalculationWarning.feesSplitEqually));
    });
  });

  group('10. discount equal to subtotal', () {
    test('without fees: everyone pays zero, no warning', () {
      final c = calculator.calculate(
        bill({
          'A': ['1'],
          'B': ['2'],
        }, discount: '3'),
      );
      expect(totals(c), [0, 0]);
      expect(c.total.minorUnits, 0);
      expect(c.warnings, isEmpty);
    });

    test('with fees: people still pay their fee share', () {
      final c = calculator.calculate(
        bill(
          {
            'A': ['1'],
            'B': ['2'],
          },
          service: '0.300',
          discount: '3',
        ),
      );
      expect(rows(c), [
        [1000, 100, 0, 1000, 100],
        [2000, 200, 0, 2000, 200],
      ]);
      expect(c.warnings, isEmpty);
    });
  });

  test(
    '11. discount greater than subtotal + fees: capped at 0 with warning',
    () {
      final c = calculator.calculate(
        bill(
          {
            'A': ['1'],
            'B': ['2'],
          },
          service: '0.300',
          discount: '5',
        ),
      );
      expect(c.requestedDiscount.minorUnits, 5000);
      expect(c.discount.minorUnits, 3300);
      expect(c.total.minorUnits, 0);
      expect(rows(c), [
        [1000, 100, 0, 1100, 0],
        [2000, 200, 0, 2200, 0],
      ]);
      expect(c.warnings, contains(CalculationWarning.discountExceedsTotal));
    },
  );

  test('12. rounding remainders are distributed deterministically', () {
    final c = calculator.calculate(
      bill({
        'A': ['1'],
        'B': ['1'],
        'C': ['1'],
      }, discount: '0.001'),
    );
    expect(totals(c), [999, 1000, 1000]);
    expect(c.total.minorUnits, 2999);
  });

  test('13. a person with no items owes nothing', () {
    final c = calculator.calculate(
      bill({
        'A': ['2'],
        'B': [],
      }, service: '0.500'),
    );
    expect(rows(c), [
      [2000, 500, 0, 0, 2500],
      [0, 0, 0, 0, 0],
    ]);
  });

  group('14. currency precision', () {
    test('USD (2 decimals)', () {
      final c = calculator.calculate(
        bill(
          {
            'A': ['10.00'],
            'B': ['5.00'],
          },
          service: '1.00',
          currency: Currency.usd,
        ),
      );
      expect(totals(c), [1067, 533]);
      expect(c.total, const Money(1600, Currency.usd));
    });

    test('JPY (0 decimals)', () {
      final c = calculator.calculate(
        bill(
          {
            'A': ['1000'],
            'B': ['2000'],
          },
          service: '100',
          currency: Currency.jpy,
        ),
      );
      expect(totals(c), [1033, 2067]);
    });
  });

  group('never negative (regressions)', () {
    test(
      'equal fee split + discount does not push the last person below 0',
      () {
        // Fees 2+2 fils over 3 people -> gross [2, 2, 0]; a 3-fil discount must
        // not land on C, who received no fees. Discount over gross: 1.5 / 1.5 /
        // 0 -> floors [1, 1, 0], leftover to A (tie) -> [2, 1, 0].
        final c = calculator.calculate(
          bill(
            {'A': [], 'B': [], 'C': []},
            service: '0.002',
            delivery: '0.002',
            discount: '0.003',
          ),
        );
        expect(totals(c), [0, 1, 0]);
      },
    );

    test('discount is weighted by each person\'s subtotal + fee shares', () {
      // Subtotals [0, 1, 4] fils; service and delivery 2 fils each -> fee
      // shares [0, 0, 2] each, gross [0, 1, 8]. Discount 8 over gross:
      // 0 / 0.89 / 7.11 -> [0, 1, 7].
      final c = calculator.calculate(
        bill(
          {
            'A': ['0'],
            'B': ['0.001'],
            'C': ['0.004'],
          },
          service: '0.002',
          delivery: '0.002',
          discount: '0.008',
        ),
      );
      expect(rows(c), [
        [0, 0, 0, 0, 0],
        [1, 0, 0, 1, 0],
        [4, 2, 2, 7, 1],
      ]);
    });

    test('exhaustive: every small 3-person bill stays >= 0', () {
      Money m(int v) => Money(v, Currency.jod);
      for (var a = 0; a <= 5; a++) {
        for (var b = 0; b <= 5; b++) {
          for (var s = 0; s <= 5; s++) {
            for (var d = 0; d <= 5; d++) {
              final gross = a + b + 1 + s + d;
              for (var disc = 0; disc <= gross; disc++) {
                final r = calculator.calculate(
                  Bill(
                    id: 'x',
                    currency: Currency.jod,
                    people: [
                      for (final (i, v) in [a, b, 1].indexed)
                        Person(
                          id: '$i',
                          name: '$i',
                          items: [BillItem(id: '$i', price: m(v))],
                        ),
                    ],
                    serviceFee: m(s),
                    deliveryFee: m(d),
                    discount: m(disc),
                  ),
                );
                for (final share in r.shares) {
                  expect(
                    share.total.isNegative,
                    isFalse,
                    reason: 'subs [$a,$b,1] svc $s del $d disc $disc',
                  );
                }
              }
            }
          }
        }
      }
    });
  });

  group('edge cases', () {
    test('no people: empty breakdown and a warning', () {
      final c = calculator.calculate(bill({}, service: '1'));
      expect(c.shares, isEmpty);
      expect(c.warnings, contains(CalculationWarning.noPeople));
    });

    test('shareOf finds the person marked Me', () {
      final b = bill(
        {
          'A': ['1'],
          'B': ['3'],
        },
        service: '0.400',
        me: 'B',
      );
      final c = calculator.calculate(b);
      expect(c.shareOf(b.me!.id)!.total.minorUnits, 3300);
    });
  });

  group('model validation', () {
    test('rejects a negative item price', () {
      expect(
        () => BillItem(id: 'x', price: const Money(-1, Currency.jod)),
        throwsArgumentError,
      );
    });

    test('rejects negative fees or discount', () {
      expect(
        () => Bill(
          id: 'b',
          currency: Currency.jod,
          people: const [],
          serviceFee: const Money(-1, Currency.jod),
        ),
        throwsArgumentError,
      );
    });

    test('rejects amounts in a different currency than the bill', () {
      expect(
        () => Bill(
          id: 'b',
          currency: Currency.jod,
          people: [
            Person(
              id: 'A',
              name: 'A',
              items: [BillItem(id: 'i', price: const Money(1, Currency.usd))],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects more than one person marked Me', () {
      expect(
        () => Bill(
          id: 'b',
          currency: Currency.jod,
          people: [
            Person(id: 'A', name: 'A', isMe: true),
            Person(id: 'B', name: 'B', isMe: true),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  test('property: 5000 random bills always balance exactly and never go '
      'negative', () {
    final random = Random(42);
    for (var run = 0; run < 5000; run++) {
      final people = <String, List<String>>{};
      final personCount = 1 + random.nextInt(6);
      for (var p = 0; p < personCount; p++) {
        people['P$p'] = [
          for (var i = 0; i < random.nextInt(5); i++)
            Money(random.nextInt(20000), Currency.jod).toDecimalString(),
        ];
      }
      String rnd(int max) =>
          Money(random.nextInt(max), Currency.jod).toDecimalString();
      final b = bill(
        people,
        service: rnd(3000),
        delivery: rnd(3000),
        discount: rnd(random.nextBool() ? 5000 : 60000),
      );
      final c = calculator.calculate(b);
      final reason = 'run $run: $people';

      int sum(int Function(PersonShare s) f) =>
          c.shares.fold(0, (acc, s) => acc + f(s));

      expect(
        sum((s) => s.total.minorUnits),
        c.total.minorUnits,
        reason: reason,
      );
      expect(
        sum((s) => s.serviceFee.minorUnits),
        c.serviceFee.minorUnits,
        reason: reason,
      );
      expect(
        sum((s) => s.deliveryFee.minorUnits),
        c.deliveryFee.minorUnits,
        reason: reason,
      );
      expect(
        sum((s) => s.discount.minorUnits),
        c.discount.minorUnits,
        reason: reason,
      );
      for (final s in c.shares) {
        expect(
          s.subtotal.minorUnits +
              s.serviceFee.minorUnits +
              s.deliveryFee.minorUnits -
              s.discount.minorUnits,
          s.total.minorUnits,
          reason: reason,
        );
        expect(s.total.isNegative, isFalse, reason: '$reason -> ${s.total}');
      }
    }
  });
}
