import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculator.dart';
import 'package:fixer/features/messaging/application/message_values.dart';
import 'package:fixer/features/messaging/domain/message_template.dart';
import 'package:flutter_test/flutter_test.dart';

Money jod(String s) => Money.parse(s, Currency.jod);

void main() {
  final bill = Bill(
    id: 'b',
    title: 'Shawarma night',
    currency: Currency.jod,
    people: [
      Person(
        id: 'a',
        name: 'Ahmad',
        items: [
          BillItem(id: '1', price: jod('1.45'), description: 'Shawarma'),
          BillItem(id: '2', price: jod('1.00')),
        ],
      ),
      Person(
        id: 'o',
        name: 'Omar',
        items: [BillItem(id: '3', price: jod('3'))],
      ),
      Person(
        id: 'j',
        name: 'J',
        items: [BillItem(id: '4', price: jod('1.65'))],
      ),
    ],
    serviceFee: jod('0.70'),
    discount: jod('2.13'),
  );
  final calc = const BillCalculator().calculate(bill);
  final date = DateTime(2026, 11, 27, 20, 30);

  test('fills name, amount, bill total, title and date', () {
    final v = messageValues(
      bill: bill,
      calculation: calc,
      person: bill.people[1],
      date: date,
    );
    expect(v['name'], 'Omar');
    expect(v['amount'], '2.396 JOD');
    expect(v['billTotal'], '5.670 JOD');
    expect(v['title'], 'Shawarma night');
    expect(v['date'], '27 Nov 2026');
  });

  test('items is the person\'s receipt: items, then non-zero fee lines', () {
    final v = messageValues(
      bill: bill,
      calculation: calc,
      person: bill.people[0],
      date: date,
    );
    expect(
      v['items'],
      '- Shawarma: 1.450\n'
      '- Item 2: 1.000\n'
      'Service: 0.241\n'
      'Discount: -0.735',
    );
  });

  test('untitled bill reads naturally', () {
    final untitled = Bill(id: 'x', currency: Currency.jod, people: bill.people);
    final v = messageValues(
      bill: untitled,
      calculation: const BillCalculator().calculate(untitled),
      person: untitled.people[0],
      date: date,
    );
    expect(v['title'], 'the bill');
  });

  test('renders the built-in template end to end', () {
    final text = MessageTemplate.builtIn.render(
      messageValues(
        bill: bill,
        calculation: calc,
        person: bill.people[2],
        date: date,
      ),
    );
    expect(
      text,
      'Hi J, your share of Shawarma night is 1.318 JOD.\n'
      '- Item 1: 1.650\n'
      'Service: 0.163\n'
      'Discount: -0.495',
    );
  });
}
