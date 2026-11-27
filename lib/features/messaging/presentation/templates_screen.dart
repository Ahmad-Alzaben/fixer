import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/features/messaging/application/template_repository.dart';
import 'package:fixer/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Saved templates; the filled radio marks the default used for every send.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);
    final repo = ref.read(templateRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MESSAGE TEMPLATES'),
        actions: [
          IconButton(
            tooltip: 'New template',
            icon: const Icon(Icons.add),
            onPressed: () => context.go(Routes.editTemplate),
          ),
        ],
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load templates: $e')),
        data: (list) => ListView(
          padding: const EdgeInsets.all(Gap.l),
          children: [
            for (final t in list) ...[
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.only(
                    left: Gap.xs,
                    right: Gap.xs,
                  ),
                  leading: IconButton(
                    tooltip: t.isDefault
                        ? '${t.name} is the default'
                        : 'Make ${t.name} the default',
                    icon: Icon(
                      t.isDefault
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: t.isDefault
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onPressed: t.isDefault ? null : () => repo.setDefault(t.id),
                  ),
                  title: Text(t.name),
                  subtitle: Text(
                    t.body.replaceAll('\n', ' '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete ${t.name}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: list.length <= 1
                        ? null
                        : () => repo.delete(t.id),
                  ),
                  onTap: () => context.go(Routes.editTemplate, extra: t),
                ),
              ),
              const SizedBox(height: Gap.s),
            ],
            Padding(
              padding: const EdgeInsets.only(top: Gap.s),
              child: Text(
                'The default template is filled in each time you send. '
                'You can switch template or edit the text before sending.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sample values for previews (the brief's example, seen by O).
const templatePreviewValues = {
  'name': 'Omar',
  'amount': '2.396 JOD',
  'billTotal': '5.670 JOD',
  'title': 'Shawarma night',
  'date': '27 Nov 2026',
  'items': '- Item 1: 3.000\nService: 0.296\nDiscount: -0.900',
};

/// Placeholders users can insert, with what they become.
const templatePlaceholders = {
  '{name}': 'Person\'s name',
  '{amount}': 'What they owe',
  '{items}': 'Their items and fee shares',
  '{billTotal}': 'Whole bill total',
  '{title}': 'Bill title',
  '{date}': 'Bill date',
};
