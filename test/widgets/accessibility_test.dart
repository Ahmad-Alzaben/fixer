import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

// Phase 4: Flutter's built-in accessibility guidelines on every main screen,
// and very large text on a small phone.

Money jod(String s) => Money.parse(s, Currency.jod);

Harness seededHarness() {
  final h = Harness();
  h.bills.save(
    Bill(
      id: 'b1',
      title: 'Dinner at a restaurant with a rather long name',
      currency: Currency.jod,
      createdAt: DateTime(2026, 11, 20),
      tagIds: const {'tag-food'},
      serviceFee: jod('1.5'),
      people: [
        Person(
          id: 'p1',
          name: 'Ahmad',
          isMe: true,
          items: [BillItem(id: 'i1', price: jod('12.345'))],
        ),
        Person(
          id: 'p2',
          name: 'Bartholomew Maximilian Longname-Example',
          items: [BillItem(id: 'i2', price: jod('99999.999'))],
        ),
      ],
    ),
  );
  return h;
}

/// Puts a bill with people, prices and fees into the editor.
Future<void> fillEditor(WidgetTester tester) async {
  await addPerson(tester, 'Ahmad');
  await addPerson(tester, 'Bartholomew Maximilian Longname-Example');
  await addPrice(tester, 'id1', '12.345');
  await addPrice(tester, 'id2', '99999.999');
  await setAdjustment(tester, 'Service fee', '1.5');
  await setAdjustment(tester, 'Discount', '0.25');
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Each screen reachable in the app, opened from a fresh start.
final screens = <String, Future<void> Function(WidgetTester)>{
  'Split (filled)': (t) async {
    await fillEditor(t);
    // Back up to the first person card (we end near the fees, below it).
    await t.scrollUntilVisible(
      find.text('Ahmad'),
      -150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
  },
  'Results': (t) async {
    await fillEditor(t);
    await t.tap(find.text('Results'));
    await t.pumpAndSettle();
  },
  'History': (t) => openTab(t, 'History'),
  'Reports': (t) => openTab(t, 'Reports'),
  'Settings': (t) => openTab(t, 'Settings'),
  'Templates': (t) async {
    await openTab(t, 'Settings');
    await scrollTo(t, find.text('Message templates'));
    await t.tap(find.text('Message templates'));
    await t.pumpAndSettle();
  },
};

void main() {
  for (final MapEntry(key: name, value: open) in screens.entries) {
    group(name, () {
      testWidgets('meets tap-target, label and contrast guidelines', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpApp(tester, harness: seededHarness());
        await open(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });

      testWidgets('200% text on a 320dp phone does not overflow', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(
          tester,
          size: const Size(320, 640),
          harness: seededHarness(),
        );
        await open(tester);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
