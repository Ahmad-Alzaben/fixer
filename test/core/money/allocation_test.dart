import 'package:fixer/core/money/allocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const strategy = ProportionalAllocation();

  group('ProportionalAllocation (largest remainder)', () {
    test('brief example: 5.670 JOD over subtotals 2.450 / 3.000 / 1.650', () {
      // Exact: 1956.55 / 2395.77 / 1317.68 -> floors 1956 / 2395 / 1317,
      // 2 leftover fils go to O (.77) then J (.68).
      expect(strategy.allocate(5670, [2450, 3000, 1650]), [1956, 2396, 1318]);
    });

    test('brief example service fee 0.700 JOD', () {
      // Exact: 241.55 / 295.77 / 162.68 -> leftover 2 to O then J.
      expect(strategy.allocate(700, [2450, 3000, 1650]), [241, 296, 163]);
    });

    test('brief example discount 2.130 JOD divides exactly', () {
      expect(strategy.allocate(2130, [2450, 3000, 1650]), [735, 900, 495]);
    });

    test('ties in the remainder go to the earlier person', () {
      expect(strategy.allocate(1, [1, 1, 1]), [1, 0, 0]);
      expect(strategy.allocate(2, [1, 1, 1]), [1, 1, 0]);
      expect(strategy.allocate(10, [1, 1, 1]), [4, 3, 3]);
    });

    test('a zero weight receives nothing while others have weight', () {
      expect(strategy.allocate(100, [0, 5, 5]), [0, 50, 50]);
      expect(strategy.allocate(101, [0, 1, 1]), [0, 51, 50]);
    });

    test('all-zero weights split equally', () {
      expect(strategy.allocate(100, [0, 0]), [50, 50]);
      expect(strategy.allocate(101, [0, 0, 0]), [34, 34, 33]);
    });

    test('zero amount allocates zeros', () {
      expect(strategy.allocate(0, [3, 7]), [0, 0]);
    });

    test('empty weights: zero amount is fine, positive amount is an error', () {
      expect(strategy.allocate(0, []), <int>[]);
      expect(() => strategy.allocate(5, []), throwsArgumentError);
    });

    test('rejects negative amount or weights', () {
      expect(() => strategy.allocate(-1, [1]), throwsArgumentError);
      expect(() => strategy.allocate(1, [1, -1]), throwsArgumentError);
    });

    test('does not overflow when amount x weight exceeds 64-bit int', () {
      // 4e12 * 3e6 = 1.2e19 > 2^63.
      expect(strategy.allocate(4000000000000, [3000000, 1000000]), [
        3000000000000,
        1000000000000,
      ]);
    });
  });
}
