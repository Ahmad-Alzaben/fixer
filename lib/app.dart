import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/features/bill/application/auto_save.dart';
import 'package:fixer/features/settings/application/settings_providers.dart';
import 'package:fixer/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FixerApp extends ConsumerWidget {
  const FixerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoSaveProvider); // keeps the current bill saved to history
    final accent = ref.watch(accentProvider);
    return MaterialApp.router(
      title: 'Fixer',
      debugShowCheckedModeBanner: false,
      theme: AppThemeFactory.build(accent),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
