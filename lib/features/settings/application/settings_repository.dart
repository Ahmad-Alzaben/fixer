import 'package:fixer/core/theme/app_accent.dart';

/// App-wide preferences. Implementations decide where they are stored.
abstract interface class SettingsRepository {
  AppAccent get accent;
  Future<void> setAccent(AppAccent accent);
}
