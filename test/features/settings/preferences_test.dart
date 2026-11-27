import 'package:fixer/core/ids.dart';
import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/bill/domain/bill.dart';
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

  group('tax', () {
    test('defaults: 16%, new bills have no tax', () async {
      final p = (await containerWith({})).read(preferencesProvider);
      expect(p.taxRate, 1600);
      expect(p.defaultTaxMode, TaxMode.none);
    });

    test('rate and default mode are saved and restored', () async {
      final c = await containerWith({});
      await c.read(preferencesProvider.notifier).setTaxRate(750);
      await c
          .read(preferencesProvider.notifier)
          .setDefaultTaxMode(TaxMode.added);
      final restarted = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            PrefsSettingsRepository(await SharedPreferences.getInstance()),
          ),
        ],
      );
      final p = restarted.read(preferencesProvider);
      expect(p.taxRate, 750);
      expect(p.defaultTaxMode, TaxMode.added);
    });

    test('new bills copy the rate and default mode', () async {
      final c = await containerWith({
        'taxRate': 1000,
        'defaultTaxMode': 'included',
      });
      final bill = c.read(billEditorProvider);
      expect(bill.taxRate, 1000);
      expect(bill.taxMode, TaxMode.included);
    });

    test('changing the setting updates a bill with no amounts yet', () async {
      final c = await containerWith({});
      final editor = c.read(billEditorProvider.notifier);
      editor.addPerson('A');
      await c.read(preferencesProvider.notifier).setTaxRate(1000);
      await c
          .read(preferencesProvider.notifier)
          .setDefaultTaxMode(TaxMode.added);
      final bill = c.read(billEditorProvider);
      expect(bill.taxRate, 1000);
      expect(bill.taxMode, TaxMode.added);
    });

    test('changing the setting leaves a bill with amounts alone', () async {
      final c = await containerWith({});
      final editor = c.read(billEditorProvider.notifier);
      editor.addItem(editor.addPerson('A'), Money.parse('5', Currency.jod));
      await c.read(preferencesProvider.notifier).setTaxRate(1000);
      expect(c.read(billEditorProvider).taxRate, 1600);
    });

    test('each bill can switch its tax mode', () async {
      final c = await containerWith({});
      c.read(billEditorProvider.notifier).setTaxMode(TaxMode.added);
      expect(c.read(billEditorProvider).taxMode, TaxMode.added);
    });

    test('an old bill without a rate takes the Settings rate', () async {
      final c = await containerWith({'taxRate': 1000});
      final editor = c.read(billEditorProvider.notifier);
      editor.open(c.read(billEditorProvider).copyWith(taxRate: 0));
      editor.setTaxMode(TaxMode.added);
      expect(c.read(billEditorProvider).taxRate, 1000);
    });
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
