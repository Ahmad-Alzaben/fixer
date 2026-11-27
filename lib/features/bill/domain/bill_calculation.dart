import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';

enum CalculationWarning {
  /// The bill has no people, so nothing could be allocated.
  noPeople,

  /// The discount was larger than subtotal + fees; it was capped so the
  /// total is zero.
  discountExceedsTotal,

  /// No item has a price, so fees were split equally between people.
  feesSplitEqually,
}

/// One person's row in the results. Always satisfies
/// `subtotal + serviceFee + deliveryFee - discount (+ tax when added) == total`.
/// With tax included in prices, [tax] is the part of the total that is tax.
class PersonShare {
  const PersonShare({
    required this.personId,
    required this.subtotal,
    required this.serviceFee,
    required this.deliveryFee,
    required this.discount,
    required this.tax,
    required this.total,
  });

  final String personId;
  final Money subtotal;
  final Money serviceFee;
  final Money deliveryFee;
  final Money discount;
  final Money tax;
  final Money total;
}

/// Derived result of a bill. Every column of [shares] sums exactly to the
/// matching bill-level value.
class BillCalculation {
  BillCalculation({
    required this.subtotal,
    required this.serviceFee,
    required this.deliveryFee,
    required this.requestedDiscount,
    required this.discount,
    required this.taxMode,
    required this.taxRate,
    required this.tax,
    required this.total,
    required List<PersonShare> shares,
    required Set<CalculationWarning> warnings,
  }) : shares = List.unmodifiable(shares),
       warnings = Set.unmodifiable(warnings);

  final Money subtotal;
  final Money serviceFee;
  final Money deliveryFee;

  /// The discount the user entered.
  final Money requestedDiscount;

  /// The discount actually applied (capped at subtotal + fees).
  final Money discount;

  final TaxMode taxMode;

  /// Basis points (1600 = 16%).
  final int taxRate;

  /// Tax added on top, or the tax part of the total when included in prices.
  /// Zero for [TaxMode.none].
  final Money tax;

  final Money total;
  final List<PersonShare> shares;
  final Set<CalculationWarning> warnings;

  PersonShare? shareOf(String personId) {
    for (final s in shares) {
      if (s.personId == personId) return s;
    }
    return null;
  }
}
