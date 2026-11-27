import 'package:fixer/core/theme/app_accent.dart';
import 'package:fixer/features/settings/application/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden in `main()` with the real storage-backed implementation.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('settingsRepositoryProvider not set'),
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
