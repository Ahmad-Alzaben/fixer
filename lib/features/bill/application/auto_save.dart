import 'dart:async';

import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/bill/application/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long edits must pause before the bill is written to storage.
final autoSaveDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 400),
);

/// Saves the bill being edited to history automatically (debounced), once it
/// has at least one item. Watch this provider once at the app root.
final autoSaveProvider = Provider<void>((ref) {
  Timer? pending;
  ref.listen(billEditorProvider, (previous, next) {
    pending?.cancel();
    if (!next.hasItems) return;
    pending = Timer(ref.read(autoSaveDelayProvider), () {
      unawaited(
        ref.read(billRepositoryProvider).save(ref.read(billEditorProvider)),
      );
    });
  });
  ref.onDispose(() => pending?.cancel());
});
