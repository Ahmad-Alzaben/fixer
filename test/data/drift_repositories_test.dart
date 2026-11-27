import 'dart:io';

import 'package:drift/native.dart';
import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/data/db/app_database.dart';
import 'package:fixer/data/repositories/drift_bill_repository.dart';
import 'package:fixer/data/repositories/drift_tag_repository.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

Money jod(String s) => Money.parse(s, Currency.jod);

Bill sampleBill({
  String id = 'b1',
  DateTime? createdAt,
  Set<String> tags = const {'tag-food'},
}) => Bill(
  id: id,
  title: 'Lunch',
  currency: Currency.jod,
  createdAt: createdAt ?? DateTime(2026, 11, 20, 13),
  tagIds: tags,
  people: [
    Person(
      id: '$id-a',
      name: 'Ahmad',
      isMe: true,
      items: [
        BillItem(id: '$id-i1', price: jod('1.45'), description: 'Falafel'),
        BillItem(id: '$id-i2', price: jod('1')),
      ],
    ),
    Person(
      id: '$id-o',
      name: 'Omar',
      phone: '+962791234567',
      contactId: 'c42',
      items: [BillItem(id: '$id-i3', price: jod('3'))],
    ),
  ],
  serviceFee: jod('0.7'),
  discount: jod('0.5'),
);

void main() {
  late AppDatabase db;
  late DriftBillRepository bills;
  late DriftTagRepository tags;
  var now = DateTime(2026, 11, 27, 12);

  setUp(() {
    db = openTestDatabase();
    bills = DriftBillRepository(db, clock: () => now);
    tags = DriftTagRepository(
      db,
      idGenerator: () => 'tag-new',
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  test('a saved bill loads back identically', () async {
    await bills.save(sampleBill());
    final loaded = (await bills.getById('b1'))!;

    expect(loaded.title, 'Lunch');
    expect(loaded.currency, Currency.jod);
    expect(loaded.createdAt, DateTime(2026, 11, 20, 13));
    expect(loaded.tagIds, {'tag-food'});
    expect(loaded.serviceFee, jod('0.7'));
    expect(loaded.discount, jod('0.5'));
    expect(loaded.deliveryFee.isZero, isTrue);
    expect(loaded.people.map((p) => p.name), ['Ahmad', 'Omar']);
    expect(loaded.people.first.isMe, isTrue);
    expect(loaded.people.last.phone, '+962791234567');
    expect(loaded.people.last.contactId, 'c42');
    expect(
      loaded.people.first.items.map((i) => (i.description, i.price.minorUnits)),
      [('Falafel', 1450), (null, 1000)],
    );
  });

  test('the split mode is saved and loaded', () async {
    await bills.save(sampleBill().copyWith(splitMode: SplitMode.equal));
    expect((await bills.getById('b1'))!.splitMode, SplitMode.equal);
    await bills.save(sampleBill().copyWith(splitMode: SplitMode.proportional));
    expect((await bills.getById('b1'))!.splitMode, SplitMode.proportional);
  });

  test(
    'bills saved by an older version (schema 2) load as proportional',
    () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('fixer').path}/old.sqlite',
      );
      // Create a current database with one bill, then turn it back into a
      // schema-2 database: no split_mode column, user_version 2.
      final current = AppDatabase(NativeDatabase(file));
      await DriftBillRepository(current, clock: () => now).save(sampleBill());
      await current.customStatement('ALTER TABLE bills DROP COLUMN split_mode');
      await current.customStatement('PRAGMA user_version = 2');
      await current.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final loaded = await DriftBillRepository(upgraded).getById('b1');
      expect(loaded!.splitMode, SplitMode.proportional);
      expect(loaded.people.length, 2);
    },
  );

  test('a bill without a creation date gets the save time', () async {
    await bills.save(sampleBill().copyWith(createdAt: () => null));
    expect((await bills.getById('b1'))!.createdAt, now);
  });

  test(
    're-saving replaces people, items and tags, keeping tombstones',
    () async {
      await bills.save(sampleBill());
      final original = (await bills.getById('b1'))!;
      final edited = original.copyWith(
        tagIds: {'tag-electronics'},
        people: [
          original.people.first.copyWith(
            items: [original.people.first.items.first],
          ),
        ],
      );
      now = DateTime(2026, 11, 28);
      await bills.save(edited);

      final loaded = (await bills.getById('b1'))!;
      expect(loaded.people.map((p) => p.name), ['Ahmad']);
      expect(loaded.people.single.items.length, 1);
      expect(loaded.tagIds, {'tag-electronics'});

      // Removed rows stay as tombstones (deletedAt set) for future sync.
      final omar = await (db.select(
        db.people,
      )..where((p) => p.id.equals('b1-o'))).getSingle();
      expect(omar.deletedAt, now);
      final item2 = await (db.select(
        db.items,
      )..where((i) => i.id.equals('b1-i2'))).getSingle();
      expect(item2.deletedAt, now);
    },
  );

  test('watchAll lists bills newest first and updates live', () async {
    final stream = bills.watchAll();
    final emissions = <List<String>>[];
    final sub = stream.listen(
      (list) => emissions.add([for (final b in list) b.id]),
    );

    await bills.save(sampleBill(id: 'old', createdAt: DateTime(2026, 10, 1)));
    await bills.save(sampleBill(id: 'new', createdAt: DateTime(2026, 11, 1)));
    await pumpEventQueue();
    expect(emissions.last, ['new', 'old']);

    await bills.delete('new');
    await pumpEventQueue();
    expect(emissions.last, ['old']);
    await sub.cancel();
  });

  test('delete is soft and can be restored', () async {
    await bills.save(sampleBill());
    await bills.delete('b1');
    expect(await bills.getById('b1'), isNull);
    final row = await (db.select(
      db.bills,
    )..where((b) => b.id.equals('b1'))).getSingle();
    expect(row.deletedAt, now);

    await bills.restore('b1');
    expect((await bills.getById('b1'))!.people.length, 2);
  });

  group('tags', () {
    test('starts with the default categories', () async {
      final names = (await tags.watchAll().first).map((t) => t.name);
      expect(names, containsAll(['Food', 'Groceries', 'Electronics', 'Other']));
    });

    test('creates a custom tag at the end of the list', () async {
      final created = await tags.create('  Gaming ');
      expect(created.name, 'Gaming');
      expect((await tags.watchAll().first).last.name, 'Gaming');
    });

    test('rejects blank or duplicate names', () async {
      expect(() => tags.create(' '), throwsArgumentError);
      expect(() => tags.create('food'), throwsArgumentError);
    });
  });
}
