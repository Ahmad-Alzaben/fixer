import 'package:fixer/app.dart';
import 'package:fixer/data/db/app_database.dart';
import 'package:fixer/data/repositories/drift_bill_repository.dart';
import 'package:fixer/data/repositories/drift_tag_repository.dart';
import 'package:fixer/data/repositories/drift_template_repository.dart';
import 'package:fixer/features/bill/application/providers.dart';
import 'package:fixer/features/messaging/application/template_repository.dart';
import 'package:fixer/features/settings/application/settings_providers.dart';
import 'package:fixer/features/settings/data/prefs_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.onDevice();
  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          PrefsSettingsRepository(prefs),
        ),
        billRepositoryProvider.overrideWithValue(DriftBillRepository(db)),
        tagRepositoryProvider.overrideWithValue(
          DriftTagRepository(db, idGenerator: const Uuid().v4),
        ),
        templateRepositoryProvider.overrideWithValue(
          DriftTemplateRepository(db),
        ),
      ],
      child: const FixerApp(),
    ),
  );
}
