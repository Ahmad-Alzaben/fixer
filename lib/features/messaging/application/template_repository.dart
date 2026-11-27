import 'package:fixer/features/messaging/domain/message_template.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saved message templates. Exactly one is the default at any time.
abstract interface class TemplateRepository {
  /// Non-deleted templates in display order.
  Stream<List<MessageTemplate>> watchAll();

  /// Inserts or updates. A template saved with `isDefault: true` becomes
  /// the only default.
  Future<void> save(MessageTemplate template);

  Future<void> setDefault(String id);

  /// Throws [StateError] for the last remaining template. Deleting the
  /// default makes the first remaining template the default.
  Future<void> delete(String id);
}

/// Overridden in `main()` with the Drift implementation.
final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => throw UnimplementedError('templateRepositoryProvider not set'),
);

final templatesProvider = StreamProvider<List<MessageTemplate>>(
  (ref) => ref.watch(templateRepositoryProvider).watchAll(),
);
