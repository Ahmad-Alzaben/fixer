import 'package:fixer/features/bill/application/repositories.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden in `main()` with the Drift implementations.
final billRepositoryProvider = Provider<BillRepository>(
  (ref) => throw UnimplementedError('billRepositoryProvider not set'),
);

final tagRepositoryProvider = Provider<TagRepository>(
  (ref) => throw UnimplementedError('tagRepositoryProvider not set'),
);

/// All saved bills, newest first.
final savedBillsProvider = StreamProvider<List<Bill>>(
  (ref) => ref.watch(billRepositoryProvider).watchAll(),
);

final tagsProvider = StreamProvider<List<Tag>>(
  (ref) => ref.watch(tagRepositoryProvider).watchAll(),
);
