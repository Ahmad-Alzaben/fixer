import 'package:drift/drift.dart';
import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/data/db/app_database.dart';
import 'package:fixer/features/bill/application/repositories.dart';
import 'package:fixer/features/bill/domain/bill.dart';

/// [BillRepository] backed by the local SQLite database.
class DriftBillRepository implements BillRepository {
  DriftBillRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Stream<List<Bill>> watchAll() {
    // Re-query whenever any bill-related table changes.
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.bills, _db.people, _db.items, _db.billTags},
        )
        .watch()
        .asyncMap((_) => _loadBills());
  }

  @override
  Future<Bill?> getById(String id) async {
    final list = await _loadBills(onlyId: id);
    return list.isEmpty ? null : list.single;
  }

  @override
  Future<void> save(Bill bill) {
    final now = _clock();
    return _db.transaction(() async {
      await _db
          .into(_db.bills)
          .insertOnConflictUpdate(
            BillsCompanion.insert(
              id: bill.id,
              title: Value(bill.title),
              currency: bill.currency.code,
              serviceFee: bill.serviceFee.minorUnits,
              deliveryFee: bill.deliveryFee.minorUnits,
              discount: bill.discount.minorUnits,
              splitMode: Value(bill.splitMode.name),
              taxMode: Value(bill.taxMode.name),
              taxRate: Value(bill.taxRate),
              createdAt: bill.createdAt ?? now,
              updatedAt: now,
              deletedAt: const Value(null),
            ),
          );

      final personIds = {for (final p in bill.people) p.id};
      final itemIds = {
        for (final p in bill.people)
          for (final i in p.items) i.id,
      };

      // Tombstone children that are no longer part of the bill.
      await (_db.update(_db.people)..where(
            (p) =>
                p.billId.equals(bill.id) &
                p.deletedAt.isNull() &
                p.id.isNotIn(personIds),
          ))
          .write(PeopleCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await (_db.update(_db.items)..where(
            (i) =>
                i.billId.equals(bill.id) &
                i.deletedAt.isNull() &
                i.id.isNotIn(itemIds),
          ))
          .write(ItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await (_db.update(_db.billTags)..where(
            (t) =>
                t.billId.equals(bill.id) &
                t.deletedAt.isNull() &
                t.tagId.isNotIn(bill.tagIds),
          ))
          .write(
            BillTagsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
          );

      await _db.batch((b) {
        for (final (pi, person) in bill.people.indexed) {
          b.insert(
            _db.people,
            PeopleCompanion.insert(
              id: person.id,
              billId: bill.id,
              position: pi,
              name: person.name,
              isMe: Value(person.isMe),
              phone: Value(person.phone),
              contactId: Value(person.contactId),
              updatedAt: now,
              deletedAt: const Value(null),
            ),
            mode: InsertMode.insertOrReplace,
          );
          for (final (ii, item) in person.items.indexed) {
            b.insert(
              _db.items,
              ItemsCompanion.insert(
                id: item.id,
                billId: bill.id,
                personId: person.id,
                position: ii,
                description: Value(item.description),
                price: item.price.minorUnits,
                updatedAt: now,
                deletedAt: const Value(null),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }
        for (final tagId in bill.tagIds) {
          b.insert(
            _db.billTags,
            BillTagsCompanion.insert(
              billId: bill.id,
              tagId: tagId,
              updatedAt: now,
              deletedAt: const Value(null),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  @override
  Future<void> delete(String id) => _setDeleted(id, _clock());

  @override
  Future<void> restore(String id) => _setDeleted(id, null);

  Future<void> _setDeleted(String id, DateTime? deletedAt) =>
      (_db.update(_db.bills)..where((b) => b.id.equals(id))).write(
        BillsCompanion(deletedAt: Value(deletedAt), updatedAt: Value(_clock())),
      );

  Future<List<Bill>> _loadBills({String? onlyId}) async {
    final billQuery = _db.select(_db.bills)
      ..where((b) => b.deletedAt.isNull())
      ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]);
    if (onlyId != null) billQuery.where((b) => b.id.equals(onlyId));
    final billRows = await billQuery.get();
    if (billRows.isEmpty) return const [];
    final ids = billRows.map((b) => b.id).toList();

    final people =
        await (_db.select(_db.people)
              ..where((p) => p.billId.isIn(ids) & p.deletedAt.isNull())
              ..orderBy([(p) => OrderingTerm.asc(p.position)]))
            .get();
    final items =
        await (_db.select(_db.items)
              ..where((i) => i.billId.isIn(ids) & i.deletedAt.isNull())
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .get();
    final tags = await (_db.select(
      _db.billTags,
    )..where((t) => t.billId.isIn(ids) & t.deletedAt.isNull())).get();

    return [
      for (final row in billRows)
        _toBill(
          row,
          people.where((p) => p.billId == row.id),
          items,
          tags.where((t) => t.billId == row.id),
        ),
    ];
  }

  Bill _toBill(
    BillRow row,
    Iterable<PersonRow> people,
    List<ItemRow> items,
    Iterable<BillTagRow> tags,
  ) {
    final currency = Currency.byCode(row.currency) ?? Currency.defaultCurrency;
    Money money(int minor) => Money(minor, currency);
    return Bill(
      id: row.id,
      title: row.title,
      currency: currency,
      createdAt: row.createdAt,
      splitMode: SplitMode.values.firstWhere(
        (m) => m.name == row.splitMode,
        orElse: () => SplitMode.proportional,
      ),
      taxMode: TaxMode.values.firstWhere(
        (m) => m.name == row.taxMode,
        orElse: () => TaxMode.none,
      ),
      taxRate: row.taxRate,
      tagIds: {for (final t in tags) t.tagId},
      serviceFee: money(row.serviceFee),
      deliveryFee: money(row.deliveryFee),
      discount: money(row.discount),
      people: [
        for (final p in people)
          Person(
            id: p.id,
            name: p.name,
            isMe: p.isMe,
            phone: p.phone,
            contactId: p.contactId,
            items: [
              for (final i in items.where((i) => i.personId == p.id))
                BillItem(
                  id: i.id,
                  description: i.description,
                  price: money(i.price),
                ),
            ],
          ),
      ],
    );
  }
}
