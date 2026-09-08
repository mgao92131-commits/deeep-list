import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deep_list/core/database/app_database.dart';
import 'package:deep_list/features/nodes/data/drift_node_repository.dart';
import 'package:deep_list/features/nodes/application/tree_command_service.dart';

void main() {
  test('100 个五层节点路径只执行一次查询，祖先重命名和移动自动刷新', () async {
    final logs = <String>[];
    await runZoned(
      () async {
        final db = AppDatabase(
          executor: NativeDatabase.memory(logStatements: true),
        );
        final repo = DriftNodeRepository(db);
        final commands = TreeCommandService(repo);
        final ancestors = <String>[];
        String? parent;
        for (var i = 0; i < 5; i++) {
          parent = (await commands.createNode(
            parentId: parent,
            content: 'Level $i',
          )).id;
          ancestors.add(parent);
        }
        final ids = <String>[];
        for (var i = 0; i < 100; i++) {
          ids.add(
            (await commands.createNode(
              parentId: parent,
              content: 'Task $i',
            )).id,
          );
        }
        logs.clear();
        final stream = StreamIterator(
          repo.watchAncestorPaths([...ids, ancestors.first, 'missing']),
        );
        expect(await stream.moveNext(), isTrue);
        expect(
          logs.where((line) => line.contains('WITH RECURSIVE ancestor_paths')),
          hasLength(1),
        );
        for (final id in ids) {
          expect(stream.current[id]!.map((node) => node.id), ancestors);
        }
        expect(stream.current[ancestors.first], isEmpty);
        expect(stream.current['missing'], isEmpty);
        await commands.updateContent(ancestors.last, 'Renamed');
        do {
          expect(await stream.moveNext(), isTrue);
        } while (stream.current[ids.first]!.last.content != 'Renamed');
        await commands.moveNode(
          nodeId: ids.first,
          newParentId: null,
          newPosition: 0,
        );
        do {
          expect(await stream.moveNext(), isTrue);
        } while (stream.current[ids.first]!.isNotEmpty);
        expect(stream.current[ids.last], hasLength(5));
        await stream.cancel();
        await db.close();
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => logs.add(line),
      ),
    );
  });
}
