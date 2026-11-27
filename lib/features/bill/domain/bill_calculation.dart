import 'package:fixer/core/money/money.dart';

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
/// `subtotal + serviceFee + deliveryFee - discount == total`.
class PersonShare {
  const PersonShare({
    required this.personId,
    required this.subtotal,
    required this.serviceFee,
    required this.deliveryFee,
    required this.discount,
    required this.total,
  });

  final String personId;
  final Money subtotal;
  final Money serviceFee;
  final Money deliveryFee;
  final Money discount;
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
