import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/features/nodes/domain/tree_rules.dart';
import 'package:deep_list/features/nodes/domain/node.dart';

import '../helpers/test_database.dart';

void main() {
  late TestDatabase harness;

  setUp(() {
    harness = TestDatabase();
  });

  tearDown(() => harness.close());

  Future<Node> create(String content, {String? parentId, int? position}) {
    return harness.commands.createNode(
      parentId: parentId,
      content: content,
      position: position,
    );
  }

  test('creates top-level nodes and children without a root entity', () async {
    final topLevel = await create('A');
    final child = await create('A1', parentId: topLevel.id);

    expect(topLevel.parentId, isNull);
    expect(child.parentId, topLevel.id);
    expect(await harness.repository.getNode('root'), isNull);
    expect((await harness.repository.getChildren(null)).single.id, topLevel.id);
  });

  test('inserts at a position and normalizes sibling positions', () async {
    final a = await create('A');
    final b = await create('B');
    final inserted = await create('X', position: 1);

    final siblings = await harness.repository.getChildren(null);
    expect(siblings.map((node) => node.id), [a.id, inserted.id, b.id]);
    expect(siblings.map((node) => node.position), [0, 1, 2]);
  });

  test('rejects self-parent and keeps the node unchanged', () async {
    final node = await create('A');

    await expectLater(
      harness.commands.moveNode(
        nodeId: node.id,
        newParentId: node.id,
        newPosition: 0,
      ),
      throwsA(
        isA<TreeRuleViolation>().having(
          (error) => error.code,
          'code',
          TreeRuleCode.selfParent,
        ),
      ),
    );

    final unchanged = await harness.repository.getNode(node.id);
    expect(unchanged!.parentId, isNull);
    expect(unchanged.position, 0);
  });

  test('rejects moving a node below itself or a descendant', () async {
    final a = await create('A');
    final b = await create('B', parentId: a.id);
    final c = await create('C', parentId: b.id);

    for (final target in [a.id, b.id, c.id]) {
      await expectLater(
        harness.commands.moveNode(
          nodeId: a.id,
          newParentId: target,
          newPosition: 0,
        ),
        throwsA(isA<TreeRuleViolation>()),
      );
    }

    expect((await harness.repository.getNode(a.id))!.parentId, isNull);
    expect((await harness.repository.getNode(b.id))!.parentId, a.id);
    expect((await harness.repository.getNode(c.id))!.parentId, b.id);
  });

  test('allows moving to an unrelated parent and to the top level', () async {
    final a = await create('A');
    final b = await create('B');
    final c = await create('C', parentId: a.id);

    await harness.commands.moveNode(
      nodeId: c.id,
      newParentId: b.id,
      newPosition: 0,
    );
    expect((await harness.repository.getNode(c.id))!.parentId, b.id);

    await harness.commands.moveNode(
      nodeId: c.id,
      newParentId: null,
      newPosition: 0,
    );
    expect((await harness.repository.getNode(c.id))!.parentId, isNull);
  });

  test('missing target parent leaves the source position unchanged', () async {
    final a = await create('A');
    final b = await create('B');

    await expectLater(
      harness.commands.moveNode(
        nodeId: a.id,
        newParentId: 'missing-parent',
        newPosition: 0,
      ),
      throwsStateError,
    );

    final siblings = await harness.repository.getChildren(null);
    expect(siblings.map((node) => node.id), [a.id, b.id]);
    expect(siblings.map((node) => node.position), [0, 1]);
  });

  test('deletes a complete subtree and repairs the parent siblings', () async {
    final a = await create('A');
    final b = await create('B');
    final c = await create('C');
    final bChild = await create('B1', parentId: b.id);
    await create('B2', parentId: bChild.id);

    await harness.commands.deleteSubtree(b.id);

    expect(await harness.repository.getNode(b.id), isNull);
    expect(await harness.repository.getNode(bChild.id), isNull);
    expect(await harness.repository.getChildren(b.id), isEmpty);
    final remaining = await harness.repository.getChildren(null);
    expect(remaining.map((node) => node.id), [a.id, c.id]);
    expect(remaining.map((node) => node.position), [0, 1]);
  });

  test('reorder changes only positions and preserves parent IDs', () async {
    final a = await create('A');
    final b = await create('B');
    final child = await create('B1', parentId: b.id);

    await harness.commands.reorderChildren(
      parentId: null,
      orderedIds: [b.id, a.id],
    );

    final roots = await harness.repository.getChildren(null);
    expect(roots.map((node) => node.id), [b.id, a.id]);
    expect(roots.every((node) => node.parentId == null), isTrue);
    expect((await harness.repository.getNode(child.id))!.parentId, b.id);
  });

  test('archive and restore preserve the parent relationship', () async {
    final parent = await create('A');
    final child = await create('B', parentId: parent.id);

    await harness.commands.archiveNode(child.id);
    expect((await harness.repository.getNode(child.id))!.parentId, parent.id);
    expect((await harness.repository.getChildren(parent.id)), isEmpty);
    expect(
      (await harness.repository.getChildren(
        parent.id,
        includeArchived: true,
      )).single.id,
      child.id,
    );

    await harness.commands.restoreNode(child.id);
    expect(
      (await harness.repository.getChildren(parent.id)).single.id,
      child.id,
    );
    expect((await harness.repository.getNode(child.id))!.parentId, parent.id);
  });

  test(
    'split creates the next sibling and merge moves children safely',
    () async {
      final first = await create('HelloWorld');
      final second = await create('Second');
      final child = await create('Child', parentId: second.id);

      final split = await harness.commands.splitNode(
        nodeId: first.id,
        cursorPosition: 5,
        text: 'HelloWorld',
      );
      final splitNode = await harness.repository.getNode(split.newNodeId);
      expect((await harness.repository.getNode(first.id))!.content, 'Hello');
      expect(splitNode!.content, 'World');
      expect(splitNode.position, 1);

      final merged = await harness.commands.mergeWithPrevious(second.id);
      expect(merged!.targetNodeId, split.newNodeId);
      expect(
        (await harness.repository.getNode(split.newNodeId))!.content,
        'WorldSecond',
      );
      expect(
        (await harness.repository.getNode(child.id))!.parentId,
        split.newNodeId,
      );
      expect(await harness.repository.getNode(second.id), isNull);
    },
  );

  test('merge is a safe no-op for the first or only sibling', () async {
    final first = await create('First');
    expect(await harness.commands.mergeWithPrevious(first.id), isNull);

    final parent = await create('Parent');
    final only = await create('Only', parentId: parent.id);
    expect(await harness.commands.mergeWithPrevious(only.id), isNull);
    expect(await harness.repository.getNode(only.id), isNotNull);
  });

  test(
    'empty merge still transfers children and rejects archived editing',
    () async {
      final previous = await create('Previous');
      final current = await create('');
      final child = await create('Child', parentId: current.id);

      final result = await harness.commands.mergeWithPrevious(current.id);
      expect(result!.targetNodeId, previous.id);
      expect(
        (await harness.repository.getNode(previous.id))!.content,
        'Previous',
      );
      expect(
        (await harness.repository.getNode(child.id))!.parentId,
        previous.id,
      );

      final archived = await create('Archived');
      await harness.commands.archiveNode(archived.id);
      await expectLater(
        harness.commands.splitNode(
          nodeId: archived.id,
          cursorPosition: 0,
          text: 'Archived',
        ),
        throwsStateError,
      );
    },
  );

  test('indent and outdent reuse safe move semantics', () async {
    final a = await create('A');
    final b = await create('B');

    await harness.commands.indentNode(b.id);
    expect((await harness.repository.getNode(b.id))!.parentId, a.id);

    await harness.commands.outdentNode(b.id);
    final movedBack = await harness.repository.getNode(b.id);
    expect(movedBack!.parentId, isNull);
    expect(
      (await harness.repository.getChildren(null)).map((node) => node.id),
      [a.id, b.id],
    );
  });

  test('repository transactions roll back partial writes', () async {
    final node = await create('before');

    await expectLater(
      harness.repository.transaction((transaction) async {
        await transaction.saveNode(node.copyWith(content: 'partial write'));
        throw StateError('abort transaction');
      }),
      throwsStateError,
    );

    expect((await harness.repository.getNode(node.id))!.content, 'before');
  });
}
