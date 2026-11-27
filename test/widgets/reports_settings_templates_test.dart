import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/contacts/contacts_gateway.dart';
import 'package:fixer/features/messaging/domain/message_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Money jod(String s) => Money.parse(s, Currency.jod);

Bill myBill(
  String id, {
  required DateTime at,
  required String mine,
  Set<String> tags = const {},
  bool withMe = true,
}) => Bill(
  id: id,
  title: id,
  currency: Currency.jod,
  createdAt: at,
  tagIds: tags,
  people: [
    Person(
      id: '$id-me',
      name: 'Ahmad',
      isMe: withMe,
      items: [BillItem(id: '$id-1', price: jod(mine))],
    ),
    Person(
      id: '$id-f',
      name: 'Sami',
      items: [BillItem(id: '$id-2', price: jod('10'))],
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
  group('Reports', () {
    testWidgets('empty state explains how reports fill up', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'Reports');
      expect(find.textContaining('No spending yet'), findsOneWidget);
    });

    testWidgets('shows my monthly total, tag breakdown and navigation', (
      tester,
    ) async {
      final h = Harness();
      await h.bills.save(
        myBill(
          'Pizza',
          at: DateTime(2026, 11, 2),
          mine: '4',
          tags: {'tag-food'},
        ),
      );
      await h.bills.save(myBill('Taxi', at: DateTime(2026, 11, 9), mine: '2'));
      await h.bills.save(
        myBill('Party', at: DateTime(2026, 11, 12), mine: '9', withMe: false),
      );
      await h.bills.save(myBill('Cable', at: DateTime(2026, 10, 5), mine: '3'));
      await pumpApp(tester, harness: h);
      await openTab(tester, 'Reports');

      expect(find.text('NOVEMBER 2026'), findsOneWidget);
      expect(find.text('6.000 JOD'), findsWidgets); // my total
      expect(find.text('2 bills'), findsOneWidget);
      expect(
        find.textContaining('1 bill has nobody marked as Me'),
        findsOneWidget,
      );
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('4.000 JOD'), findsOneWidget);
      expect(find.text('Untagged'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('OCTOBER 2026'), findsOneWidget);
      expect(find.text('3.000 JOD'), findsWidgets);
    });
  });

  group('Settings', () {
    testWidgets('your name marks you as Me when you add yourself', (
      tester,
    ) async {
      await pumpApp(tester);
      await openTab(tester, 'Settings');
      await tester.enterText(
        find.widgetWithText(TextField, 'Your name'),
        'Ahmad',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await openTab(tester, 'Split');
      await addPerson(tester, 'Ahmad');
      expect(find.text('ME'), findsOneWidget);
    });

    testWidgets('default currency applies to new bills', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'Settings');
      await tester.tap(find.byKey(const ValueKey('default-currency')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD').last);
      await tester.pumpAndSettle();

      await openTab(tester, 'Split');
      await tester.tap(find.byTooltip('New bill'));
      await tester.pumpAndSettle();
      expect(find.text('USD'), findsOneWidget); // app bar currency button
    });

    testWidgets('country code is used for WhatsApp numbers', (tester) async {
      final h = Harness()
        ..storedSettings = {'countryCode': '966'}
        ..contacts.next = const PickedContact(
          id: 'c1',
          name: 'Faisal',
          phones: ['0501234567'],
        );
      await pumpApp(tester, harness: h);
      await tester.tap(find.byTooltip('Add from contacts'));
      await tester.pumpAndSettle();
      await addPrice(tester, 'id1', '1');
      await tester.tap(find.text('Results'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send to Faisal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      expect(
        h.launcher.opened.single.toString(),
        startsWith('https://wa.me/966501234567?'),
      );
    });
  });

  group('Message templates', () {
    Future<void> openTemplates(WidgetTester tester) async {
      await openTab(tester, 'Settings');
      await scrollTo(tester, find.text('Message templates'));
      await tester.tap(find.text('Message templates'));
      await tester.pumpAndSettle();
    }

    testWidgets('create a template, make it default, use it when sending', (
      tester,
    ) async {
      final h = await pumpApp(tester);
      await openTemplates(tester);
      expect(find.text('Default'), findsOneWidget);

      await tester.tap(find.byTooltip('New template'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Friends');
      await tester.enterText(
        find.widgetWithText(TextField, 'Message'),
        'Yo {name}, send ',
      );
      await tester.tap(find.widgetWithText(ActionChip, '{amount}'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Yo Omar, send 2.396 JOD'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Friends'), findsOneWidget);
      await tester.tap(find.byTooltip('Make Friends the default'));
      await tester.pumpAndSettle();
      expect(
        h.templates.templates.singleWhere((t) => t.isDefault).name,
        'Friends',
      );

      // Sending now starts from the new default.
      await openTab(tester, 'Split');
      await addPerson(tester, 'Omar');
      // id0 = bill, id1 = the new template, so Omar is id2.
      await addPrice(tester, 'id2', '1');
      await tester.tap(find.text('Results'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send to Omar'));
      await tester.pumpAndSettle();
      expect(find.text('Yo Omar, send 1.000 JOD'), findsOneWidget);

      // Switching template re-renders the message.
      await tester.tap(find.byKey(const ValueKey('template-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Default').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Hi Omar, your share'), findsOneWidget);
    });

    testWidgets('the only template cannot be deleted', (tester) async {
      await pumpApp(tester);
      await openTemplates(tester);
      final delete = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(delete.onPressed, isNull);
    });

    testWidgets('editing keeps the id and updates the text', (tester) async {
      final h = Harness();
      await h.templates.save(
        const MessageTemplate(id: 't1', name: 'Formal', body: 'Dear {name}'),
      );
      await pumpApp(tester, harness: h);
      await openTemplates(tester);
      await tester.tap(find.text('Formal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Message'),
        'Dear {name}, kindly send {amount}.',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        h.templates.templates.singleWhere((t) => t.id == 't1').body,
        'Dear {name}, kindly send {amount}.',
      );
    });
  });
}
