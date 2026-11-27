import 'package:drift/native.dart';
import 'package:fixer/data/db/app_database.dart';
import 'package:fixer/data/repositories/drift_template_repository.dart';
import 'package:fixer/features/messaging/domain/message_template.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftTemplateRepository repo;
  final now = DateTime(2026, 11, 28);

  setUp(() {
    db = openTestDatabase();
    repo = DriftTemplateRepository(db, clock: () => now);
  });

  tearDown(() => db.close());

  Future<List<MessageTemplate>> all() => repo.watchAll().first;

  test('a new database starts with the built-in default template', () async {
    final list = await all();
    expect(list.single.id, MessageTemplate.builtIn.id);
    expect(list.single.body, MessageTemplate.builtIn.body);
    expect(list.single.isDefault, isTrue);
  });

  test('saves new templates and edits existing ones in place', () async {
    await repo.save(
      const MessageTemplate(id: 't1', name: 'Formal', body: 'Dear {name}'),
    );
    await repo.save(
      const MessageTemplate(
        id: 't1',
        name: 'Formal',
        body: 'Dear {name}, {amount}',
      ),
    );
    final list = await all();
    expect(list.map((t) => t.id), ['builtin', 't1']);
    expect(list.last.body, 'Dear {name}, {amount}');
    expect(list.last.isDefault, isFalse);
  });

  test('setDefault leaves exactly one default', () async {
    await repo.save(const MessageTemplate(id: 't1', name: 'A', body: 'a'));
    await repo.setDefault('t1');
    final list = await all();
    expect(
      [
        for (final t in list)
          if (t.isDefault) t.id,
      ],
      ['t1'],
    );
  });

  test('saving a template marked default unmarks the old one', () async {
    await repo.save(
      const MessageTemplate(id: 't1', name: 'A', body: 'a', isDefault: true),
    );
    expect(
      [
        for (final t in await all())
          if (t.isDefault) t.id,
      ],
      ['t1'],
    );
  });

  test(
    'deleting the default passes the role to the first remaining one',
    () async {
      await repo.save(const MessageTemplate(id: 't1', name: 'A', body: 'a'));
      await repo.save(const MessageTemplate(id: 't2', name: 'B', body: 'b'));
      await repo.setDefault('t2');
      await repo.delete('t2');
      final list = await all();
      expect(list.map((t) => t.id), ['builtin', 't1']);
      expect(
        [
          for (final t in list)
            if (t.isDefault) t.id,
        ],
        ['builtin'],
      );

      // Kept as a tombstone for future sync.
      final row = await (db.select(
        db.messageTemplates,
      )..where((t) => t.id.equals('t2'))).getSingle();
      expect(row.deletedAt, now);
    },
  );

  test('the last template cannot be deleted', () async {
    expect(() => repo.delete('builtin'), throwsStateError);
  });

  test(
    'upgrading a version-1 database adds templates with the default',
    () async {
      // A database created by the previous app version (schema 1).
      final old = AppDatabase(
        NativeDatabase.memory(setup: (raw) => raw.userVersion = 1),
      );
      addTearDown(old.close);
      final list = await DriftTemplateRepository(old).watchAll().first;
      expect(list.single.id, 'builtin');
      expect(list.single.isDefault, isTrue);
    },
  );
}
