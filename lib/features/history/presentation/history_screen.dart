import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/core/widgets/section_label.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/bill/application/providers.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Saved bills grouped by month, with search and tag filters.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';
  final _selectedTags = <String>{};

  bool _matches(Bill bill) {
    if (_selectedTags.isNotEmpty && !bill.tagIds.any(_selectedTags.contains)) {
      return false;
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return (bill.title ?? '').toLowerCase().contains(q) ||
        bill.people.any((p) => p.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final bills = ref.watch(savedBillsProvider);
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final tagNames = {for (final t in tags) t.id: t.name};

    return Scaffold(
      appBar: AppBar(title: const Text('HISTORY')),
      body: bills.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load history: $e')),
        data: (all) {
          final visible = all.where(_matches).toList();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.s),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ),
              if (tags.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Gap.l),
                      children: [
                        for (final tag in tags)
                          Padding(
                            padding: const EdgeInsets.only(right: Gap.s),
                            child: FilterChip(
                              label: Text(tag.name),
                              selected: _selectedTags.contains(tag.id),
                              onSelected: (on) => setState(
                                () => on
                                    ? _selectedTags.add(tag.id)
                                    : _selectedTags.remove(tag.id),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyHistory(filtered: all.isNotEmpty),
                )
              else
                ..._monthSections(visible, tagNames),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _monthSections(List<Bill> bills, Map<String, String> tagNames) {
    final monthFormat = DateFormat('MMMM yyyy', 'en_US');
    final sections = <Widget>[];
    String? currentMonth;
    for (final bill in bills) {
      final month = monthFormat.format(bill.createdAt!);
      if (month != currentMonth) {
        currentMonth = month;
        sections.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.s),
              child: SectionLabel(month),
            ),
          ),
        );
      }
      sections.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.s),
            child: _BillTile(bill: bill, tagNames: tagNames),
          ),
        ),
      );
    }
    sections.add(const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)));
    return sections;
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: Gap.m),
            Text(
              filtered
                  ? 'No bills match.'
                  : 'Bills you split are saved here automatically.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

enum _BillAction { duplicate, delete }

class _BillTile extends ConsumerWidget {
  const _BillTile({required this.bill, required this.tagNames});

  final Bill bill;
  final Map<String, String> tagNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final total = ref.read(billCalculatorProvider).calculate(bill).total;
    final title = bill.title ?? 'Untitled bill';
    final details = [
      DateFormat('d MMM', 'en_US').format(bill.createdAt!),
      '${bill.people.length} ${bill.people.length == 1 ? 'person' : 'people'}',
      for (final id in bill.tagIds)
        if (tagNames[id] != null) tagNames[id]!,
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(billEditorProvider.notifier).open(bill);
          context.go(Routes.split);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.xs, Gap.m),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: bill.title == null
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.s),
              Text(total.toString(), style: theme.textTheme.amount),
              PopupMenuButton<_BillAction>(
                tooltip: 'Options for $title',
                onSelected: (action) => _onAction(context, ref, action),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _BillAction.duplicate,
                    child: Text('Duplicate'),
                  ),
                  PopupMenuItem(
                    value: _BillAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _BillAction action,
  ) async {
    final editor = ref.read(billEditorProvider.notifier);
    switch (action) {
      case _BillAction.duplicate:
        editor.duplicate(bill);
        context.go(Routes.split);
      case _BillAction.delete:
        final repo = ref.read(billRepositoryProvider);
        // Don't let auto-save bring back the bill being edited.
        if (ref.read(billEditorProvider).id == bill.id) editor.reset();
        final messenger = ScaffoldMessenger.of(context);
        await repo.delete(bill.id);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${bill.title ?? 'Bill'} deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => repo.restore(bill.id),
              ),
            ),
          );
    }
  }
}
