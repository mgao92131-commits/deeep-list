import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/nodes_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Nodes])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor})
    : super(executor ?? driftDatabase(name: 'deep_list'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
