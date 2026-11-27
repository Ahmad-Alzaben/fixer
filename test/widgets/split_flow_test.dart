import 'package:fixer/app.dart';
import 'package:fixer/core/ids.dart';
import 'package:fixer/core/platform/share_gateway.dart';
import 'package:fixer/features/settings/application/settings_providers.dart';
import 'package:fixer/features/settings/data/prefs_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeShareGateway implements ShareGateway {
  final copied = <String>[];
  final shared = <String>[];

  @override
  Future<void> copy(String text) async => copied.add(text);

  @override
  Future<void> share(String text, {String? subject}) async => shared.add(text);
}

Future<FakeShareGateway> pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final share = FakeShareGateway();
  var next = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          PrefsSettingsRepository(prefs),
        ),
        shareGatewayProvider.overrideWithValue(share),
        idGeneratorProvider.overrideWithValue(() => 'id${next++}'),
      ],
      child: const FixerApp(),
    ),
  );
  await tester.pumpAndSettle();
  return share;
}

/// Scrolls the bill editor until [finder] is built and on screen
/// (list rows off screen are not built at all).
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> addPerson(WidgetTester tester, String name) async {
  final field = find.widgetWithText(TextField, 'Add person');
  await scrollTo(tester, field);
  await tester.enterText(field, name);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Types a price into the given person's quick-entry field and submits.
Future<void> addPrice(WidgetTester tester, String person, String price) async {
  final field = find.byKey(ValueKey('price-$person'));
  await scrollTo(tester, field);
  await tester.enterText(field, price);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> setAdjustment(WidgetTester tester, String label, String v) async {
  final field = find.widgetWithText(TextField, label);
  if (field.evaluate().isEmpty) {
    final expand = find.text('Fees & discount');
    await scrollTo(tester, expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();
  }
  await scrollTo(tester, field);
  await tester.enterText(field, v);
  await tester.pumpAndSettle();
}

/// Ids are id0, id1... in creation order: bill id0, first person id1.
Future<void> enterBriefExample(WidgetTester tester) async {
  await addPerson(tester, 'A'); // id1
  await addPerson(tester, 'O'); // id2
  await addPerson(tester, 'J'); // id3
  await addPrice(tester, 'id1', '1.45');
  await addPrice(tester, 'id1', '1.00');
  await addPrice(tester, 'id2', '3');
  await addPrice(tester, 'id3', '1.65');
  await setAdjustment(tester, 'Service fee', '0.70');
  await setAdjustment(tester, 'Discount', '2.13');
}

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
    final share = await pumpApp(tester);
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
