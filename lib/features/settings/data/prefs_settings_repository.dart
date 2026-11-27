import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/theme/app_accent.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/settings/application/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores settings in Android SharedPreferences / iOS NSUserDefaults.
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _accentKey = 'accent';
  static const _nameKey = 'yourName';
  static const _currencyKey = 'defaultCurrency';
  static const _countryKey = 'countryCode';
  static const _taxRateKey = 'taxRate';
  static const _taxModeKey = 'defaultTaxMode';

  @override
  AppAccent get accent => AppAccent.fromName(_prefs.getString(_accentKey));

  @override
  Future<void> setAccent(AppAccent accent) =>
      _prefs.setString(_accentKey, accent.name);

  @override
  String? get yourName => _prefs.getString(_nameKey);

  @override
  Future<void> setYourName(String? name) =>
      name == null ? _prefs.remove(_nameKey) : _prefs.setString(_nameKey, name);

  @override
  Currency get defaultCurrency =>
      Currency.byCode(_prefs.getString(_currencyKey) ?? '') ??
      Currency.defaultCurrency;

  @override
  Future<void> setDefaultCurrency(Currency currency) =>
      _prefs.setString(_currencyKey, currency.code);

  @override
  String get countryCode => _prefs.getString(_countryKey) ?? defaultCountryCode;

  @override
  Future<void> setCountryCode(String digits) =>
      _prefs.setString(_countryKey, digits);

  @override
  int get taxRate => _prefs.getInt(_taxRateKey) ?? defaultTaxRate;

  @override
  Future<void> setTaxRate(int rate) => _prefs.setInt(_taxRateKey, rate);

  @override
  TaxMode get defaultTaxMode => TaxMode.values.firstWhere(
    (m) => m.name == _prefs.getString(_taxModeKey),
    orElse: () => TaxMode.none,
  );

  @override
  Future<void> setDefaultTaxMode(TaxMode mode) =>
      _prefs.setString(_taxModeKey, mode.name);
}
