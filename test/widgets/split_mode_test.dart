import 'package:fixer/features/bill/domain/bill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> threePeopleWithDelivery(WidgetTester tester) async {
  await addPerson(tester, 'A'); // id1
  await addPerson(tester, 'Z'); // id2
  await addPerson(tester, 'T'); // id3
  await addPrice(tester, 'id1', '4');
  await addPrice(tester, 'id2', '4.123');
  await addPrice(tester, 'id3', '4');
  await setAdjustment(tester, 'Delivery fee', '1');
}

void main() {
  testWidgets('new bills split equally; the switch shows it', (tester) async {
    await pumpApp(tester);
    await threePeopleWithDelivery(tester);

    final toggle = tester.widget<SegmentedButton<SplitMode>>(
      find.byType(SegmentedButton<SplitMode>),
    );
    expect(toggle.selected, {SplitMode.equal});

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    // Delivery 1.000 in equal parts: 0.334 / 0.333 / 0.333.
    expect(find.text('4.334 JOD'), findsOneWidget);
    expect(find.text('4.456 JOD'), findsOneWidget);
    expect(find.text('4.333 JOD'), findsOneWidget);
    expect(find.textContaining('split equally'), findsOneWidget);
  });

  testWidgets('switching to "By order" splits by what each person ordered', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await threePeopleWithDelivery(tester);
    await scrollTo(tester, find.text('By order'));
    await tester.tap(find.text('By order'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    // Proportional: 0.330 / 0.340 / 0.330.
    expect(find.text('4.330 JOD'), findsNWidgets(2));
    expect(find.text('4.463 JOD'), findsOneWidget);
    expect(find.textContaining('by what each person ordered'), findsOneWidget);

    // The choice is saved with the bill.
    await tester.pump(const Duration(milliseconds: 10));
    expect(h.bills.saved.values.single.splitMode, SplitMode.proportional);
  });

  testWidgets('the collapsed section says how fees are split', (tester) async {
    await pumpApp(tester);
    expect(find.textContaining('Split equally'), findsOneWidget);
  });
}
