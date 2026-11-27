import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/bill/application/providers.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bill's tags as removable chips, plus "Add tag".
class TagChips extends ConsumerWidget {
  const TagChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(billEditorProvider.select((b) => b.tagIds));
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final editor = ref.read(billEditorProvider.notifier);
    return Wrap(
      spacing: Gap.s,
      runSpacing: Gap.xs,
      children: [
        for (final tag in tags.where((t) => selected.contains(t.id)))
          InputChip(
            label: Text(tag.name),
            onDeleted: () => editor.toggleTag(tag.id),
            deleteButtonTooltipMessage: 'Remove ${tag.name}',
          ),
        ActionChip(
          avatar: const Icon(Icons.sell_outlined, size: 18),
          label: const Text('Add tag'),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => const _TagSheet(),
          ),
        ),
      ],
    );
  }
}

class _TagSheet extends ConsumerStatefulWidget {
  const _TagSheet();

  @override
  ConsumerState<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends ConsumerState<_TagSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    try {
      final tag = await ref.read(tagRepositoryProvider).create(name);
      ref.read(billEditorProvider.notifier).toggleTag(tag.id);
      _controller.clear();
      setState(() => _error = null);
    } on ArgumentError {
      setState(() => _error = 'That tag already exists');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(billEditorProvider.select((b) => b.tagIds));
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final editor = ref.read(billEditorProvider.notifier);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.l,
        0,
        Gap.l,
        Gap.l + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tags', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Gap.m),
          Wrap(
            spacing: Gap.s,
            runSpacing: Gap.xs,
            children: [
              for (final tag in tags)
                FilterChip(
                  label: Text(tag.name),
                  selected: selected.contains(tag.id),
                  onSelected: (_) => editor.toggleTag(tag.id),
                ),
            ],
          ),
          const SizedBox(height: Gap.m),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _create(),
            decoration: InputDecoration(
              labelText: 'New tag',
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: 'Create tag',
                icon: const Icon(Icons.add),
                onPressed: _create,
              ),
            ),
          ),
          const SizedBox(height: Gap.m),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
