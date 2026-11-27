import 'package:fixer/core/money/money.dart';
import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/core/widgets/money_input.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Edit an item's description and price, or delete it.
Future<void> showEditItemDialog(
  BuildContext context,
  WidgetRef ref,
  String personId,
  BillItem item,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EditItemDialog(ref: ref, personId: personId, item: item),
  );
}

class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({
    required this.ref,
    required this.personId,
    required this.item,
  });

  final WidgetRef ref;
  final String personId;
  final BillItem item;

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final _description = TextEditingController(
    text: widget.item.description,
  );
  late final _price = TextEditingController(
    text: widget.item.price.toDecimalString(),
  );
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  BillEditor get _editor => widget.ref.read(billEditorProvider.notifier);

  void _save() {
    final currency = widget.item.price.currency;
    final Money price;
    try {
      price = Money.parse(_price.text, currency);
    } on FormatException {
      setState(() => _error = 'Not a valid price');
      return;
    }
    if (price.isZero) {
      setState(() => _error = 'Enter a price above 0');
      return;
    }
    _editor.updateItem(
      widget.personId,
      widget.item.id,
      price: price,
      description: _description.text,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.item.price.currency;
    return AlertDialog(
      title: const Text('Edit item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          const SizedBox(height: Gap.m),
          TextField(
            controller: _price,
            keyboardType: moneyKeyboard,
            inputFormatters: moneyInputFormatters(currency),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Price',
              suffixText: currency.code,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _editor.removeItem(widget.personId, widget.item.id);
            Navigator.pop(context);
          },
          child: Text(
            'Delete',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
