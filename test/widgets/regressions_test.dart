import 'package:fixer/features/messaging/domain/message_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

// Bugs reported from a real phone. Each test reproduces the bug first.

void main() {
  testWidgets('bug: leaving the app closes the keyboard (no stale state)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.widgetWithText(TextField, 'Add person'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    // Return to the app the way Android does.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets(
    'bug: Results keeps full height even if a stale keyboard inset arrives',
    (tester) async {
      await pumpApp(tester);
      await addPerson(tester, 'A');
      await addPrice(tester, 'id1', '1');
      await tester.tap(find.text('Results'));
      await tester.pumpAndSettle();
      final normal = tester.getRect(find.byType(ListView).last).height;

      // Android wrongly reports a 600px keyboard after returning to the app.
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(ListView).last).height, normal);
    },
  );

  testWidgets(
    'bug: sending uses the EDITED default template, not the original text',
    (tester) async {
      final h = Harness();
      // The user edited the built-in default template (same id).
      await h.templates.save(
        MessageTemplate(
          id: MessageTemplate.builtIn.id,
          name: 'Default',
          body: 'Yo {name}, you owe {amount}',
          isDefault: true,
        ),
      );
      await pumpApp(tester, harness: h);
      await addPerson(tester, 'Omar');
      await addPrice(tester, 'id1', '2');
      await tester.tap(find.text('Results'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send to Omar'));
      await tester.pumpAndSettle();

      expect(find.text('Yo Omar, you owe 2.000 JOD'), findsOneWidget);
      expect(find.textContaining('your share of'), findsNothing);
    },
  );

  testWidgets(
    'bug: the floating "Service fee" label is not cut off by the section',
    (tester) async {
      await pumpApp(tester);
      await scrollTo(tester, find.text('Fees & discount'));
      await tester.tap(find.text('Fees & discount'));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, 'Service fee');
      await tester.tap(field); // focus: the label floats above the border
      await tester.pumpAndSettle();

      final label = tester.getRect(
        find.descendant(of: field, matching: find.text('Service fee')),
      );
      final header = tester.getRect(
        find.ancestor(
          of: find.text('Fees & discount'),
          matching: find.byType(ListTile),
        ),
      );
      // The label must sit below the section header, inside the visible
      // area, not clipped above it.
      expect(label.top, greaterThanOrEqualTo(header.bottom));
    },
  );
}
