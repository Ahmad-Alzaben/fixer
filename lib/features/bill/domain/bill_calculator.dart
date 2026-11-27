import 'package:fixer/core/money/allocation.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';
import 'package:fixer/features/bill/domain/tax.dart';

/// Computes each person's share of a [Bill].
///
/// [SplitMode.equal]: service and delivery are split in equal parts; the
/// discount too, but nobody's discount exceeds what they owe.
/// [SplitMode.proportional]: service and delivery are weighted by each
/// person's item subtotal; the discount by subtotal + fee shares.
/// Tax ([TaxMode.added] or [TaxMode.included]) is charged on items +
/// service fee minus the discount, rounded half up once for the bill, and
/// split by each person's taxed amount whatever the split mode.
/// Either way every total is >= 0, and because every column is allocated
/// exactly (largest remainder), every row and column adds up.
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
        taxMode: bill.taxMode,
        taxRate: bill.taxRate,
        tax: money(0),
        total: money(gross - discount),
        shares: const [],
        warnings: warnings,
      );
    }

    final equal = bill.splitMode == SplitMode.equal;
    if (!equal && subtotal == 0 && service + delivery > 0) {
      warnings.add(CalculationWarning.feesSplitEqually);
    }

    // Equal: every person weighs the same. Proportional: weight = subtotal.
    final feeWeights = equal
        ? List<int>.filled(subtotals.length, 1)
        : subtotals;
    final serviceShares = allocation.allocate(service, feeWeights);
    final deliveryShares = allocation.allocate(delivery, feeWeights);
    final personGross = [
      for (var i = 0; i < subtotals.length; i++)
        subtotals[i] + serviceShares[i] + deliveryShares[i],
    ];
    final discountShares = equal
        ? _equalCapped(discount, personGross)
        // Weighted by each person's subtotal + rounded fee shares (their
        // "gross"), not by subtotal alone. With no fees this is identical
        // to weighting by subtotal. With fees it differs by at most a minor
        // unit, and it guarantees discount_i <= gross_i, so nobody goes
        // negative. (Weighting by subtotal alone let fee and discount
        // leftovers land on different people, e.g. totals of [1, 1, -1].)
        : allocation.allocate(discount, personGross);

    // Taxed: items + service, minus the discount (which comes off the taxed
    // part first), never below zero.
    final taxable = [
      for (var i = 0; i < subtotals.length; i++)
        _atLeastZero(subtotals[i] + serviceShares[i] - discountShares[i]),
    ];
    final tax = _billTax(bill, _atLeastZero(subtotal + service - discount));
    // tax > 0 implies some taxable weight > 0, so no equal fallback here.
    final taxShares = allocation.allocate(tax, taxable);
    final added = bill.taxMode == TaxMode.added;

    final shares = [
      for (var i = 0; i < bill.people.length; i++)
        PersonShare(
          personId: bill.people[i].id,
          subtotal: money(subtotals[i]),
          serviceFee: money(serviceShares[i]),
          deliveryFee: money(deliveryShares[i]),
          discount: money(discountShares[i]),
          tax: money(taxShares[i]),
          total: money(
            personGross[i] - discountShares[i] + (added ? taxShares[i] : 0),
          ),
        ),
    ];

    return BillCalculation(
      subtotal: money(subtotal),
      serviceFee: bill.serviceFee,
      deliveryFee: bill.deliveryFee,
      requestedDiscount: bill.discount,
      discount: money(discount),
      taxMode: bill.taxMode,
      taxRate: bill.taxRate,
      tax: money(tax),
      total: money(gross - discount + (added ? tax : 0)),
      shares: shares,
      warnings: warnings,
    );
  }

  static int _atLeastZero(int v) => v < 0 ? 0 : v;

  /// The bill's tax on [taxable], rounded half up to a whole minor unit.
  /// Added: taxable × rate. Included: the tax part of a price that already
  /// contains it, taxable × rate / (100% + rate).
  static int _billTax(Bill bill, int taxable) {
    final rate = bill.taxRate;
    final (numerator, denominator) = switch (bill.taxMode) {
      TaxMode.none => (0, 1),
      TaxMode.added => (rate, maxTaxRate),
      TaxMode.included => (rate, maxTaxRate + rate),
    };
    // round(a / b) half up for a, b >= 0 is (2a + b) ~/ 2b.
    final a = BigInt.from(taxable) * BigInt.from(numerator);
    final b = BigInt.from(denominator);
    return ((a * BigInt.two + b) ~/ (b * BigInt.two)).toInt();
  }

  /// Splits [amount] equally, but never gives anyone more than their cap
  /// (what they owe). A capped person's unused part is split equally among
  /// the others, repeating until everything is placed. Requires
  /// `amount <= sum(caps)`, which holds because the discount is capped at
  /// the bill total.
  List<int> _equalCapped(int amount, List<int> caps) {
    final result = List<int>.filled(caps.length, 0);
    var remaining = amount;
    var open = [
      for (var i = 0; i < caps.length; i++)
        if (caps[i] > 0) i,
    ];
    while (remaining > 0 && open.isNotEmpty) {
      final shares = allocation.allocate(
        remaining,
        List<int>.filled(open.length, 1),
      );
      final capped = [
        for (var k = 0; k < open.length; k++)
          if (result[open[k]] + shares[k] >= caps[open[k]]) open[k],
      ];
      if (capped.isEmpty) {
        for (var k = 0; k < open.length; k++) {
          result[open[k]] += shares[k];
        }
        remaining = 0;
      } else {
        // Fill the capped people to their cap, then re-split the rest.
        for (final i in capped) {
          remaining -= caps[i] - result[i];
          result[i] = caps[i];
        }
        open = open.where((i) => !capped.contains(i)).toList();
      }
    }
    return result;
  }
}
