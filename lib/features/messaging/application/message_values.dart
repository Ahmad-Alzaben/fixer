import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';
import 'package:intl/intl.dart';

/// Values for a person's message placeholders (see `MessageTemplate`).
Map<String, String> messageValues({
  required Bill bill,
  required BillCalculation calculation,
  required Person person,
  required DateTime date,
}) {
  final share = calculation.shareOf(person.id);
  return {
    'name': person.name,
    'amount': share?.total.toString() ?? '',
    'billTotal': calculation.total.toString(),
    'title': bill.title ?? 'the bill',
    'date': DateFormat('d MMM yyyy', 'en_US').format(date),
    'items': share == null ? '' : _receipt(person, share),
  };
}

String _receipt(Person person, PersonShare share) {
  String amount(Money m) => m.toDecimalString();
  return [
    for (final (i, item) in person.items.indexed)
      '- ${item.description ?? 'Item ${i + 1}'}: ${amount(item.price)}',
    if (!share.serviceFee.isZero) 'Service: ${amount(share.serviceFee)}',
    if (!share.deliveryFee.isZero) 'Delivery: ${amount(share.deliveryFee)}',
    if (!share.discount.isZero) 'Discount: -${amount(share.discount)}',
  ].join('\n');
}
