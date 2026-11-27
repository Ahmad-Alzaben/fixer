/// Splits an integer amount of minor units across weighted shares.
///
/// The result always has one entry per weight and sums exactly to [amount].
abstract interface class AllocationStrategy {
  List<int> allocate(int amount, List<int> weights);
}

/// Proportional split using the largest-remainder (Hamilton) method.
///
/// 1. Each share's exact value is `amount * weight / totalWeight`.
/// 2. Every share is floored to a whole minor unit.
/// 3. The leftover units (always fewer than the number of shares) go one
///    each to the shares with the largest fractional remainders.
/// 4. Equal remainders are broken by position: the earlier share wins.
///
/// If every weight is zero the amount is split equally (same tie rule).
/// Products are computed with [BigInt] so large amounts cannot overflow.
class ProportionalAllocation implements AllocationStrategy {
  const ProportionalAllocation();

  @override
  List<int> allocate(int amount, List<int> weights) {
    if (amount < 0) throw ArgumentError.value(amount, 'amount', 'negative');
    if (weights.any((w) => w < 0)) {
      throw ArgumentError.value(weights, 'weights', 'negative weight');
    }
    if (weights.isEmpty) {
      if (amount == 0) return const [];
      throw ArgumentError('Cannot allocate $amount across zero shares');
    }

    final effective = weights.every((w) => w == 0)
        ? List<int>.filled(weights.length, 1)
        : weights;

    final total = BigInt.from(effective.fold<int>(0, (sum, w) => sum + w));
    final bigAmount = BigInt.from(amount);

    final shares = List<int>.filled(effective.length, 0);
    final remainders = List<BigInt>.filled(effective.length, BigInt.zero);
    var allocated = 0;
    for (var i = 0; i < effective.length; i++) {
      final product = bigAmount * BigInt.from(effective[i]);
      shares[i] = (product ~/ total).toInt();
      remainders[i] = product.remainder(total);
      allocated += shares[i];
    }

    final order = List<int>.generate(effective.length, (i) => i)
      ..sort((a, b) {
        final byRemainder = remainders[b].compareTo(remainders[a]);
        return byRemainder != 0 ? byRemainder : a.compareTo(b);
      });

    for (var k = 0; k < amount - allocated; k++) {
      shares[order[k]] += 1;
    }
    return shares;
  }
}
