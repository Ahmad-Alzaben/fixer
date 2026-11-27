import 'dart:async';

import 'package:fixer/features/bill/application/repositories.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/messaging/application/template_repository.dart';
import 'package:fixer/features/messaging/domain/message_template.dart';

/// In-memory [BillRepository] for application and widget tests.
class FakeBillRepository implements BillRepository {
  final saved = <String, Bill>{};
  final deleted = <String>{};
  int saveCount = 0;
  final _changes = StreamController<void>.broadcast();

  List<Bill> get _visible =>
      saved.values.where((b) => !deleted.contains(b.id)).toList()
        ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

  @override
  Stream<List<Bill>> watchAll() async* {
    yield _visible;
    await for (final _ in _changes.stream) {
      yield _visible;
    }
  }

  @override
  Future<Bill?> getById(String id) async =>
      deleted.contains(id) ? null : saved[id];

  @override
  Future<void> save(Bill bill) async {
    saveCount++;
    saved[bill.id] = bill;
    deleted.remove(bill.id);
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    _changes.add(null);
  }

  @override
  Future<void> restore(String id) async {
    deleted.remove(id);
    _changes.add(null);
  }
}

class FakeTemplateRepository implements TemplateRepository {
  final templates = <MessageTemplate>[MessageTemplate.builtIn];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<MessageTemplate>> watchAll() async* {
    yield List.of(templates);
    await for (final _ in _changes.stream) {
      yield List.of(templates);
    }
  }

  void _clearDefault() {
    for (var i = 0; i < templates.length; i++) {
      final t = templates[i];
      templates[i] = MessageTemplate(id: t.id, name: t.name, body: t.body);
    }
  }

  @override
  Future<void> save(MessageTemplate template) async {
    final i = templates.indexWhere((t) => t.id == template.id);
    final wasDefault = i >= 0 && templates[i].isDefault;
    if (template.isDefault) _clearDefault();
    final stored = MessageTemplate(
      id: template.id,
      name: template.name,
      body: template.body,
      isDefault: template.isDefault || wasDefault,
    );
    i >= 0 ? templates[i] = stored : templates.add(stored);
    _changes.add(null);
  }

  @override
  Future<void> setDefault(String id) async {
    _clearDefault();
    final i = templates.indexWhere((t) => t.id == id);
    final t = templates[i];
    templates[i] = MessageTemplate(
      id: t.id,
      name: t.name,
      body: t.body,
      isDefault: true,
    );
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    if (templates.length <= 1) throw StateError('last template');
    final removed = templates.firstWhere((t) => t.id == id);
    templates.remove(removed);
    if (removed.isDefault) await setDefault(templates.first.id);
    _changes.add(null);
  }
}

class FakeTagRepository implements TagRepository {
  final tags = <Tag>[
    const Tag(id: 'tag-food', name: 'Food'),
    const Tag(id: 'tag-electronics', name: 'Electronics'),
  ];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Tag>> watchAll() async* {
    yield List.of(tags);
    await for (final _ in _changes.stream) {
      yield List.of(tags);
    }
  }

  @override
  Future<Tag> create(String name) async {
    final tag = Tag(id: 'tag-${name.toLowerCase()}', name: name.trim());
    tags.add(tag);
    _changes.add(null);
    return tag;
  }
}
