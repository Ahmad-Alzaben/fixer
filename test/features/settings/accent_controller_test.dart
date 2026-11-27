import 'package:fixer/core/theme/app_accent.dart';
import 'package:fixer/features/settings/application/settings_providers.dart';
import 'package:fixer/features/settings/data/prefs_settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(
        PrefsSettingsRepository(prefs),
      ),
    ],
  );
}

void main() {
  test('defaults to neon yellow when nothing is saved', () async {
    final c = await containerWith({});
    expect(c.read(accentProvider), AppAccent.neonYellow);
  });

  test('choosing an accent is saved and restored on the next start', () async {
    final first = await containerWith({});
    await first.read(accentProvider.notifier).choose(AppAccent.electricCyan);
    expect(first.read(accentProvider), AppAccent.electricCyan);

    // Simulate an app restart reading the same storage.
    final prefs = await SharedPreferences.getInstance();
    final restarted = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          PrefsSettingsRepository(prefs),
        ),
      ],
    );
    expect(restarted.read(accentProvider), AppAccent.electricCyan);
  });

  test('an unknown saved value falls back to the default', () async {
    final c = await containerWith({'accent': 'ultraviolet'});
    expect(c.read(accentProvider), AppAccent.neonYellow);
  });

  test('every accent keeps text on it readable (contrast >= 4.5:1)', () {
    for (final accent in AppAccent.values) {
      final ratio = contrastRatio(accent.color, accent.onColor);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: accent.name);
    }
  });
}
