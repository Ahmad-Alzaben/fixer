import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';

/// Plain-text summary used by "Copy results" and "Share results".
String buildResultText(Bill bill, BillCalculation calculation) {
  final buffer = StringBuffer();
  if (bill.title != null) buffer.writeln(bill.title);
  buffer
    ..writeln('Bill total: ${calculation.total}')
    ..writeln();
  final lines = [
    for (final person in bill.people)
      '${person.name}: ${calculation.shareOf(person.id)?.total}',
  ];
  buffer.write(lines.join('\n'));
  return buffer.toString();
}
