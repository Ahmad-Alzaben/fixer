import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/theme/app_accent.dart';
import 'package:fixer/features/settings/application/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory by default; `main()` installs the SharedPreferences one.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => InMemorySettingsRepository(),
);

final accentProvider = NotifierProvider<AccentController, AppAccent>(
  AccentController.new,
);

class AccentController extends Notifier<AppAccent> {
  @override
  AppAccent build() => ref.read(settingsRepositoryProvider).accent;

  Future<void> choose(AppAccent accent) async {
    state = accent;
    await ref.read(settingsRepositoryProvider).setAccent(accent);
  }
}

class Preferences {
  const Preferences({
    required this.yourName,
    required this.defaultCurrency,
    required this.countryCode,
  });

  final String? yourName;
  final Currency defaultCurrency;
  final String countryCode;
}

final preferencesProvider =
    NotifierProvider<PreferencesController, Preferences>(
      PreferencesController.new,
    );

class PreferencesController extends Notifier<Preferences> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Preferences build() => Preferences(
    yourName: _repo.yourName,
    defaultCurrency: _repo.defaultCurrency,
    countryCode: _repo.countryCode,
  );

  Future<void> setYourName(String name) async {
    final trimmed = name.trim();
    await _repo.setYourName(trimmed.isEmpty ? null : trimmed);
    state = build();
  }

  Future<void> setDefaultCurrency(Currency currency) async {
    await _repo.setDefaultCurrency(currency);
    state = build();
  }

  /// Accepts `962`, `+962` or `00962`; stores digits only.
  Future<void> setCountryCode(String code) async {
    final digits = code.trim().replaceFirst(RegExp(r'^(\+|00)'), '');
    if (!RegExp(r'^[1-9]\d{0,3}$').hasMatch(digits)) {
      throw ArgumentError.value(code, 'code', 'not a country calling code');
    }
    await _repo.setCountryCode(digits);
    state = build();
  }
}
