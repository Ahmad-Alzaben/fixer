import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/core/widgets/money_input.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service fee, delivery fee and discount, collapsed until needed.
class AdjustmentsCard extends ConsumerWidget {
  const AdjustmentsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = ref.watch(billEditorProvider);
    final editor = ref.read(billEditorProvider.notifier);
    final discountTooBig = ref.watch(
      billCalculationProvider.select(
        (c) => c.warnings.contains(CalculationWarning.discountExceedsTotal),
      ),
    );
    final parts = [
      if (!bill.serviceFee.isZero)
        'Service ${bill.serviceFee.toDecimalString()}',
      if (!bill.deliveryFee.isZero)
        'Delivery ${bill.deliveryFee.toDecimalString()}',
      if (!bill.discount.isZero) 'Discount ${bill.discount.toDecimalString()}',
    ];
    final anySet = parts.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: anySet,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.percent),
        title: const Text('Fees & discount'),
        subtitle: Text(anySet ? parts.join(' · ') : 'None'),
        // Top padding leaves room for the first field's floating label, which
        // sits above the field's border and was clipped with 0 here.
        childrenPadding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.m, Gap.m),
        children: [
          _MoneyField(
            label: 'Service fee',
            initial: bill.serviceFee,
            currency: bill.currency,
            onChanged: editor.setServiceFee,
          ),
          const SizedBox(height: Gap.m),
          _MoneyField(
            label: 'Delivery fee',
            initial: bill.deliveryFee,
            currency: bill.currency,
            onChanged: editor.setDeliveryFee,
          ),
          const SizedBox(height: Gap.m),
          _MoneyField(
            label: 'Discount',
            initial: bill.discount,
            currency: bill.currency,
            onChanged: editor.setDiscount,
            warning: discountTooBig
                ? 'Discount is larger than the bill. The total is capped at 0.'
                : null,
          ),
        ],
      ),
    );
  }
}

class _MoneyField extends StatefulWidget {
  const _MoneyField({
    required this.label,
    required this.initial,
    required this.currency,
    required this.onChanged,
    this.warning,
  });

  final String label;
  final Money initial;
  final Currency currency;
  final ValueChanged<Money> onChanged;
  final String? warning;

  @override
  State<_MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<_MoneyField> {
  late final _controller = TextEditingController(
    text: widget.initial.isZero ? '' : widget.initial.toDecimalString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) {
    if (text.trim().isEmpty) {
      widget.onChanged(Money.zero(widget.currency));
      return;
    }
    try {
      widget.onChanged(Money.parse(text, widget.currency));
    } on FormatException {
      // e.g. a lone "." while typing; the formatter blocks anything worse.
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: moneyKeyboard,
      inputFormatters: moneyInputFormatters(widget.currency),
      textInputAction: TextInputAction.next,
      onChanged: _changed,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: moneyHint(widget.currency),
        suffixText: widget.currency.code,
        errorText: widget.warning,
        errorMaxLines: 2,
      ),
    );
  }
}
