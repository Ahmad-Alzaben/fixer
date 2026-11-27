import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculator.dart';

/// A calendar month.
class MonthKey implements Comparable<MonthKey> {
  const MonthKey(this.year, this.month);

  MonthKey.of(DateTime date) : this(date.year, date.month);

  final int year;
  final int month;

  @override
  int compareTo(MonthKey other) =>
      year != other.year ? year - other.year : month - other.month;

  @override
  bool operator ==(Object other) =>
      other is MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}

/// What "Me" spent in one month, in one currency.
///
/// A bill with several tags counts in full toward each of them, so the
/// [byTag] values can add up to more than [myTotal].
class MonthlyReport {
  MonthlyReport({
    required this.month,
    required this.currency,
    required this.myTotal,
    required Map<String, Money> byTag,
    required this.untagged,
    required this.billCount,
    required this.billsWithoutMe,
  }) : byTag = Map.unmodifiable(byTag);

  final MonthKey month;
  final Currency currency;
  final Money myTotal;

  /// Tag id -> my share of bills carrying that tag.
  final Map<String, Money> byTag;

  /// My share of bills with no tag.
  final Money untagged;

  /// Bills with someone marked "Me" (included in [myTotal]).
  final int billCount;

  /// Bills nobody is marked "Me" on (not included in [myTotal]).
  final int billsWithoutMe;
}

/// Groups bills by month and currency, newest month first.
List<MonthlyReport> buildMonthlyReports(
  Iterable<Bill> bills, {
  BillCalculator calculator = const BillCalculator(),
}) {
  final builders = <(MonthKey, String), _Builder>{};
  for (final bill in bills) {
    final created = bill.createdAt;
    if (created == null) continue;
    final key = (MonthKey.of(created), bill.currency.code);
    final b = builders.putIfAbsent(key, () => _Builder(key.$1, bill.currency));

    final me = bill.me;
    if (me == null) {
      b.billsWithoutMe++;
      continue;
    }
    final share =
        calculator.calculate(bill).shareOf(me.id)?.total.minorUnits ?? 0;
    b.billCount++;
    b.total += share;
    if (bill.tagIds.isEmpty) {
      b.untagged += share;
    } else {
      for (final tag in bill.tagIds) {
        b.byTag[tag] = (b.byTag[tag] ?? 0) + share;
      }
    }
  }

  final reports = [for (final b in builders.values) b.build()]
    ..sort((a, b) {
      final byMonth = b.month.compareTo(a.month);
      return byMonth != 0
          ? byMonth
          : a.currency.code.compareTo(b.currency.code);
    });
  return reports;
}

class _Builder {
  _Builder(this.month, this.currency);

  final MonthKey month;
  final Currency currency;
  int total = 0;
  int untagged = 0;
  int billCount = 0;
  int billsWithoutMe = 0;
  final byTag = <String, int>{};

  MonthlyReport build() {
    Money m(int v) => Money(v, currency);
    return MonthlyReport(
      month: month,
      currency: currency,
      myTotal: m(total),
      byTag: {for (final e in byTag.entries) e.key: m(e.value)},
      untagged: m(untagged),
      billCount: billCount,
      billsWithoutMe: billsWithoutMe,
    );
  }
}
