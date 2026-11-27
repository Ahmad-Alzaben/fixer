# Rounding & allocation rule

Implemented in `lib/core/money/allocation.dart` and `lib/features/bill/domain/bill_calculator.dart`.

## Money
- All amounts are integers in the currency's minor unit (JOD → fils, 3 decimals). No `double` anywhere.
- Input is parsed from text; more decimals than the currency allows, negatives, and malformed input are rejected.

## Steps for one bill
1. **Subtotals**: each person's subtotal is the sum of their item prices. The bill subtotal is the sum of those.
2. **Discount cap**: applied discount = min(discount, subtotal + service + delivery). If it was capped, warning `discountExceedsTotal`. The total is never below 0.
3. **Service fee** is allocated weighted by subtotal.
4. **Delivery fee** is allocated weighted by subtotal.
5. **Discount** is allocated weighted by each person's *gross* = subtotal + their service share + their delivery share.
6. **Person total** = subtotal + service share + delivery share − discount share.

## Allocation method (largest remainder)
For an amount `A` and weights `w₁…wₙ` with total `W`:
1. Exact share `A·wᵢ / W`, computed with integers (no floats, `BigInt` for safety).
2. Floor every share.
3. Leftover = A − Σ floors (always < n). Give 1 unit each to the shares with the largest remainders.
4. **Tie-break:** the person listed earlier wins.
5. If every weight is 0 (nobody has priced items), split equally, same tie rule, warning `feesSplitEqually`.

## Guarantees (tested)
- Every column (service, delivery, discount, total) sums **exactly** to the bill value.
- Every row satisfies subtotal + service + delivery − discount = total.
- No person total is ever negative.

## Brief example (JOD, 3 decimals)
A 2.450 · O 3.000 · J 1.650 · service 0.700 · discount 2.130 → **5.670**

| | Subtotal | Service | Discount | **Total** |
|---|---|---|---|---|
| A | 2.450 | 0.241 | 0.735 | **1.956** |
| O | 3.000 | 0.296 | 0.900 | **2.396** |
| J | 1.650 | 0.163 | 0.495 | **1.318** |
| Sum | 7.100 | 0.700 | 2.130 | **5.670** |

## One difference from the brief's formula (step 5)
The brief says `discountShare = totalDiscount × personSubtotal / billSubtotal`. Fixer weights the discount by *subtotal + fee shares* instead, because:
- Rounding each column separately with subtotal weights could leave someone at −0.001 (an exhaustive search found 1,962 small bills where it happened, e.g. totals of [1, 1, −1] fils).
- Weighting by gross makes each person's discount ≤ their gross, so a negative total is impossible.
- **Without fees the result is identical to the brief.** With fees, a person's discount differs from the literal formula by at most about one minor unit (0.001 JOD). In the brief's example it is identical.
