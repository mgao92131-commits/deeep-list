import 'package:flutter_test/flutter_test.dart';
import 'package:deep_list/features/nodes/application/tree_command_service.dart';
import 'package:deep_list/features/nodes/application/smart_list_query.dart';
import 'package:deep_list/features/nodes/presentation/controllers/node_actions_controller.dart';
import 'package:deep_list/features/nodes/presentation/controllers/node_editing_coordinator.dart';
import 'package:deep_list/features/nodes/presentation/controllers/node_list_controller.dart';
import 'package:deep_list/features/nodes/presentation/models/visible_node_item.dart';
import '../helpers/memory_node_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final type in [null, ...SmartListType.values]) {
    test('完成/撤销策略无需 Widget: $type', () async {
      final repo = MemoryNodeRepository();
      final commands = TreeCommandService(repo);
      final node = await commands.createNode(parentId: null, content: 'Task');
      await commands.toggleFavorite(node.id);
      await commands.updateDueDate(node.id, DateTime(2026, 9, 8));
      final editor = NodeEditingCoordinator(
        treeCommandService: commands,
        onError: (error) => fail('$error'),
      );
      final actions = NodeActionsController(
        editor: editor,
        commands: commands,
        smartList: type,
        today: () => DateTime(2026, 9, 8),
        onError: (error) => fail('$error'),
        clipboard: () => null,
        copyToClipboard: (_) {},
        clearClipboard: () {},
      );
      editor.editing.startEditing(node.id);
      expect(
        await actions.toggleDone((await repo.getNode(node.id))!),
        type != null,
      );
      expect(editor.activeNodeId, type == null ? node.id : null);
      expect((await repo.getNode(node.id))!.isDone, isTrue);
      await actions.undoDone(node.id);
      expect((await repo.getNode(node.id))!.isDone, isFalse);
      editor.dispose();
      await repo.close();
    });
  }
  test('排序失败恢复显示顺序，归档视图禁止结构修改', () async {
    final repo = MemoryNodeRepository();
    final commands = TreeCommandService(repo);
    final a = await commands.createNode(parentId: null, content: 'A');
    final b = await commands.createNode(parentId: null, content: 'B');
    final errors = <Object>[];
    final editor = NodeEditingCoordinator(
      treeCommandService: commands,
      onError: errors.add,
    );
    var archived = false;
    final list = NodeListController(
      editor: editor,
      commands: commands,
      parentId: null,
      isArchived: () => archived,
      onError: errors.add,
    );
    final items = [
      VisibleNodeItem(node: a, parentId: null, hasPreviousSibling: false),
      VisibleNodeItem(node: b, parentId: null, hasPreviousSibling: true),
    ];
    repo.throwOnWrite = true;
    await list.reorder(null, [b.id, a.id]);
    expect(errors, hasLength(1));
    expect(list.displayItems(items).map((item) => item.id), [a.id, b.id]);
    errors.clear();
    archived = true;
    await list.createTrailingNode();
    await list.indent(b.id);
    await list.outdent(b.id);
    await list.reorder(null, [b.id, a.id]);
    expect(errors, isEmpty);
    expect(await repo.getChildren(null), hasLength(2));
    list.dispose();
    editor.dispose();
    await repo.close();
  });
}
