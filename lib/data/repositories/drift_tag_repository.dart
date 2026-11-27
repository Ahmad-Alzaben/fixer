import 'package:drift/drift.dart';
import 'package:fixer/data/db/app_database.dart';
import 'package:fixer/features/bill/application/repositories.dart';
import 'package:fixer/features/bill/domain/bill.dart';

class DriftTagRepository implements TagRepository {
  DriftTagRepository(
    this._db, {
    required String Function() idGenerator,
    DateTime Function()? clock,
  }) : _newId = idGenerator,
       _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _clock;

  @override
  Stream<List<Tag>> watchAll() {
    final query = _db.select(_db.tags)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return query.watch().map(
      (rows) => [for (final r in rows) Tag(id: r.id, name: r.name)],
    );
  }

  @override
  Future<Tag> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'is blank');
    final existing = await watchAll().first;
    if (existing.any((t) => t.name.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError.value(name, 'name', 'already exists');
    }
    final tag = Tag(id: _newId(), name: trimmed);
    await _db
        .into(_db.tags)
        .insert(
          TagsCompanion.insert(
            id: tag.id,
            name: tag.name,
            position: existing.length,
            updatedAt: _clock(),
          ),
        );
    return tag;
  }
}
