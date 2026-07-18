import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

/// Drift database for ride recording.
///
/// Stores [Rides] and [Samples] in a local SQLite file with WAL mode for crash
/// safety.
@DriftDatabase(tables: [Rides, Samples])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'wattson.db'));
      return NativeDatabase(file);
    });
  }
}
