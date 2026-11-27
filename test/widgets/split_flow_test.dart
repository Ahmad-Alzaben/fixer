import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('quick entry: add person, add prices, running subtotal', (
    tester,
  ) async {
    await pumpApp(tester);
    await addPerson(tester, 'Omar');
    expect(find.text('Omar'), findsOneWidget);

    await addPrice(tester, 'id1', '1.45');
    await addPrice(tester, 'id1', '1');
    expect(find.text('2.450 JOD'), findsWidgets); // subtotal + total bar

    // The price field is cleared and keeps focus for the next price.
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('price-id1')),
    );
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('add-person field keeps focus so names can be typed in a row', (
    tester,
  ) async {
    await pumpApp(tester);
    await addPerson(tester, 'A');
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Add person'),
    );
    expect(field.focusNode!.hasFocus, isTrue);

    // Type into whatever field the keyboard is attached to (like a real
    // user), not into a field picked by a finder.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'O',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('O'), findsOneWidget);
  });

  testWidgets('invalid price is rejected with a message', (tester) async {
    await pumpApp(tester);
    await addPerson(tester, 'A');
    await addPrice(tester, 'id1', '0');
    expect(find.text('Enter a price above 0'), findsOneWidget);
  });

  testWidgets('brief example: results show each share and copy text', (
    tester,
  ) async {
    final share = (await pumpApp(tester)).share;
    await enterBriefExample(tester);
    expect(find.text('5.670 JOD'), findsWidgets);

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.text('1.956 JOD'), findsOneWidget);
    expect(find.text('2.396 JOD'), findsOneWidget);
    expect(find.text('1.318 JOD'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(share.copied.single, startsWith('Bill total: 5.670 JOD'));
    expect(find.text('Results copied'), findsOneWidget);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(share.shared.single, contains('O: 2.396 JOD'));
  });

  testWidgets('discount larger than the bill shows a warning', (tester) async {
    await pumpApp(tester);
    await addPerson(tester, 'A');
    await addPrice(tester, 'id1', '1');
    await setAdjustment(tester, 'Discount', '5');
    expect(
      find.textContaining('Discount is larger than the bill'),
      findsOneWidget,
    );
  });

  testWidgets('removing a person can be undone', (tester) async {
    await pumpApp(tester);
    await addPerson(tester, 'A');
    await tester.tap(find.byTooltip('Options for A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('small 320dp screen with 5 people renders without overflow', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(320, 568));
    for (final name in ['A', 'J', 'R', 'O', 'F']) {
      await addPerson(tester, name);
    }
    await addPrice(tester, 'id5', '12.345');
    await setAdjustment(tester, 'Delivery fee', '1');
    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide screen shows results beside the editor', (tester) async {
    await pumpApp(tester, size: const Size(1100, 800));
    await enterBriefExample(tester);
    expect(find.text('Results'), findsNothing); // no separate button
    expect(find.text('2.396 JOD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing accent in settings recolors the app', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electric Cyan'));
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.text('SETTINGS')));
    expect(theme.colorScheme.primary, const Color(0xFF00F0FF));
  });
}
