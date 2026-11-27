import 'package:fixer/core/money/money.dart';
import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/core/widgets/fit_amount.dart';
import 'package:fixer/core/widgets/section_label.dart';
import 'package:fixer/features/bill/application/providers.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/reports/domain/monthly_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final monthlyReportsProvider = Provider<AsyncValue<List<MonthlyReport>>>(
  (ref) => ref.watch(savedBillsProvider).whenData(buildMonthlyReports),
);

String _monthName(MonthKey m) =>
    DateFormat('MMMM yyyy', 'en_US').format(DateTime(m.year, m.month));

/// What I spent per month (my share only), by tag, with recent months.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  MonthKey? _selected;

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(monthlyReportsProvider);
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final tagNames = {for (final t in tags) t.id: t.name};

    return Scaffold(
      appBar: AppBar(title: const Text('REPORTS')),
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load reports: $e')),
        data: (all) {
          if (all.isEmpty) return const _EmptyReports();
          final months = {for (final r in all) r.month}.toList()
            ..sort((a, b) => b.compareTo(a));
          final selected = months.contains(_selected)
              ? _selected!
              : months.first;
          final index = months.indexOf(selected);
          final thisMonth = all.where((r) => r.month == selected).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xl),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: index < months.length - 1
                        ? () => setState(() => _selected = months[index + 1])
                        : null,
                  ),
                  Expanded(
                    child: Center(child: SectionLabel(_monthName(selected))),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: index > 0
                        ? () => setState(() => _selected = months[index - 1])
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: Gap.s),
              for (final report in thisMonth) ...[
                _MonthCard(report: report, tagNames: tagNames),
                const SizedBox(height: Gap.l),
              ],
              _RecentMonths(reports: all, selected: selected),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: Gap.m),
            Text(
              'No spending yet.\nBills where you are marked as Me show up '
              'here by month. Set your name in Settings to be marked '
              'automatically.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.report, required this.tagNames});

  final MonthlyReport report;
  final Map<String, String> tagNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = [
      for (final e in report.byTag.entries)
        (tagNames[e.key] ?? 'Deleted tag', e.value),
      if (!report.untagged.isZero) ('Untagged', report.untagged),
    ]..sort((a, b) => b.$2.minorUnits.compareTo(a.$2.minorUnits));
    final max = rows.isEmpty ? 0 : rows.first.$2.minorUnits;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'YOU SPENT',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.6,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                report.myTotal.toString(),
                style: theme.textTheme.amountLarge.copyWith(
                  fontSize: 32,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Text(
              report.billCount == 1 ? '1 bill' : '${report.billCount} bills',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (report.billsWithoutMe > 0) ...[
              const SizedBox(height: Gap.m),
              Text(
                report.billsWithoutMe == 1
                    ? '1 bill has nobody marked as Me and is not counted.'
                    : '${report.billsWithoutMe} bills have nobody marked as '
                          'Me and are not counted.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (rows.isNotEmpty) ...[
              const SizedBox(height: Gap.l),
              for (final (name, amount) in rows)
                _BarRow(label: name, amount: amount, max: max),
              if (report.byTag.length > 1 ||
                  (report.byTag.isNotEmpty && !report.untagged.isZero))
                Padding(
                  padding: const EdgeInsets.only(top: Gap.s),
                  child: Text(
                    'A bill with several tags counts toward each of them.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.amount,
    required this.max,
    this.highlight = true,
  });

  final String label;
  final Money amount;
  final int max;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = max == 0 ? 0.0 : amount.minorUnits / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
              FitAmount(
                amount.toString(),
                style: theme.textTheme.amount.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.02, 1.0),
                child: Container(
                  height: 4,
                  color: highlight
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The last six months, per currency, for a quick trend.
class _RecentMonths extends StatelessWidget {
  const _RecentMonths({required this.reports, required this.selected});

  final List<MonthlyReport> reports;
  final MonthKey selected;

  @override
  Widget build(BuildContext context) {
    final months = {for (final r in reports) r.month}.take(6).toSet();
    final recent = reports.where((r) => months.contains(r.month)).toList();
    if (months.length < 2) return const SizedBox.shrink();
    final currencies = {for (final r in recent) r.currency.code};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Recent months'),
        const SizedBox(height: Gap.s),
        for (final code in currencies) ...[
          for (final r in recent.where((r) => r.currency.code == code))
            _BarRow(
              label: DateFormat(
                'MMM yyyy',
                'en_US',
              ).format(DateTime(r.month.year, r.month.month)),
              amount: r.myTotal,
              max: recent
                  .where((x) => x.currency.code == code)
                  .map((x) => x.myTotal.minorUnits)
                  .reduce((a, b) => a > b ? a : b),
              highlight: r.month == selected,
            ),
        ],
      ],
    );
  }
}
