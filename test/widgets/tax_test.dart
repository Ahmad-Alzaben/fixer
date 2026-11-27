import 'package:fixer/features/bill/domain/bill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> chooseTaxMode(WidgetTester tester, String label) async {
  final segment = find.descendant(
    of: find.byType(SegmentedButton<TaxMode>),
    matching: find.text(label),
  );
  if (segment.evaluate().isEmpty) {
    final expand = find.text('Fees, discount & tax');
    await scrollTo(tester, expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();
  }
  await scrollTo(tester, segment);
  await tester.tap(segment);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rate and default mode from Settings apply to the new bill', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await openTab(tester, 'Settings');
    await scrollTo(tester, find.byKey(const ValueKey('tax-rate')));
    await tester.enterText(find.byKey(const ValueKey('tax-rate')), '10');
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('default-tax-mode')));
    await tester.tap(find.byKey(const ValueKey('default-tax-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Added on top').last);
    await tester.pumpAndSettle();

    await openTab(tester, 'Split');
    await addPerson(tester, 'A'); // id1
    await addPerson(tester, 'B'); // id2
    await addPrice(tester, 'id1', '10');
    await addPrice(tester, 'id2', '5');
    expect(find.text('16.500 JOD'), findsOneWidget); // total bar

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.text('11.000 JOD'), findsOneWidget);
    expect(find.text('5.500 JOD'), findsOneWidget);
    expect(find.text('Tax 10%'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 10));
    final saved = h.bills.saved.values.single;
    expect(saved.taxMode, TaxMode.added);
    expect(saved.taxRate, 1000);
  });

  testWidgets('a bill can switch to tax added on top', (tester) async {
    await pumpApp(tester);
    await addPerson(tester, 'A');
    await addPrice(tester, 'id1', '10');
    await chooseTaxMode(tester, 'Added');
    expect(find.textContaining('Tax 16% added'), findsOneWidget);

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.text('11.600 JOD'), findsWidgets);
  });

  testWidgets('tax included keeps totals and shows the tax part', (
    tester,
  ) async {
    await pumpApp(tester);
    await addPerson(tester, 'A');
    await addPrice(tester, 'id1', '11.6');
    await chooseTaxMode(tester, 'Included');

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.text('11.600 JOD'), findsWidgets);
    expect(find.text('Includes tax 16%'), findsOneWidget);
    expect(find.text('1.600'), findsOneWidget);
  });

  testWidgets('an invalid rate shows an error and is not saved', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Settings');
    final field = find.byKey(const ValueKey('tax-rate'));
    await scrollTo(tester, field);
    await tester.enterText(field, '120');
    await tester.pumpAndSettle();
    expect(find.text('A percentage from 0 to 100'), findsOneWidget);
  });
}
