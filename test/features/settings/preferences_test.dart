import 'package:fixer/core/ids.dart';
import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/settings/application/settings_providers.dart';
import 'package:fixer/features/settings/data/prefs_settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  var next = 0;
  return ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(
        PrefsSettingsRepository(prefs),
      ),
      idGeneratorProvider.overrideWithValue(() => 'id${next++}'),
    ],
  );
}

void main() {
  test('defaults: no name, JOD, Jordan country code 962', () async {
    final c = await containerWith({});
    final p = c.read(preferencesProvider);
    expect(p.yourName, isNull);
    expect(p.defaultCurrency, Currency.jod);
    expect(p.countryCode, '962');
  });

  test('changes are saved and restored after a restart', () async {
    final c = await containerWith({});
    final prefs = c.read(preferencesProvider.notifier);
    await prefs.setYourName('  Ahmad ');
    await prefs.setDefaultCurrency(Currency.usd);
    await prefs.setCountryCode('+966');

    final restarted = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          PrefsSettingsRepository(await SharedPreferences.getInstance()),
        ),
      ],
    );
    final p = restarted.read(preferencesProvider);
    expect(p.yourName, 'Ahmad');
    expect(p.defaultCurrency, Currency.usd);
    expect(p.countryCode, '966'); // digits only
  });

  test('blank name clears it; invalid country code is rejected', () async {
    final c = await containerWith({'yourName': 'Ahmad'});
    final prefs = c.read(preferencesProvider.notifier);
    await prefs.setYourName('  ');
    expect(c.read(preferencesProvider).yourName, isNull);
    expect(() => prefs.setCountryCode('abc'), throwsArgumentError);
  });

  group('bill editor uses preferences', () {
    test('new bills start in the default currency', () async {
      final c = await containerWith({'defaultCurrency': 'USD'});
      expect(c.read(billEditorProvider).currency, Currency.usd);
    });

    test('adding a person with your name marks them as Me', () async {
      final c = await containerWith({'yourName': 'Ahmad'});
      final editor = c.read(billEditorProvider.notifier);
      editor.addPerson('Omar');
      editor.addPerson('ahmad ');
      final people = c.read(billEditorProvider).people;
      expect(people.map((p) => p.isMe), [false, true]);
    });

    test('does not move Me if someone is already marked', () async {
      final c = await containerWith({'yourName': 'Ahmad'});
      final editor = c.read(billEditorProvider.notifier);
      final o = editor.addPerson('Omar');
      editor.toggleMe(o);
      editor.addPerson('Ahmad');
      expect(c.read(billEditorProvider).people.map((p) => p.isMe), [
        true,
        false,
      ]);
    });

    test('a bill opened in another currency keeps it', () async {
      final c = await containerWith({});
      final editor = c.read(billEditorProvider.notifier);
      final a = editor.addPerson('A');
      editor.setCurrency(Currency.usd);
      editor.addItem(a, Money.parse('1', Currency.usd));
      expect(c.read(billEditorProvider).currency, Currency.usd);
    });
  });
}
