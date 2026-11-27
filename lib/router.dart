import 'package:fixer/core/widgets/app_shell.dart';
import 'package:fixer/features/bill/presentation/split_screen.dart';
import 'package:fixer/features/history/presentation/history_screen.dart';
import 'package:fixer/features/messaging/domain/message_template.dart';
import 'package:fixer/features/messaging/presentation/template_editor_screen.dart';
import 'package:fixer/features/messaging/presentation/templates_screen.dart';
import 'package:fixer/features/reports/presentation/reports_screen.dart';
import 'package:fixer/features/results/presentation/results_screen.dart';
import 'package:fixer/features/settings/presentation/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class Routes {
  static const split = '/split';
  static const results = '/split/results';
  static const history = '/history';
  static const reports = '/reports';
  static const settings = '/settings';
  static const templates = '/settings/templates';
  static const editTemplate = '/settings/templates/edit';
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
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.reports,
                builder: (_, _) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'templates',
                    builder: (_, _) => const TemplatesScreen(),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => TemplateEditorScreen(
                          template: state.extra as MessageTemplate?,
                        ),
                      ),
                    ],
                  ),
                ],
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
