import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculator.dart';
import 'package:fixer/features/results/application/result_text.dart';
import 'package:flutter_test/flutter_test.dart';

Money jod(String s) => Money.parse(s, Currency.jod);

Bill exampleBill({String? title}) => Bill(
  id: 'b',
  title: title,
  currency: Currency.jod,
  people: [
    Person(
      id: 'a',
      name: 'A',
      items: [
        BillItem(id: '1', price: jod('1.45')),
        BillItem(id: '2', price: jod('1.00')),
      ],
    ),
    Person(
      id: 'o',
      name: 'O',
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

void main() {
  test('lists the bill total then each person in order', () {
    final bill = exampleBill();
    final text = buildResultText(bill, const BillCalculator().calculate(bill));
    expect(
      text,
      'Bill total: 5.670 JOD\n'
      '\n'
      'A: 1.956 JOD\n'
      'O: 2.396 JOD\n'
      'J: 1.318 JOD',
    );
  });

  test('puts the title on the first line when there is one', () {
    final bill = exampleBill(title: 'Shawarma night');
    final text = buildResultText(bill, const BillCalculator().calculate(bill));
    expect(text.split('\n').first, 'Shawarma night');
    expect(text.split('\n')[1], 'Bill total: 5.670 JOD');
  });
}
