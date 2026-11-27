import 'package:fixer/app.dart';
import 'package:fixer/features/settings/application/settings_providers.dart';
import 'package:fixer/features/settings/data/prefs_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          PrefsSettingsRepository(prefs),
        ),
      ],
      child: const FixerApp(),
    ),
  );
}
