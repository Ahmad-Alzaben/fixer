import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/core/widgets/money_input.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/presentation/widgets/edit_item_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One person: name, running subtotal, items and a quick price field.
class PersonCard extends ConsumerWidget {
  const PersonCard({required this.person, super.key});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(billEditorProvider.select((b) => b.currency));
    final subtotal = person.items.fold(
      Money.zero(currency),
      (sum, i) => sum + i.price,
    );
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.m, Gap.xs, Gap.xs, Gap.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          person.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (person.isMe) ...[
                        const SizedBox(width: Gap.s),
                        const _MeBadge(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Gap.s),
                Text(subtotal.toString(), style: theme.textTheme.amount),
                _PersonMenu(person: person),
              ],
            ),
            for (final (index, item) in person.items.indexed)
              _ItemRow(person: person, item: item, number: index + 1),
            Padding(
              padding: const EdgeInsets.only(top: Gap.s, right: Gap.s),
              child: _PriceEntry(personId: person.id, currency: currency),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeBadge extends StatelessWidget {
  const _MeBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: scheme.primary,
      child: Text(
        'ME',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _PersonAction { rename, toggleMe, remove }

class _PersonMenu extends ConsumerWidget {
  const _PersonMenu({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(billEditorProvider.notifier);
    return PopupMenuButton<_PersonAction>(
      tooltip: 'Options for ${person.name}',
      onSelected: (action) async {
        switch (action) {
          case _PersonAction.rename:
            final name = await _askName(context, person.name);
            if (name != null && name.trim().isNotEmpty) {
              editor.renamePerson(person.id, name);
            }
          case _PersonAction.toggleMe:
            editor.toggleMe(person.id);
          case _PersonAction.remove:
            final undo = editor.removePerson(person.id);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('${person.name} removed'),
                  action: SnackBarAction(label: 'Undo', onPressed: undo),
                ),
              );
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: _PersonAction.rename, child: Text('Rename')),
        PopupMenuItem(
          value: _PersonAction.toggleMe,
          child: Text(person.isMe ? 'Unmark as me' : 'This is me'),
        ),
        const PopupMenuItem(value: _PersonAction.remove, child: Text('Remove')),
      ],
    );
  }

  Future<String?> _askName(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    required this.person,
    required this.item,
    required this.number,
  });

  final Person person;
  final BillItem item;
  final int number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = item.description ?? 'Item $number';
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Gap.l),
        color: theme.colorScheme.error.withValues(alpha: 0.2),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.error),
      ),
      onDismissed: (_) =>
          ref.read(billEditorProvider.notifier).removeItem(person.id, item.id),
      child: InkWell(
        onTap: () => showEditItemDialog(context, ref, person.id, item),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.only(right: Gap.m),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: item.description == null
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                ),
                Text(
                  item.price.toDecimalString(),
                  style: theme.textTheme.amount,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Price-only quick entry: type, press Enter, type the next one.
class _PriceEntry extends ConsumerStatefulWidget {
  const _PriceEntry({required this.personId, required this.currency});

  final String personId;
  final Currency currency;

  @override
  ConsumerState<_PriceEntry> createState() => _PriceEntryState();
}

class _PriceEntryState extends ConsumerState<_PriceEntry> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final Money price;
    try {
      price = Money.parse(text, widget.currency);
    } on FormatException {
      setState(() => _error = 'Not a valid price');
      return;
    }
    if (price.isZero) {
      setState(() => _error = 'Enter a price above 0');
      return;
    }
    ref.read(billEditorProvider.notifier).addItem(widget.personId, price);
    _controller.clear();
    setState(() => _error = null);
    refocus(_focus);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey('price-${widget.personId}'),
      controller: _controller,
      focusNode: _focus,
      keyboardType: moneyKeyboard,
      inputFormatters: moneyInputFormatters(widget.currency),
      textInputAction: TextInputAction.done,
      onEditingComplete: keepFocus,
      onSubmitted: (_) => _submit(),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: InputDecoration(
        labelText: 'Add price',
        hintText: moneyHint(widget.currency),
        errorText: _error,
        suffixText: widget.currency.code,
        suffixIcon: IconButton(
          tooltip: 'Add item',
          icon: const Icon(Icons.add),
          onPressed: _submit,
        ),
      ),
    );
  }
}
