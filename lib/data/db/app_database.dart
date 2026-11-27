import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// Sync-ready schema: every row has a globally unique text id, an
// `updatedAt` timestamp and a nullable `deletedAt` tombstone instead of being
// hard-deleted. A future sync service can upload rows changed since the last
// sync, including deletions.

@DataClassName('BillRow')
class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().nullable()();
  TextColumn get currency => text()();
  IntColumn get serviceFee => integer()();
  IntColumn get deliveryFee => integer()();
  IntColumn get discount => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PersonRow')
class People extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text().references(Bills, #id)();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
  TextColumn get phone => text().nullable()();
  TextColumn get contactId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ItemRow')
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text().references(Bills, #id)();
  TextColumn get personId => text().references(People, #id)();
  IntColumn get position => integer()();
  TextColumn get description => text().nullable()();
  IntColumn get price => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get position => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BillTagRow')
class BillTags extends Table {
  TextColumn get billId => text().references(Bills, #id)();
  TextColumn get tagId => text().references(Tags, #id)();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {billId, tagId};
}

/// Default categories. Fixed ids so they match across devices after sync.
const defaultTags = [
  ('tag-food', 'Food'),
  ('tag-groceries', 'Groceries'),
  ('tag-electronics', 'Electronics'),
  ('tag-transport', 'Transport'),
  ('tag-entertainment', 'Entertainment'),
  ('tag-utilities', 'Utilities'),
  ('tag-other', 'Other'),
];

@DriftDatabase(tables: [Bills, People, Items, Tags, BillTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The on-device database file (`fixer.sqlite` in app documents).
  factory AppDatabase.onDevice() => AppDatabase(driftDatabase(name: 'fixer'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      final now = DateTime.now();
      await batch((b) {
        for (final (i, (id, name)) in defaultTags.indexed) {
          b.insert(
            tags,
            TagsCompanion.insert(
              id: id,
              name: name,
              position: i,
              updatedAt: now,
            ),
          );
        }
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
