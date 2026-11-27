import 'package:fixer/core/money/money.dart';
import 'package:fixer/core/platform/share_gateway.dart';
import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/core/widgets/section_label.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';
import 'package:fixer/features/messaging/presentation/send_sheet.dart';
import 'package:fixer/features/results/application/result_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Final amounts per person (prominent) with the breakdown one tap away.
class ResultsPanel extends ConsumerWidget {
  const ResultsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = ref.watch(billEditorProvider);
    final calc = ref.watch(billCalculationProvider);
    final theme = Theme.of(context);

    if (bill.people.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Text(
            'Add people and prices to see each share.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(Gap.l),
      children: [
        for (final w in calc.warnings) ...[
          _WarningBanner(_warningText(w)),
          const SizedBox(height: Gap.m),
        ],
        _SummaryCard(calc: calc),
        const SizedBox(height: Gap.l),
        _ShareActions(bill: bill, calc: calc),
        const SizedBox(height: Gap.l),
        const SectionLabel('Each person pays'),
        const SizedBox(height: Gap.s),
        for (final person in bill.people) ...[
          _PersonResult(
            bill: bill,
            calc: calc,
            person: person,
            share: calc.shareOf(person.id)!,
          ),
          const SizedBox(height: Gap.s),
        ],
      ],
    );
  }

  static String _warningText(CalculationWarning w) => switch (w) {
    CalculationWarning.discountExceedsTotal =>
      'Discount is larger than the bill. It was capped so the total is 0.',
    CalculationWarning.feesSplitEqually =>
      'No item prices yet, so fees are split equally.',
    CalculationWarning.noPeople => 'Add at least one person.',
  };
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Gap.m),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: scheme.error, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.error),
          const SizedBox(width: Gap.s),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.calc});

  final BillCalculation calc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Bill total'),
            const SizedBox(height: Gap.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                calc.total.toString(),
                style: theme.textTheme.amountLarge.copyWith(
                  fontSize: 32,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: Gap.m),
            _AmountLine('Subtotal', calc.subtotal),
            _AmountLine('Service fee', calc.serviceFee),
            _AmountLine('Delivery fee', calc.deliveryFee),
            _AmountLine('Discount', calc.discount, negative: true),
          ],
        ),
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine(this.label, this.amount, {this.negative = false});

  final String label;
  final Money amount;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final sign = negative && !amount.isZero ? '−' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
          Text(
            '$sign${amount.toDecimalString()}',
            style: theme.textTheme.amount.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ShareActions extends ConsumerWidget {
  const _ShareActions({required this.bill, required this.calc});

  final Bill bill;
  final BillCalculation calc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateway = ref.read(shareGatewayProvider);
    final text = buildResultText(bill, calc);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
            onPressed: () async {
              await gateway.copy(text);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Results copied')));
            },
          ),
        ),
        const SizedBox(width: Gap.m),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            onPressed: () => gateway.share(text, subject: bill.title),
          ),
        ),
      ],
    );
  }
}

class _PersonResult extends StatelessWidget {
  const _PersonResult({
    required this.bill,
    required this.calc,
    required this.person,
    required this.share,
  });

  final Bill bill;
  final BillCalculation calc;
  final Person person;
  final PersonShare share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.only(left: Gap.l, right: Gap.xs),
        // Tapping the row shows the breakdown; the amount shrinks to fit on
        // narrow screens so the Send button always has room.
        title: Row(
          children: [
            Expanded(
              child: Text(
                person.isMe ? '${person.name} (me)' : person.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: Gap.s),
            Flexible(
              fit: FlexFit.tight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  share.total.toString(),
                  style: theme.textTheme.amountLarge.copyWith(fontSize: 20),
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Send to ${person.name}',
          icon: const Icon(Icons.send_outlined),
          onPressed: () => showSendSheet(
            context,
            bill: bill,
            calculation: calc,
            person: person,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
        children: [
          _AmountLine('Items', share.subtotal),
          _AmountLine('Service fee', share.serviceFee),
          _AmountLine('Delivery fee', share.deliveryFee),
          _AmountLine('Discount', share.discount, negative: true),
        ],
      ),
    );
  }
}
