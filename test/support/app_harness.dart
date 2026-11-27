import 'package:fixer/app.dart';
import 'package:fixer/core/clock.dart';
import 'package:fixer/core/ids.dart';
import 'package:fixer/core/platform/share_gateway.dart';
import 'package:fixer/features/bill/application/auto_save.dart';
import 'package:fixer/features/bill/application/providers.dart';
import 'package:fixer/features/contacts/contacts_gateway.dart';
import 'package:fixer/features/messaging/application/message_launcher.dart';
import 'package:fixer/features/messaging/application/template_repository.dart';
import 'package:fixer/features/settings/application/settings_providers.dart';
import 'package:fixer/features/settings/data/prefs_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

class FakeShareGateway implements ShareGateway {
  final copied = <String>[];
  final shared = <String>[];

  @override
  Future<void> copy(String text) async => copied.add(text);

  @override
  Future<void> share(String text, {String? subject, Rect? origin}) async {
    shared.add(text);
    origins.add(origin);
  }

  final origins = <Rect?>[];
}

class FakeContactsGateway implements ContactsGateway {
  PickedContact? next;
  bool deny = false;

  @override
  Future<PickedContact?> pick() async {
    if (deny) throw const ContactsPermissionDenied();
    return next;
  }
}

class FakeMessageLauncher implements MessageLauncher {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

class Harness {
  Harness();
  final share = FakeShareGateway();
  final bills = FakeBillRepository();
  final tags = FakeTagRepository();
  final templates = FakeTemplateRepository();
  Map<String, Object> storedSettings = {};
  final contacts = FakeContactsGateway();
  final launcher = FakeMessageLauncher();
}

final testNow = DateTime(2026, 11, 27, 19);

Future<Harness> pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Harness? harness,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final h = harness ?? Harness();
  SharedPreferences.setMockInitialValues(h.storedSettings);
  final prefs = await SharedPreferences.getInstance();
  var next = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          PrefsSettingsRepository(prefs),
        ),
        shareGatewayProvider.overrideWithValue(h.share),
        idGeneratorProvider.overrideWithValue(() => 'id${next++}'),
        clockProvider.overrideWithValue(() => testNow),
        billRepositoryProvider.overrideWithValue(h.bills),
        tagRepositoryProvider.overrideWithValue(h.tags),
        templateRepositoryProvider.overrideWithValue(h.templates),
        contactsGatewayProvider.overrideWithValue(h.contacts),
        messageLauncherProvider.overrideWithValue(h.launcher),
        autoSaveDelayProvider.overrideWithValue(Duration.zero),
      ],
      child: const FixerApp(),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

/// Scrolls the current screen's list until [finder] is built and on screen
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
