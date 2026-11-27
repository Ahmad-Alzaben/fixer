import 'package:fixer/core/theme/app_accent.dart';
import 'package:fixer/features/settings/application/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores settings in Android SharedPreferences / iOS NSUserDefaults.
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _accentKey = 'accent';

  @override
  AppAccent get accent => AppAccent.fromName(_prefs.getString(_accentKey));

  @override
  Future<void> setAccent(AppAccent accent) =>
      _prefs.setString(_accentKey, accent.name);
}
