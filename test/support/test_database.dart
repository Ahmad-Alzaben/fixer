import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fixer/data/db/app_database.dart';
import 'package:sqlite3/open.dart';

var _configured = false;

/// In-memory database for tests. On Windows the host's built-in
/// `winsqlite3.dll` is used, so no extra download is needed.
AppDatabase openTestDatabase() {
  if (!_configured) {
    if (Platform.isWindows) {
      open.overrideFor(
        OperatingSystem.windows,
        () => DynamicLibrary.open('winsqlite3.dll'),
      );
    }
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    _configured = true;
  }
  return AppDatabase(NativeDatabase.memory());
}
