import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Produces globally unique ids (UUID v4), so records can later sync to a
/// server without clashing. Overridden in tests for predictable ids.
final idGeneratorProvider = Provider<String Function()>(
  (ref) => const Uuid().v4,
);
