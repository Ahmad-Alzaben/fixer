# Shared Bill Splitter --- App Brief for Claude

## 1. Project overview

Build a polished bill-splitting app for **Android first**, with the
option to support **iOS later**. The preferred technology is
**Flutter**. This is an initial product brief, not a final design or
architecture specification. I will provide design references and
architecture ideas later; do not make major assumptions silently.

## 2. Purpose

The app helps a group calculate what each person owes when people order
different items and the bill includes service fees, delivery fees,
and/or a total discount.

The main workflow should be fast: add people, enter their items and
prices, enter bill adjustments, and see each person's final share.

## 3. Calculation rules

### Default: proportional allocation

Distribute the service fee, delivery fee, and total discount
proportionally according to each person's item subtotal.

For each person:

-   `personSubtotal = sum(person item prices)`
-   `billSubtotal = sum(all person subtotals)`
-   `shareRatio = personSubtotal / billSubtotal`
-   `serviceShare = serviceFee * shareRatio`
-   `deliveryShare = deliveryFee * shareRatio`
-   `discountShare = totalDiscount * shareRatio`
-   `personFinal = personSubtotal + serviceShare + deliveryShare - discountShare`

An omitted adjustment is zero.

### Example

-   A: 1.45 + 1.00 = 2.45
-   O: 3.00
-   J: 1.65
-   Service fee: 0.70
-   Discount: 2.13
-   Delivery fee: 0.00

Subtotal = 7.10; final bill = 7.10 + 0.70 - 2.13 = **5.67**. Allocate
all adjustments proportionally. Displayed person totals must add up
exactly to the final bill after rounding.

### Money and rounding

-   Never use ordinary binary floating-point arithmetic for money. Use
    integer minor units or a suitable decimal type.
-   Make currency configurable; default to **JOD**.
-   Respect currency precision.
-   Round displayed person totals to the currency's minor unit.
-   Ensure the sum of person totals equals the bill total exactly. If
    rounding leaves a remainder, distribute it deterministically (for
    example, largest fractional remainder) and document the rule.
-   Do not divide by zero. Handle zero-value bills and people with no
    items.
-   Validate monetary inputs. Do not allow negative prices, fees, or
    discounts in the MVP.
-   Warn if the discount exceeds the amount available to discount.

## 4. MVP features

### Create and edit a bill

-   Start a new bill.
-   Add, rename, and remove people (for example A, J, R, O, F).
-   Add multiple items per person.
-   Each item has an optional description and a required price.
-   Support quick entry of a price without an item description.
-   Show each person's running subtotal.
-   Edit and delete items.

### Bill adjustments

-   Optional service fee, delivery fee, and total discount fields,
    defaulting to zero.

### Results

Show: - Bill subtotal, service fee, delivery fee, discount, and final
bill total. - Each person's item subtotal. - Each person's allocated
service fee, delivery fee, and discount. - Each person's final amount to
pay.

Make the final amount prominent; keep the detailed breakdown accessible
without cluttering the main result.

### Copy and share

-   Add **Copy results** and **Share results** actions.
-   Use the native platform share sheet.
-   Include each person's amount and the final bill total.
-   Format values using the selected currency.

Example format (illustrative only):

``` text
Bill total: 5.67 JOD

A: 1.96 JOD
O: 2.40 JOD
J: 1.31 JOD
```

### History --- confirm scope first

Potential later features: save bills with date/title, reopen and edit,
duplicate, and delete. Keep the design extensible, but ask me whether
history belongs in the first release before implementing persistence.

## 5. Design direction

I will provide design references and UI ideas later. Until then: - Use a
clean, modern, mobile-first layout. - Optimize amount entry for speed
and minimal taps. - Use clear labels and readable numeric values. -
Support small Android screens and different screen densities. - Do not
invent a brand, logo, or fixed color palette; use a neutral temporary
theme. - Consider dark mode, but ask before making it an MVP
requirement. - Avoid unnecessary charts, animations, and decoration.

## 6. Platform and technical direction

Preferred starting point: - Flutter and Dart. - Android as the first
target. - Structure the app so iOS can be added later. - Local-first and
usable offline. - No backend or authentication in the initial calculator
unless I request it. - Keep calculation logic independent from UI
widgets. - Separate presentation, application/business logic, and
persistence. - Use clear models for bills, people, items, adjustments,
and calculation results. - Keep money calculations in a dedicated,
well-tested module. - Avoid unnecessary dependencies and verify package
compatibility before adding packages.

Do not assume a state-management package, database, routing package, or
specific architecture pattern yet. Recommend options with trade-offs and
wait for my approval before making decisions that significantly shape
the project.

## 7. Suggested domain concepts

Treat these as starting points, not rigid implementation requirements:

-   **Bill:** id, optional title, currency, people, service fee,
    delivery fee, total discount, and creation date if history is
    enabled.
-   **Person:** id, display name, ordered items.
-   **BillItem:** id, optional description, price.
-   **BillCalculation:** bill subtotal, total fees, total discount,
    final total, and per-person breakdown.

Prefer deriving calculated values from source bill data rather than
storing duplicate totals.

## 8. Testing requirements

Write calculation unit tests before building the full UI. Cover: 1. One
person with multiple items. 2. Several people with different subtotals.
3. Equal subtotals. 4. Service fee only. 5. Delivery fee only. 6.
Discount only. 7. All adjustments together. 8. No adjustments. 9. Zero
subtotal. 10. Discount equal to subtotal. 11. Discount greater than
subtotal. 12. Rounding remainders. 13. A person with no items. 14.
Currency precision differences, if supported.

Verify that the sum of all per-person final amounts equals the bill
total exactly in minor units.

## 9. Work in phases

### Phase 1 --- Clarify and plan

1.  Summarize the requirements.
2.  Identify important ambiguities and ask only essential questions.
3.  Propose a Flutter project structure and architecture.
4.  Explain state-management and local-storage options with trade-offs.
5.  Wait for my approval before coding.

### Phase 2 --- Calculation foundation

1.  Define domain models.
2.  Implement proportional allocation.
3.  Implement deterministic rounding and remainder allocation.
4.  Add unit tests.
5.  Explain the rounding rule and show test results.

### Phase 3 --- Android MVP

1.  Build the bill-entry workflow.
2.  Add people and items.
3.  Add service fee, delivery fee, and discount.
4.  Display live calculations.
5.  Add copy and share.
6.  Verify Android screen sizes and input behavior.

### Phase 4 --- Review

1.  Review usability and edge cases.
2.  Refactor where appropriate.
3.  Check accessibility, keyboard behavior, and validation.
4.  Add history or other features only after discussing scope.
5.  Check readiness for future iOS support.

## 10. Collaboration rules

-   Treat my later design references and architecture decisions as the
    source of truth.
-   Do not make major assumptions silently.
-   Explain meaningful technical decisions briefly.
-   Prefer simple, maintainable solutions over unnecessary abstraction.
-   Do not add features just because similar apps commonly have them.
-   Keep the app focused on splitting bills quickly and accurately.
-   At the end of each phase, summarize what changed, what is complete,
    what remains, and what decisions are needed.

## 11. First task for Claude

Start with **Phase 1 --- Clarify and plan only**. Do not write
application code yet. Summarize this brief, identify important
unanswered questions, and propose a practical Flutter architecture for
an Android-first app that can later support iOS. Then wait for my
feedback, design references, and architecture ideas.
