import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current time source; overridden in tests for fixed dates.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
