# Rounding & allocation rule

Implemented in `lib/core/money/allocation.dart` and `lib/features/bill/domain/bill_calculator.dart`.

## Money
- All amounts are integers in the currency's minor unit (JOD → fils, 3 decimals). No `double` anywhere.
- Input is parsed from text; more decimals than the currency allows, negatives, and malformed input are rejected.

## Split mode (per bill)
Each bill has a switch in **Fees & discount**: **Equally** (default for new bills) or **By order** (proportional). Bills saved before v1.0.3 load as By order, which is how they were calculated.

## Steps for one bill
1. **Subtotals**: each person's subtotal is the sum of their item prices. The bill subtotal is the sum of those.
2. **Discount cap**: applied discount = min(discount, subtotal + service + delivery). If it was capped, warning `discountExceedsTotal`. The total is never below 0.
3. **Service fee** and 4. **Delivery fee**:
   - *Equally*: split into equal parts between everyone on the bill (also people with no items).
   - *By order*: weighted by each person's subtotal.
5. **Discount**:
   - *Equally*: equal parts, but nobody's discount exceeds what they owe (their *gross* = subtotal + service share + delivery share). A capped person's unused part is split equally among the others, repeated until it is all placed.
   - *By order*: weighted by each person's *gross*.
6. **Tax** (per bill: *No tax*, *Included*, *Added*; rate in basis points, 1600 = 16%, copied from Settings when the bill is created):
   - *Taxed amount* per person = max(0, subtotal + service share − discount share). Delivery is not taxed; the discount comes off the taxed part first. Bill taxed amount = max(0, subtotal + service − applied discount).
   - *Added*: bill tax = taxed amount × rate. *Included*: bill tax = taxed amount × rate / (100% + rate), shown only, not added.
   - The bill tax is rounded **half up** to a whole minor unit once, then allocated by each person's taxed amount (largest remainder, whatever the split mode).
7. **Person total** = subtotal + service share + delivery share − discount share (+ tax share when *Added*).

Tax example (16% added, equally): A 10.000, B 5.000, service 1.500, delivery 1.000 → taxed 10.750 / 5.750 → tax 2.640 split 1.720 / 0.920 → totals 12.970 / 7.170.

Example, items 4.000 / 4.123 / 4.000 with delivery 1.000: *Equally* → 0.334 / 0.333 / 0.333; *By order* → 0.330 / 0.340 / 0.330.

## Allocation method (largest remainder)
For an amount `A` and weights `w₁…wₙ` with total `W`:
1. Exact share `A·wᵢ / W`, computed with integers (no floats, `BigInt` for safety).
2. Floor every share.
3. Leftover = A − Σ floors (always < n). Give 1 unit each to the shares with the largest remainders.
4. **Tie-break:** the person listed earlier wins.
5. If every weight is 0 (nobody has priced items), split equally, same tie rule, warning `feesSplitEqually`.

## Guarantees (tested)
- Every column (service, delivery, discount, tax, total) sums **exactly** to the bill value.
- Every row satisfies subtotal + service + delivery − discount (+ tax when added) = total.
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
