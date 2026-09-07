import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/features/nodes/application/tree_command_service.dart';
import 'package:deep_list/features/nodes/domain/node_color.dart';
import '../helpers/test_database.dart';

void main() {
  late TestDatabase db;

  setUp(() {
    db = TestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('TreeCommandService color operations', () {
    test('new nodes default to NodeColor.none', () async {
      final node = await db.commands.createNode(
        parentId: null,
        content: 'Task 1',
      );
      expect(node.color, NodeColor.none);
    });

    test('updateColor persists and updates timestamp', () async {
      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      final commands = TreeCommandService(
        db.repository,
        clock: () => currentTime,
      );

      final node = await commands.createNode(parentId: null, content: 'Item');
      expect(node.color, NodeColor.none);
      expect(node.updatedAt, DateTime(2026, 1, 1, 12, 0, 0));

      currentTime = DateTime(2026, 1, 1, 12, 0, 10);
      await commands.updateColor(node.id, NodeColor.yellow);
      final updated = await db.repository.getNode(node.id);
      expect(updated?.color, NodeColor.yellow);
      expect(updated?.updatedAt, DateTime(2026, 1, 1, 12, 0, 10));
    });

    test('parent color is NOT inherited by child (Section X)', () async {
      final parent = await db.commands.createNode(
        parentId: null,
        content: 'Parent Project',
      );
      await db.commands.updateColor(parent.id, NodeColor.blue);

      final child = await db.commands.createNode(
        parentId: parent.id,
        content: 'Child Task',
      );

      final fetchedParent = await db.repository.getNode(parent.id);
      final fetchedChild = await db.repository.getNode(child.id);

      expect(fetchedParent?.color, NodeColor.blue);
      expect(fetchedChild?.color, NodeColor.none);
    });

    test('sibling node does NOT inherit previous node color', () async {
      final sibling1 = await db.commands.createNode(
        parentId: null,
        content: 'Sibling 1',
      );
      await db.commands.updateColor(sibling1.id, NodeColor.green);

      final sibling2 = await db.commands.createNode(
        parentId: null,
        content: 'Sibling 2',
      );

      final fetched2 = await db.repository.getNode(sibling2.id);
      expect(fetched2?.color, NodeColor.none);
    });

    test('copySubtree preserves colors of copied subtree nodes', () async {
      final root = await db.commands.createNode(
        parentId: null,
        content: 'Root',
      );
      await db.commands.updateColor(root.id, NodeColor.red);

      final child = await db.commands.createNode(
        parentId: root.id,
        content: 'Child',
      );
      await db.commands.updateColor(child.id, NodeColor.purple);

      final copiedRoot = await db.commands.copySubtree(
        sourceNodeId: root.id,
        targetParentId: null,
        targetPosition: 1,
      );

      expect(copiedRoot.color, NodeColor.red);
      final copiedChildren = await db.repository.getChildren(copiedRoot.id);
      expect(copiedChildren.single.color, NodeColor.purple);
    });
  });
}
