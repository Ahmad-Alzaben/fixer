import 'package:fixer/core/ids.dart';
import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Money jod(String s) => Money.parse(s, Currency.jod);

void main() {
  late ProviderContainer container;
  late BillEditor editor;

  setUp(() {
    var next = 0;
    container = ProviderContainer(
      overrides: [idGeneratorProvider.overrideWithValue(() => 'id${next++}')],
    );
    editor = container.read(billEditorProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('starts empty in the default currency (JOD)', () {
    final bill = container.read(billEditorProvider);
    expect(bill.people, isEmpty);
    expect(bill.currency, Currency.jod);
    expect(bill.serviceFee.isZero, isTrue);
  });

  test('adds people with trimmed names and rejects blank names', () {
    final id = editor.addPerson('  Omar ');
    final bill = container.read(billEditorProvider);
    expect(bill.people.single.name, 'Omar');
    expect(bill.people.single.id, id);
    expect(() => editor.addPerson('   '), throwsArgumentError);
  });

  test('renames and removes people; removal can be undone in place', () {
    final a = editor.addPerson('A');
    editor.addPerson('B');
    editor.renamePerson(a, 'Ahmad');
    expect(container.read(billEditorProvider).people.first.name, 'Ahmad');

    final undo = editor.removePerson(a);
    expect(container.read(billEditorProvider).people.map((p) => p.name), ['B']);
    undo();
    expect(container.read(billEditorProvider).people.map((p) => p.name), [
      'Ahmad',
      'B',
    ]);
  });

  test(
    'marking Me moves the flag; marking the same person again clears it',
    () {
      final a = editor.addPerson('A');
      final b = editor.addPerson('B');
      editor.toggleMe(a);
      editor.toggleMe(b);
      var people = container.read(billEditorProvider).people;
      expect(people.map((p) => p.isMe), [false, true]);
      editor.toggleMe(b);
      people = container.read(billEditorProvider).people;
      expect(people.any((p) => p.isMe), isFalse);
    },
  );

  test('adds, edits and removes items; calculation updates live', () {
    final a = editor.addPerson('A');
    final item = editor.addItem(a, jod('1.45'));
    editor.addItem(a, jod('1.00'), description: 'Tea');
    expect(container.read(billCalculationProvider).total, jod('2.45'));

    editor.updateItem(a, item, price: jod('2'), description: 'Falafel');
    final items = container.read(billEditorProvider).people.single.items;
    expect(items.first.description, 'Falafel');
    expect(container.read(billCalculationProvider).total, jod('3'));

    editor.removeItem(a, item);
    expect(container.read(billCalculationProvider).total, jod('1'));
  });

  test('updating only the price keeps the description; blank clears it', () {
    final a = editor.addPerson('A');
    final item = editor.addItem(a, jod('1'), description: 'Tea');
    editor.updateItem(a, item, price: jod('2'));
    var stored = container.read(billEditorProvider).people.single.items.single;
    expect(stored.description, 'Tea');
    expect(stored.price, jod('2'));

    editor.updateItem(a, item, description: '');
    stored = container.read(billEditorProvider).people.single.items.single;
    expect(stored.description, isNull);
  });

  test('a blank description is stored as none', () {
    final a = editor.addPerson('A');
    editor.addItem(a, jod('1'), description: '  ');
    expect(
      container.read(billEditorProvider).people.single.items.single.description,
      isNull,
    );
  });

  test('adjustments feed the calculation (brief example)', () {
    final a = editor.addPerson('A');
    final o = editor.addPerson('O');
    final j = editor.addPerson('J');
    editor
      ..setSplitMode(SplitMode.proportional)
      ..addItem(a, jod('1.45'))
      ..addItem(a, jod('1.00'))
      ..addItem(o, jod('3.00'))
      ..addItem(j, jod('1.65'))
      ..setServiceFee(jod('0.70'))
      ..setDiscount(jod('2.13'));
    final c = container.read(billCalculationProvider);
    expect(c.total, jod('5.670'));
    expect(c.shares.map((s) => s.total.minorUnits), [1956, 2396, 1318]);

    editor.setDeliveryFee(jod('1'));
    expect(container.read(billCalculationProvider).total, jod('6.670'));
  });

  test('currency can change only while the bill has no amounts', () {
    final a = editor.addPerson('A');
    expect(editor.canChangeCurrency, isTrue);
    editor.setCurrency(Currency.usd);
    expect(container.read(billEditorProvider).currency, Currency.usd);

    editor.addItem(a, Money.parse('1.50', Currency.usd));
    expect(editor.canChangeCurrency, isFalse);
    expect(() => editor.setCurrency(Currency.jod), throwsStateError);
  });

  test('title is optional and trimmed', () {
    editor.setTitle('  Dinner ');
    expect(container.read(billEditorProvider).title, 'Dinner');
    editor.setTitle(' ');
    expect(container.read(billEditorProvider).title, isNull);
  });

  test('reset starts a fresh bill with a new id', () {
    final firstId = container.read(billEditorProvider).id;
    editor.addPerson('A');
    editor.reset();
    final bill = container.read(billEditorProvider);
    expect(bill.people, isEmpty);
    expect(bill.id, isNot(firstId));
  });
}
