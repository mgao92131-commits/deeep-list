import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/nodes_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Nodes])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor})
    : super(executor ?? driftDatabase(name: 'deep_list'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
      await _createTreeIntegrityTriggers();
    },
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await _createTreeIntegrityTriggers();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createTreeIntegrityTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS nodes_prevent_cycle_insert
      BEFORE INSERT ON nodes
      FOR EACH ROW
      WHEN NEW.parent_id IS NOT NULL
      BEGIN
        SELECT RAISE(ABORT, 'node cycle detected')
        WHERE EXISTS (
          WITH RECURSIVE ancestors(id, path) AS (
            SELECT NEW.parent_id, '|' || NEW.parent_id || '|'
            UNION ALL
            SELECT parent.parent_id,
                   ancestors.path || parent.parent_id || '|'
            FROM nodes AS parent
            JOIN ancestors ON parent.id = ancestors.id
            WHERE parent.parent_id IS NOT NULL
              AND instr(
                ancestors.path,
                '|' || parent.parent_id || '|'
              ) = 0
          )
          SELECT 1
          FROM ancestors
          WHERE ancestors.id = NEW.id
        );
      END;
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS nodes_prevent_cycle_update
      BEFORE UPDATE OF parent_id ON nodes
      FOR EACH ROW
      WHEN NEW.parent_id IS NOT NULL
      BEGIN
        SELECT RAISE(ABORT, 'node cycle detected')
        WHERE EXISTS (
          WITH RECURSIVE ancestors(id, path) AS (
            SELECT NEW.parent_id, '|' || NEW.parent_id || '|'
            UNION ALL
            SELECT parent.parent_id,
                   ancestors.path || parent.parent_id || '|'
            FROM nodes AS parent
            JOIN ancestors ON parent.id = ancestors.id
            WHERE parent.parent_id IS NOT NULL
              AND instr(
                ancestors.path,
                '|' || parent.parent_id || '|'
              ) = 0
          )
          SELECT 1
          FROM ancestors
          WHERE ancestors.id = NEW.id
        );
      END;
    ''');
  }
}
