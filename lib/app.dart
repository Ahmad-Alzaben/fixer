import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/core/widgets/stale_inset_guard.dart';
import 'package:fixer/features/bill/application/auto_save.dart';
import 'package:fixer/features/settings/application/settings_providers.dart';
import 'package:fixer/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FixerApp extends ConsumerStatefulWidget {
  const FixerApp({super.key});

  @override
  ConsumerState<FixerApp> createState() => _FixerAppState();
}

class _FixerAppState extends ConsumerState<FixerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Close the keyboard when leaving the app (e.g. to WhatsApp), so no
    // "keyboard open" state is left behind for when the user returns.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(autoSaveProvider); // keeps the current bill saved to history
    final accent = ref.watch(accentProvider);
    return MaterialApp.router(
      title: 'Fixer',
      debugShowCheckedModeBanner: false,
      theme: AppThemeFactory.build(accent),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => StaleInsetGuard(child: child!),
    );
  }
}
