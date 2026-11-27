import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/reports/domain/monthly_report.dart';
import 'package:flutter_test/flutter_test.dart';

Money jod(String s) => Money.parse(s, Currency.jod);

var _id = 0;

/// A bill where "Me" ordered [mine] and a friend ordered [theirs].
Bill bill({
  required DateTime at,
  String mine = '0',
  String theirs = '0',
  bool withMe = true,
  Set<String> tags = const {},
  String service = '0',
  Currency currency = Currency.jod,
}) {
  final n = _id++;
  Money m(String s) => Money.parse(s, currency);
  return Bill(
    id: 'b$n',
    currency: currency,
    createdAt: at,
    tagIds: tags,
    serviceFee: m(service),
    people: [
      Person(
        id: 'me$n',
        name: 'Me',
        isMe: withMe,
        items: [BillItem(id: 'i$n-a', price: m(mine))],
      ),
      Person(
        id: 'f$n',
        name: 'Friend',
        items: [BillItem(id: 'i$n-b', price: m(theirs))],
      ),
    ],
  );
}

void main() {
  test('no bills, no reports', () {
    expect(buildMonthlyReports(const []), isEmpty);
  });

  test('sums only my share of each bill in the month', () {
    final reports = buildMonthlyReports([
      bill(at: DateTime(2026, 11, 3), mine: '2', theirs: '5'),
      bill(at: DateTime(2026, 11, 20), mine: '1.5', theirs: '9'),
    ]);
    expect(reports, hasLength(1));
    expect(reports.single.month, const MonthKey(2026, 11));
    expect(reports.single.myTotal, jod('3.5'));
    expect(reports.single.billCount, 2);
  });

  test('my share includes my part of fees (brief example, Me = O)', () {
    final example = Bill(
      id: 'x',
      currency: Currency.jod,
      createdAt: DateTime(2026, 11, 27),
      serviceFee: jod('0.70'),
      discount: jod('2.13'),
      people: [
        Person(
          id: 'a',
          name: 'A',
          items: [
            BillItem(id: '1', price: jod('1.45')),
            BillItem(id: '2', price: jod('1.00')),
          ],
        ),
        Person(
          id: 'o',
          name: 'O',
          isMe: true,
          items: [BillItem(id: '3', price: jod('3'))],
        ),
        Person(
          id: 'j',
          name: 'J',
          items: [BillItem(id: '4', price: jod('1.65'))],
        ),
      ],
    );
    expect(buildMonthlyReports([example]).single.myTotal, jod('2.396'));
  });

  test('a bill with several tags counts toward each tag', () {
    final r = buildMonthlyReports([
      bill(at: DateTime(2026, 11, 1), mine: '2', tags: {'food', 'transport'}),
      bill(at: DateTime(2026, 11, 2), mine: '1', tags: {'food'}),
      bill(at: DateTime(2026, 11, 3), mine: '4'),
    ]).single;
    expect(r.myTotal, jod('7'));
    expect(r.byTag, {'food': jod('3'), 'transport': jod('2')});
    expect(r.untagged, jod('4'));
  });

  test('bills without anyone marked Me are counted but not summed', () {
    final r = buildMonthlyReports([
      bill(at: DateTime(2026, 11, 1), mine: '2'),
      bill(at: DateTime(2026, 11, 5), mine: '8', withMe: false),
    ]).single;
    expect(r.myTotal, jod('2'));
    expect(r.billCount, 1);
    expect(r.billsWithoutMe, 1);
  });

  test('a month with only "no Me" bills still appears, at zero', () {
    final r = buildMonthlyReports([
      bill(at: DateTime(2026, 10, 1), mine: '8', withMe: false),
    ]).single;
    expect(r.myTotal, jod('0'));
    expect(r.billsWithoutMe, 1);
  });

  test('months are separate and listed newest first', () {
    final reports = buildMonthlyReports([
      bill(at: DateTime(2026, 9, 30), mine: '1'),
      bill(at: DateTime(2026, 11, 1), mine: '3'),
      bill(at: DateTime(2026, 10, 15), mine: '2'),
    ]);
    expect(reports.map((r) => r.month), const [
      MonthKey(2026, 11),
      MonthKey(2026, 10),
      MonthKey(2026, 9),
    ]);
    expect(reports.map((r) => r.myTotal.minorUnits), [3000, 2000, 1000]);
  });

  test('different currencies are never added together', () {
    final reports = buildMonthlyReports([
      bill(at: DateTime(2026, 11, 1), mine: '2'),
      bill(at: DateTime(2026, 11, 2), mine: '10.00', currency: Currency.usd),
    ]);
    expect(reports, hasLength(2));
    expect(
      {for (final r in reports) r.currency.code: r.myTotal.minorUnits},
      {'JOD': 2000, 'USD': 1000},
    );
  });
}
