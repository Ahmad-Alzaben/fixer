import 'package:fixer/core/widgets/app_shell.dart';
import 'package:fixer/core/widgets/coming_soon.dart';
import 'package:fixer/features/bill/presentation/split_screen.dart';
import 'package:fixer/features/results/presentation/results_screen.dart';
import 'package:fixer/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class Routes {
  static const split = '/split';
  static const results = '/split/results';
  static const history = '/history';
  static const reports = '/reports';
  static const settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.split,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.split,
                builder: (_, _) => const SplitScreen(),
                routes: [
                  GoRoute(
                    path: 'results',
                    builder: (_, _) => const ResultsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.history,
                builder: (_, _) => const ComingSoon(
                  title: 'History',
                  icon: Icons.history,
                  message: 'Saved bills will appear here.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.reports,
                builder: (_, _) => const ComingSoon(
                  title: 'Reports',
                  icon: Icons.bar_chart,
                  message: 'Your monthly spending will appear here.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
