import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/contacts/contacts_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Money jod(String s) => Money.parse(s, Currency.jod);

Bill seeded(
  String id,
  String title, {
  Set<String> tags = const {},
  int day = 1,
}) => Bill(
  id: id,
  title: title,
  currency: Currency.jod,
  createdAt: DateTime(2026, 11, day, 12),
  tagIds: tags,
  people: [
    Person(
      id: '$id-p',
      name: 'Sami',
      items: [BillItem(id: '$id-i', price: jod('4'))],
    ),
  ],
);

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('History', () {
    testWidgets('a bill being entered is saved and can be reopened', (
      tester,
    ) async {
      final h = await pumpApp(tester);
      await addPerson(tester, 'A');
      await addPrice(tester, 'id1', '2');
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.bills.saved, hasLength(1));

      await tester.tap(find.byTooltip('New bill'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'New bill'));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);

      await openTab(tester, 'History');
      expect(find.text('Untitled bill'), findsOneWidget);
      expect(find.text('2.000 JOD'), findsOneWidget);
      expect(find.text('NOVEMBER 2026'), findsOneWidget);

      await tester.tap(find.text('Untitled bill'));
      await tester.pumpAndSettle();
      expect(find.text('FIXER'), findsOneWidget); // back on Split
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('delete removes a bill and Undo brings it back', (
      tester,
    ) async {
      final h = Harness();
      await h.bills.save(seeded('b1', 'Lunch'));
      await pumpApp(tester, harness: h);
      await openTab(tester, 'History');

      await tester.tap(find.byTooltip('Options for Lunch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Lunch'), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Lunch'), findsOneWidget);
    });

    testWidgets('filters by tag and searches by title or person', (
      tester,
    ) async {
      final h = Harness();
      await h.bills.save(seeded('b1', 'Pizza', tags: {'tag-food'}, day: 2));
      await h.bills.save(
        seeded('b2', 'Cable', tags: {'tag-electronics'}, day: 3),
      );
      await pumpApp(tester, harness: h);
      await openTab(tester, 'History');
      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Cable'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Food'));
      await tester.pumpAndSettle();
      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Cable'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Food'));
      await tester.enterText(find.widgetWithText(TextField, 'Search'), 'cab');
      await tester.pumpAndSettle();
      expect(find.text('Pizza'), findsNothing);
      expect(find.text('Cable'), findsOneWidget);
    });

    testWidgets('duplicate opens a copy in the editor', (tester) async {
      final h = Harness();
      await h.bills.save(seeded('b1', 'Lunch'));
      await pumpApp(tester, harness: h);
      await openTab(tester, 'History');
      await tester.tap(find.byTooltip('Options for Lunch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      expect(find.text('FIXER'), findsOneWidget);
      expect(find.text('Sami'), findsOneWidget);
    });
  });

  group('Tags on the Split screen', () {
    testWidgets('pick existing tags and create a new one', (tester) async {
      final h = await pumpApp(tester);
      await tester.tap(find.text('Add tag'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Food'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'New tag'),
        'Gaming',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputChip, 'Food'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Gaming'), findsOneWidget);
      expect(h.tags.tags.map((t) => t.name), contains('Gaming'));
    });
  });

  group('Contacts', () {
    testWidgets('pick a contact with several numbers', (tester) async {
      final h = Harness();
      h.contacts.next = const PickedContact(
        id: 'c1',
        name: 'Omar',
        phones: ['+962 79 111 1111', '0792222222'],
      );
      await pumpApp(tester, harness: h);
      await tester.tap(find.byTooltip('Add from contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0792222222'));
      await tester.pumpAndSettle();
      expect(find.text('Omar'), findsOneWidget);
    });

    testWidgets('explains when contacts permission is denied', (tester) async {
      final h = Harness()..contacts.deny = true;
      await pumpApp(tester, harness: h);
      await tester.tap(find.byTooltip('Add from contacts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Allow contacts access'), findsOneWidget);
    });
  });

  group('Send', () {
    Future<Harness> billWithOmar(WidgetTester tester) async {
      final h = Harness();
      h.contacts.next = const PickedContact(
        id: 'c1',
        name: 'Omar',
        phones: ['+962791234567'],
      );
      await pumpApp(tester, harness: h);
      await tester.tap(find.byTooltip('Add from contacts'));
      await tester.pumpAndSettle();
      await addPrice(tester, 'id1', '2.5');
      await tester.tap(find.text('Results'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send to Omar'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('WhatsApp opens a chat with the default template', (
      tester,
    ) async {
      final h = await billWithOmar(tester);
      expect(find.textContaining('Hi Omar, your share'), findsOneWidget);
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      expect(
        h.launcher.opened.single.toString(),
        startsWith(
          'https://wa.me/962791234567?text=Hi%20Omar%2C%20your%20share',
        ),
      );
    });

    testWidgets('message can be edited before sending by SMS', (tester) async {
      final h = await billWithOmar(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Message'),
        'Send me 2.500 please',
      );
      await tester.tap(find.text('SMS'));
      await tester.pumpAndSettle();
      expect(
        h.launcher.opened.single.toString(),
        'sms:+962791234567?body=Send%20me%202.500%20please',
      );
    });
  });
}
