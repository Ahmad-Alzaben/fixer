import 'package:fixer/core/money/currency.dart';

/// An immutable amount of money stored as integer minor units (e.g. fils).
///
/// Never uses floating point. Arithmetic between different currencies throws.
class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currency);

  const Money.zero(this.currency) : minorUnits = 0;

  final int minorUnits;
  final Currency currency;

  static final _pattern = RegExp(r'^(\d+)(?:\.(\d+))?$');

  /// Largest accepted amount is 999,999,999 in the major unit, which keeps
  /// every sum far inside 64-bit integers.
  static const maxWholeDigits = 9;

  /// Parses a non-negative decimal string such as `"1.45"`.
  ///
  /// Throws [FormatException] for negative, malformed, or over-precise input.
  factory Money.parse(String input, Currency currency) {
    final text = input.trim();
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw FormatException('Not a valid amount', input);
    }
    final whole = match.group(1)!;
    final fraction = match.group(2) ?? '';
    if (whole.replaceFirst(RegExp(r'^0+'), '').length > maxWholeDigits) {
      throw FormatException('Amount is too large', input);
    }
    if (fraction.length > currency.minorDigits) {
      throw FormatException(
        '${currency.code} allows at most ${currency.minorDigits} decimals',
        input,
      );
    }
    final padded = fraction.padRight(currency.minorDigits, '0');
    final minor =
        int.parse(whole) * currency.minorPerMajor +
        (padded.isEmpty ? 0 : int.parse(padded));
    return Money(minor, currency);
  }

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;

  Money operator +(Money other) {
    _checkCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _checkCurrency(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  int compareTo(Money other) {
    _checkCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  /// Plain decimal text at the currency's precision, e.g. `"1.957"`.
  String toDecimalString() {
    final digits = currency.minorDigits;
    final abs = minorUnits.abs();
    final sign = minorUnits < 0 ? '-' : '';
    if (digits == 0) return '$sign$abs';
    final whole = abs ~/ currency.minorPerMajor;
    final fraction = (abs % currency.minorPerMajor).toString().padLeft(
      digits,
      '0',
    );
    return '$sign$whole.$fraction';
  }

  void _checkCurrency(Money other) {
    if (other.currency.code != currency.code) {
      throw ArgumentError(
        'Currency mismatch: ${currency.code} vs ${other.currency.code}',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency.code == currency.code;

  @override
  int get hashCode => Object.hash(minorUnits, currency.code);

  @override
  String toString() => '${toDecimalString()} ${currency.code}';
}
