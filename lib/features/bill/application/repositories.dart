import 'package:fixer/features/bill/domain/bill.dart';

/// Saved bills (history). Implementations decide where they live.
abstract interface class BillRepository {
  /// Non-deleted bills, newest first. Emits again whenever bills change.
  Stream<List<Bill>> watchAll();

  Future<Bill?> getById(String id);

  /// Inserts or replaces the whole bill (people, items, tags).
  Future<void> save(Bill bill);

  /// Soft delete; [restore] undoes it.
  Future<void> delete(String id);
  Future<void> restore(String id);
}

abstract interface class TagRepository {
  /// Non-deleted tags in display order.
  Stream<List<Tag>> watchAll();

  /// Adds a tag. Throws [ArgumentError] for a blank or duplicate name.
  Future<Tag> create(String name);
}
