import 'package:fixer/core/money/allocation.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';

/// Computes each person's share of a [Bill].
///
/// Service and delivery fees are allocated with [allocation], weighted by
/// each person's item subtotal. The discount is then allocated weighted by
/// each person's subtotal + fee shares, which keeps every total >= 0.
/// Because every column is allocated exactly, every row and column adds up.
class BillCalculator {
  const BillCalculator({this.allocation = const ProportionalAllocation()});

  final AllocationStrategy allocation;

  BillCalculation calculate(Bill bill) {
    final currency = bill.currency;
    Money money(int minor) => Money(minor, currency);

    final subtotals = [
      for (final person in bill.people)
        person.items.fold<int>(0, (sum, item) => sum + item.price.minorUnits),
    ];
    final subtotal = subtotals.fold<int>(0, (a, b) => a + b);
    final service = bill.serviceFee.minorUnits;
    final delivery = bill.deliveryFee.minorUnits;
    final gross = subtotal + service + delivery;

    final warnings = <CalculationWarning>{};
    final requested = bill.discount.minorUnits;
    final discount = requested > gross ? gross : requested;
    if (requested > gross) {
      warnings.add(CalculationWarning.discountExceedsTotal);
    }

    if (bill.people.isEmpty) {
      warnings.add(CalculationWarning.noPeople);
      return BillCalculation(
        subtotal: money(subtotal),
        serviceFee: bill.serviceFee,
        deliveryFee: bill.deliveryFee,
        requestedDiscount: bill.discount,
        discount: money(discount),
        total: money(gross - discount),
        shares: const [],
        warnings: warnings,
      );
    }

    if (subtotal == 0 && service + delivery > 0) {
      warnings.add(CalculationWarning.feesSplitEqually);
    }

    final serviceShares = allocation.allocate(service, subtotals);
    final deliveryShares = allocation.allocate(delivery, subtotals);
    final personGross = [
      for (var i = 0; i < subtotals.length; i++)
        subtotals[i] + serviceShares[i] + deliveryShares[i],
    ];
    // The discount is weighted by each person's subtotal + rounded fee shares
    // (their "gross"), not by subtotal alone. With no fees this is identical
    // to weighting by subtotal. With fees it differs by at most a minor unit,
    // and it guarantees discount_i <= gross_i, so nobody goes negative.
    // (Weighting by subtotal alone let fee and discount leftovers land on
    // different people, e.g. totals of [1, 1, -1].)
    final discountShares = allocation.allocate(discount, personGross);

    final shares = [
      for (var i = 0; i < bill.people.length; i++)
        PersonShare(
          personId: bill.people[i].id,
          subtotal: money(subtotals[i]),
          serviceFee: money(serviceShares[i]),
          deliveryFee: money(deliveryShares[i]),
          discount: money(discountShares[i]),
          total: money(personGross[i] - discountShares[i]),
        ),
    ];

    return BillCalculation(
      subtotal: money(subtotal),
      serviceFee: bill.serviceFee,
      deliveryFee: bill.deliveryFee,
      requestedDiscount: bill.discount,
      discount: money(discount),
      total: money(gross - discount),
      shares: shares,
      warnings: warnings,
    );
  }
}
