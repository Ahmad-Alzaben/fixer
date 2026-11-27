import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sticky bar with the live bill total and a button to open results.
class TotalBar extends ConsumerWidget {
  const TotalBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(billCalculationProvider.select((c) => c.total));
    final hasPeople = ref.watch(
      billEditorProvider.select((b) => b.people.isNotEmpty),
    );
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.s),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.6,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        total.toString(),
                        style: theme.textTheme.amountLarge.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: hasPeople ? () => context.go(Routes.results) : null,
                child: const Text('Results'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
