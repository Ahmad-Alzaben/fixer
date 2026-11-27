import 'package:fixer/core/clock.dart';
import 'package:fixer/core/ids.dart';
import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/application/auto_save.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/bill/application/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

Money jod(String s) => Money.parse(s, Currency.jod);

void main() {
  late ProviderContainer container;
  late FakeBillRepository repo;
  late BillEditor editor;
  final now = DateTime(2026, 11, 27, 19);

  setUp(() {
    var next = 0;
    repo = FakeBillRepository();
    container = ProviderContainer(
      overrides: [
        idGeneratorProvider.overrideWithValue(() => 'id${next++}'),
        clockProvider.overrideWithValue(() => now),
        billRepositoryProvider.overrideWithValue(repo),
        autoSaveDelayProvider.overrideWithValue(Duration.zero),
      ],
    );
    editor = container.read(billEditorProvider.notifier);
  });

  tearDown(() => container.dispose());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  test('a new bill is stamped with the current time', () {
    expect(container.read(billEditorProvider).createdAt, now);
  });

  group('auto-save', () {
    setUp(() => container.read(autoSaveProvider));

    test('does not save a bill with no items', () async {
      editor.addPerson('A');
      await settle();
      expect(repo.saveCount, 0);
    });

    test('saves the latest state once a person has an item', () async {
      final a = editor.addPerson('A');
      editor.addItem(a, jod('1'));
      editor.setTitle('Lunch');
      await settle();
      final saved = repo.saved.values.single;
      expect(saved.title, 'Lunch');
      expect(saved.people.single.items.single.price, jod('1'));
    });

    test('rapid edits are coalesced into one save', () async {
      final a = editor.addPerson('A');
      for (var i = 0; i < 5; i++) {
        editor.addItem(a, jod('1'));
      }
      await settle();
      expect(repo.saveCount, 1);
    });
  });

  test('open loads a saved bill into the editor', () async {
    final a = editor.addPerson('A');
    editor.addItem(a, jod('2'));
    final saved = container.read(billEditorProvider);
    editor.reset();
    expect(container.read(billEditorProvider).people, isEmpty);

    editor.open(saved);
    expect(container.read(billEditorProvider).id, saved.id);
    expect(container.read(billEditorProvider).people.single.name, 'A');
  });

  test('duplicate copies content with fresh ids and the current time', () {
    final a = editor.addPerson('A');
    editor
      ..addItem(a, jod('2'), description: 'Tea')
      ..toggleTag('tag-food')
      ..setServiceFee(jod('0.5'));
    final original = container.read(billEditorProvider);

    editor.duplicate(original);
    final copy = container.read(billEditorProvider);
    expect(copy.id, isNot(original.id));
    expect(copy.people.single.id, isNot(original.people.single.id));
    expect(
      copy.people.single.items.single.id,
      isNot(original.people.single.items.single.id),
    );
    expect(copy.people.single.items.single.description, 'Tea');
    expect(copy.tagIds, {'tag-food'});
    expect(copy.serviceFee, jod('0.5'));
    expect(copy.createdAt, now);
  });

  test('toggleTag adds and removes a tag', () {
    editor.toggleTag('tag-food');
    editor.toggleTag('tag-electronics');
    expect(container.read(billEditorProvider).tagIds, {
      'tag-food',
      'tag-electronics',
    });
    editor.toggleTag('tag-food');
    expect(container.read(billEditorProvider).tagIds, {'tag-electronics'});
  });

  test('a person added from contacts keeps phone and contact id', () {
    editor.addPerson('Omar', phone: '+962791234567', contactId: 'c1');
    final p = container.read(billEditorProvider).people.single;
    expect(p.phone, '+962791234567');
    expect(p.contactId, 'c1');
  });
}
