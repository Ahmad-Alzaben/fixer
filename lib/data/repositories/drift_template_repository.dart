import 'package:drift/drift.dart';
import 'package:fixer/data/db/app_database.dart';
import 'package:fixer/features/messaging/application/template_repository.dart';
import 'package:fixer/features/messaging/domain/message_template.dart';

class DriftTemplateRepository implements TemplateRepository {
  DriftTemplateRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  SimpleSelectStatement<$MessageTemplatesTable, TemplateRow> _live() =>
      _db.select(_db.messageTemplates)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.position)]);

  @override
  Stream<List<MessageTemplate>> watchAll() => _live().watch().map(
    (rows) => [
      for (final r in rows)
        MessageTemplate(
          id: r.id,
          name: r.name,
          body: r.body,
          isDefault: r.isDefault,
        ),
    ],
  );

  @override
  Future<void> save(MessageTemplate template) => _db.transaction(() async {
    final now = _clock();
    final existing = await (_db.select(
      _db.messageTemplates,
    )..where((t) => t.id.equals(template.id))).getSingleOrNull();
    final position = existing?.position ?? (await _live().get()).length;
    if (template.isDefault) await _clearDefault(now);
    await _db
        .into(_db.messageTemplates)
        .insertOnConflictUpdate(
          MessageTemplatesCompanion.insert(
            id: template.id,
            name: template.name,
            body: template.body,
            isDefault: Value(
              template.isDefault || (existing?.isDefault ?? false),
            ),
            position: position,
            updatedAt: now,
            deletedAt: const Value(null),
          ),
        );
  });

  @override
  Future<void> setDefault(String id) => _db.transaction(() async {
    final now = _clock();
    await _clearDefault(now);
    await (_db.update(
      _db.messageTemplates,
    )..where((t) => t.id.equals(id))).write(
      MessageTemplatesCompanion(
        isDefault: const Value(true),
        updatedAt: Value(now),
      ),
    );
  });

  @override
  Future<void> delete(String id) => _db.transaction(() async {
    final now = _clock();
    final live = await _live().get();
    if (live.length <= 1) {
      throw StateError('At least one template must remain');
    }
    final target = live.firstWhere((t) => t.id == id);
    await (_db.update(
      _db.messageTemplates,
    )..where((t) => t.id.equals(id))).write(
      MessageTemplatesCompanion(
        isDefault: const Value(false),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    if (target.isDefault) {
      final next = live.firstWhere((t) => t.id != id);
      await (_db.update(
        _db.messageTemplates,
      )..where((t) => t.id.equals(next.id))).write(
        MessageTemplatesCompanion(
          isDefault: const Value(true),
          updatedAt: Value(now),
        ),
      );
    }
  });

  Future<void> _clearDefault(DateTime now) =>
      (_db.update(
        _db.messageTemplates,
      )..where((t) => t.isDefault.equals(true))).write(
        MessageTemplatesCompanion(
          isDefault: const Value(false),
          updatedAt: Value(now),
        ),
      );
}
