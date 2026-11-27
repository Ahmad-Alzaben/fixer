import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/theme/app_accent.dart';

/// App-wide preferences. Implementations decide where they are stored.
abstract interface class SettingsRepository {
  AppAccent get accent;
  Future<void> setAccent(AppAccent accent);

  /// Name that marks a person as "Me" automatically; null when unset.
  String? get yourName;
  Future<void> setYourName(String? name);

  /// Currency for new bills.
  Currency get defaultCurrency;
  Future<void> setDefaultCurrency(Currency currency);

  /// Digits only, e.g. `962`. Used to turn local numbers like `079...`
  /// into international ones for WhatsApp.
  String get countryCode;
  Future<void> setCountryCode(String digits);
}

const defaultCountryCode = '962';

/// Non-persistent settings; the default until `main()` installs the real one,
/// and handy in tests.
class InMemorySettingsRepository implements SettingsRepository {
  @override
  AppAccent accent = AppAccent.fallback;
  @override
  String? yourName;
  @override
  Currency defaultCurrency = Currency.defaultCurrency;
  @override
  String countryCode = defaultCountryCode;

  @override
  Future<void> setAccent(AppAccent value) async => accent = value;
  @override
  Future<void> setYourName(String? value) async => yourName = value;
  @override
  Future<void> setDefaultCurrency(Currency value) async =>
      defaultCurrency = value;
  @override
  Future<void> setCountryCode(String value) async => countryCode = value;
}
