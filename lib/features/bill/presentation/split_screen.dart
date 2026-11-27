import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/bill/presentation/widgets/add_person_field.dart';
import 'package:fixer/features/bill/presentation/widgets/adjustments_card.dart';
import 'package:fixer/features/bill/presentation/widgets/person_card.dart';
import 'package:fixer/features/bill/presentation/widgets/total_bar.dart';
import 'package:fixer/features/results/presentation/results_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The main bill-entry tab. On wide screens results sit beside the editor.
class SplitScreen extends ConsumerWidget {
  const SplitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideLayoutMinWidth - 81;
        return Scaffold(
          appBar: AppBar(
            title: const Text('FIXER'),
            actions: const [_CurrencyButton(), _NewBillButton()],
          ),
          body: wide
              ? const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Editor()),
                    VerticalDivider(width: 1),
                    SizedBox(width: 380, child: ResultsPanel()),
                  ],
                )
              : const _Editor(),
          bottomNavigationBar: wide ? null : const TotalBar(),
        );
      },
    );
  }
}

class _Editor extends ConsumerWidget {
  const _Editor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = ref.watch(billEditorProvider);
    // Keyed by bill id so all text fields reset when a new bill starts.
    // Every row has a stable key: the list matches rows by key, so inserting
    // a person doesn't recreate the fields below it (which would drop focus
    // and typed text).
    return ListView(
      key: ValueKey(bill.id),
      padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.xl),
      children: [
        _TitleField(key: const ValueKey('title'), initial: bill.title),
        for (final person in bill.people)
          Padding(
            key: ValueKey(person.id),
            padding: const EdgeInsets.only(top: Gap.m),
            child: PersonCard(person: person),
          ),
        const Padding(
          key: ValueKey('add-person'),
          padding: EdgeInsets.only(top: Gap.l),
          child: AddPersonField(),
        ),
        const Padding(
          key: ValueKey('adjustments'),
          padding: EdgeInsets.only(top: Gap.l),
          child: AdjustmentsCard(),
        ),
      ],
    );
  }
}

class _TitleField extends ConsumerWidget {
  const _TitleField({required this.initial, super.key});

  final String? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextFormField(
      initialValue: initial,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Bill title (optional)',
        prefixIcon: Icon(Icons.receipt_long_outlined),
      ),
      onChanged: ref.read(billEditorProvider.notifier).setTitle,
    );
  }
}

class _CurrencyButton extends ConsumerWidget {
  const _CurrencyButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(billEditorProvider.select((b) => b.currency));
    final editor = ref.read(billEditorProvider.notifier);
    return PopupMenuButton<Currency>(
      tooltip: 'Currency',
      onOpened: () {
        if (!editor.canChangeCurrency) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Currency can only change before amounts are added',
              ),
            ),
          );
        }
      },
      enabled: true,
      itemBuilder: (_) => [
        for (final c in Currency.supported)
          PopupMenuItem(
            value: c,
            enabled: editor.canChangeCurrency,
            child: Text(c.code),
          ),
      ],
      onSelected: editor.setCurrency,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.m),
        child: Center(
          child: Text(
            currency.code,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NewBillButton extends ConsumerWidget {
  const _NewBillButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'New bill',
      icon: const Icon(Icons.add_box_outlined),
      onPressed: () async {
        final bill = ref.read(billEditorProvider);
        final empty = bill.people.isEmpty && bill.hasNoAmounts;
        final confirmed =
            empty ||
            (await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Start a new bill?'),
                    content: const Text('The current bill will be cleared.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('New bill'),
                      ),
                    ],
                  ),
                ) ??
                false);
        if (confirmed) ref.read(billEditorProvider.notifier).reset();
      },
    );
  }
}
