import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/core/database/app_database.dart';
import 'package:deep_list/features/nodes/application/tree_command_service.dart';
import 'package:deep_list/features/nodes/data/drift_node_repository.dart';

class _SchemaV3Opener extends QueryExecutorUser {
  @override
  int get schemaVersion => 3;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

void main() {
  group('Drift v3 -> v4 Schema Migration Test', () {
    test(
      'successfully upgrades from v3 to v4 and adds nullable dueDate',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'drift_migration_',
        );
        final dbFile = File('${tempDir.path}/test_v3_to_v4.db');

        try {
          // 1. Manually set up schema v3 in SQLite database file (without dueDate)
          final setupExecutor = NativeDatabase(dbFile);
          await setupExecutor.ensureOpen(_SchemaV3Opener());

          await setupExecutor.runCustom('''
          CREATE TABLE nodes (
            id TEXT NOT NULL PRIMARY KEY,
            parent_id TEXT,
            position INTEGER NOT NULL,
            content TEXT NOT NULL,
            note TEXT,
            is_done INTEGER NOT NULL DEFAULT 0,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            color TEXT NOT NULL DEFAULT 'none',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');

          // Set schema version to 3
          await setupExecutor.runCustom('PRAGMA user_version = 3;');

          // Insert pre-existing v3 node
          final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          await setupExecutor.runCustom('''
          INSERT INTO nodes (
            id, parent_id, position, content, is_done, is_favorite, is_archived,
            color, created_at, updated_at
          ) VALUES (
            'v3-node-1', NULL, 0, 'Pre-existing Node', 0, 1, 0,
            'none', $nowSeconds, $nowSeconds
          );
        ''');

          await setupExecutor.close();

          // 2. Open database with AppDatabase (schemaVersion = 4)
          final appDb = AppDatabase(executor: NativeDatabase(dbFile));

          // Verify schema version upgraded to 4
          expect(appDb.schemaVersion, 4);

          // Check PRAGMA user_version is now 4
          final versionResult = await appDb
              .customSelect('PRAGMA user_version;')
              .getSingle();
          expect(versionResult.read<int>('user_version'), 4);

          // 3. Verify the pre-existing node is still intact and has null dueDate
          final repo = DriftNodeRepository(appDb);
          final commands = TreeCommandService(repo);
          final existingNode = await repo.getNode('v3-node-1');
          expect(existingNode, isNotNull);
          expect(existingNode!.content, 'Pre-existing Node');
          expect(existingNode.isFavorite, isTrue);
          expect(existingNode.dueDate, isNull);

          // 4. Verify we can update and query dueDate
          final tomorrow = DateTime(2026, 9, 8);
          await commands.updateDueDate('v3-node-1', tomorrow);

          final updated = await repo.getNode('v3-node-1');
          expect(updated!.dueDate, isNotNull);
          expect(updated.dueDate!.year, 2026);
          expect(updated.dueDate!.month, 9);
          expect(updated.dueDate!.day, 8);

          final dueNodes = await repo.watchDueNodes().first;
          expect(dueNodes.map((n) => n.id), contains('v3-node-1'));

          await appDb.close();
        } finally {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        }
      },
    );
  });
}
