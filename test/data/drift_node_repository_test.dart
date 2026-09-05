import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/core/database/app_database.dart' as db;
import 'package:deep_list/features/nodes/domain/node.dart';

import '../helpers/test_database.dart';

void main() {
  late TestDatabase harness;

  setUp(() {
    harness = TestDatabase();
  });

  tearDown(() => harness.close());

  test('enables foreign keys and creates required indexes', () async {
    final foreignKeys = await harness.database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    final indexes = await harness.database
        .customSelect("PRAGMA index_list('nodes')")
        .get();
    final names = indexes.map((row) => row.data['name']).toSet();

    expect(foreignKeys.data['foreign_keys'], 1);
    expect(names, contains('nodes_parent_position'));
    expect(names, contains('nodes_parent_archive_position'));
  });

  test(
    'rejects dangling and self-referencing rows at the database boundary',
    () async {
      final now = DateTime.utc(2026, 1, 1);

      Future<void> insert({required String id, String? parentId}) {
        return harness.database
            .into(harness.database.nodes)
            .insert(
              db.NodesCompanion.insert(
                id: id,
                parentId: Value(parentId),
                position: 0,
                content: id,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      await expectLater(
        insert(id: 'child', parentId: 'missing'),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        insert(id: 'self', parentId: 'self'),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('watchChildren observes top-level and parent-scoped changes', () async {
    final topLevelStream = harness.repository.watchChildren(null);
    final firstTopLevel = await topLevelStream.first;
    expect(firstTopLevel, isEmpty);

    final parent = await harness.commands.createNode(
      parentId: null,
      content: 'parent',
    );
    final child = await harness.commands.createNode(
      parentId: parent.id,
      content: 'child',
    );

    expect(
      (await harness.repository.watchChildren(null).first).map((n) => n.id),
      [parent.id],
    );
    expect(
      (await harness.repository.watchChildren(parent.id).first).map(
        (n) => n.id,
      ),
      [child.id],
    );
  });

  test('archived rows are filtered without changing their parent', () async {
    final parent = await harness.commands.createNode(
      parentId: null,
      content: 'parent',
    );
    final child = await harness.commands.createNode(
      parentId: parent.id,
      content: 'child',
    );

    await harness.commands.archiveNode(child.id);

    expect(await harness.repository.getChildren(parent.id), isEmpty);
    final archived = await harness.repository.getChildren(
      parent.id,
      includeArchived: true,
    );
    expect(archived.single.parentId, parent.id);
    expect(archived.single.isArchived, isTrue);
  });

  test(
    'database trigger rejects a descendant cycle at the write boundary',
    () async {
      final a = await harness.commands.createNode(parentId: null, content: 'A');
      final b = await harness.commands.createNode(parentId: null, content: 'B');

      await (harness.database.update(harness.database.nodes)
            ..where((table) => table.id.equals(a.id)))
          .write(db.NodesCompanion(parentId: Value(b.id)));

      await expectLater(
        (harness.database.update(harness.database.nodes)
              ..where((table) => table.id.equals(b.id)))
            .write(db.NodesCompanion(parentId: Value(a.id))),
        throwsA(isA<Exception>()),
      );

      expect((await harness.repository.getNode(a.id))!.parentId, b.id);
      expect((await harness.repository.getNode(b.id))!.parentId, isNull);
    },
  );

  test('domain rows round-trip through Drift without a root row', () async {
    final node = await harness.commands.createNode(
      parentId: null,
      content: 'persisted',
    );
    final loaded = await harness.repository.getNode(node.id);

    expect(loaded, isA<Node>());
    expect(loaded!.id, node.id);
    expect(loaded.parentId, isNull);
    expect((await harness.repository.getChildren(null)).length, 1);
  });
}
