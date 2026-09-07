import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deep_list/app/app.dart';
import 'package:deep_list/app/providers.dart';
import 'package:deep_list/features/nodes/application/clipboard_controller.dart';
import 'package:deep_list/features/nodes/application/node_page_controller.dart';
import 'package:deep_list/features/nodes/application/tree_command_service.dart';

import '../helpers/memory_node_repository.dart';

void main() {
  late MemoryNodeRepository repository;
  late TreeCommandService commands;

  setUp(() {
    repository = MemoryNodeRepository();
    commands = TreeCommandService(repository);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await repository.close();
      await tester.pump();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nodeRepositoryProvider.overrideWithValue(repository),
          treeCommandServiceProvider.overrideWithValue(commands),
        ],
        child: const DeepListApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // A. 点击直接编辑
  testWidgets(
    'A. tap node once enters editing directly without selected state',
    (tester) async {
      final a = await commands.createNode(parentId: null, content: 'A');
      await pumpApp(tester);

      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      final controller = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      ).read(nodePageControllerProvider(null));

      expect(controller.mode, PageMode.editing);
      expect(controller.editingNodeId, a.id);
      expect(find.byType(TextField), findsOneWidget);
    },
  );

  // B. 编辑节点切换
  testWidgets(
    'B. editing node switch saves previous and edits target seamlessly',
    (tester) async {
      final a = await commands.createNode(parentId: null, content: 'A');
      final b = await commands.createNode(parentId: null, content: 'B');
      await pumpApp(tester);

      // Edit A
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      // Modify A
      await tester.enterText(find.byType(TextField), 'A Modified');
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      );
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.editing,
      );

      // Tap B directly
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();

      // B is now editing
      final pageState = container.read(nodePageControllerProvider(null));
      expect(pageState.mode, PageMode.editing);
      expect(pageState.editingNodeId, b.id);

      // A is saved in repository
      final nodeA = await repository.getNode(a.id);
      expect(nodeA!.content, 'A Modified');
    },
  );

  // C. 空节点切换
  testWidgets('C. empty editing node is deleted upon tapping another node', (
    tester,
  ) async {
    await commands.createNode(parentId: null, content: 'Target');
    await pumpApp(tester);

    // Create empty node via blank area
    await tester.tap(find.byKey(const ValueKey('blank-area')));
    await tester.pumpAndSettle();
    expect(await repository.getChildren(null), hasLength(2));

    // Tap Target
    await tester.tap(find.text('Target'));
    await tester.pumpAndSettle();

    final remaining = await repository.getChildren(null);
    expect(remaining, hasLength(1));
    expect(remaining.first.content, 'Target');

    final controller = ProviderScope.containerOf(
      tester.element(find.byType(DeepListApp)),
    ).read(nodePageControllerProvider(null));
    expect(controller.mode, PageMode.editing);
    expect(controller.editingNodeId, remaining.first.id);
  });

  // D. 点击空白无缝创建
  testWidgets(
    'D. tapping blank area during editing saves current and creates new node seamlessly',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Original');
      await pumpApp(tester);

      // Edit A
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Saved Content');
      await tester.pump();

      // Tap blank area
      await tester.tap(find.byKey(const ValueKey('blank-area')));
      await tester.pumpAndSettle();

      // Previous node is saved, new empty node is created and editing
      final children = await repository.getChildren(null);
      expect(children, hasLength(2));
      expect(children[0].content, 'Saved Content');
      expect(children[1].content, '');

      final controller = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      ).read(nodePageControllerProvider(null));
      expect(controller.mode, PageMode.editing);
      expect(controller.editingNodeId, children[1].id);
    },
  );

  // E. 长按菜单
  testWidgets(
    'E. long press node opens NodeActionMenu while mode stays normal',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Item');
      await pumpApp(tester);

      await tester.longPress(find.text('Item'));
      await tester.pumpAndSettle();

      // Menu options exist
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('粘贴'), findsOneWidget);
      expect(find.text('归档'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      final controller = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      ).read(nodePageControllerProvider(null));
      expect(controller.mode, PageMode.normal);
    },
  );

  // F. 编辑时长按
  testWidgets('F. long press during editing does not open NodeActionMenu', (
    tester,
  ) async {
    await commands.createNode(parentId: null, content: 'EditingNode');
    await pumpApp(tester);

    // Enter editing
    await tester.tap(find.text('EditingNode'));
    await tester.pumpAndSettle();

    // Long press text field
    await tester.longPress(find.byType(TextField));
    await tester.pumpAndSettle();

    // NodeActionMenu should not be open
    expect(find.text('归档'), findsNothing);
    expect(find.text('删除'), findsNothing);
  });

  // G. 拖动柄排序同级
  testWidgets(
    'G. reorder via drag handle reorders siblings and preserves parentId',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Item 1');
      await commands.createNode(parentId: null, content: 'Item 2');
      await commands.createNode(parentId: null, content: 'Item 3');
      await pumpApp(tester);

      // Find drag handles
      final handles = find.byIcon(Icons.drag_indicator);
      expect(handles, findsNWidgets(3));

      // Drag handle 0 down by 120dp
      await tester.drag(handles.at(0), const Offset(0, 120));
      await tester.pumpAndSettle();

      final siblings = await repository.getChildren(null);
      expect(siblings.map((n) => n.content).toList(), [
        'Item 2',
        'Item 1',
        'Item 3',
      ]);
      for (final s in siblings) {
        expect(s.parentId, isNull);
      }
    },
  );

  // H. 长按正文不再启动拖动
  testWidgets(
    'H. long press body opens NodeActionMenu without triggering reorder',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Alpha');
      await commands.createNode(parentId: null, content: 'Beta');
      await pumpApp(tester);

      await tester.longPress(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(find.text('删除'), findsOneWidget);

      // Order has not changed
      final siblings = await repository.getChildren(null);
      expect(siblings.map((n) => n.content).toList(), ['Alpha', 'Beta']);
    },
  );

  // I. 粘贴位置
  testWidgets('I. paste creates sibling directly below target node', (
    tester,
  ) async {
    await commands.createNode(parentId: null, content: 'A');
    final b = await commands.createNode(parentId: null, content: 'B');
    await commands.createNode(parentId: null, content: 'C');
    final x = await commands.createNode(parentId: null, content: 'X');
    await pumpApp(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeepListApp)),
    );
    // Copy X
    container.read(clipboardControllerProvider.notifier).copy(x.id);

    // Long press B -> Paste
    await tester.longPress(find.text('B'));
    await tester.pumpAndSettle();

    expect(find.text('粘贴'), findsOneWidget);
    await tester.tap(find.text('粘贴'));
    await tester.pumpAndSettle();

    final siblings = await repository.getChildren(null);
    expect(siblings.map((n) => n.content).toList(), ['A', 'B', 'X', 'C', 'X']);
    expect(siblings[2].content, 'X');
    expect(siblings[2].parentId, b.parentId);
  });

  // J. subtree copy
  testWidgets(
    'J. copySubtree copies entire descendant hierarchy with new IDs',
    (tester) async {
      final a = await commands.createNode(parentId: null, content: 'A');
      final a1 = await commands.createNode(parentId: a.id, content: 'A1');
      final a11 = await commands.createNode(parentId: a1.id, content: 'A11');

      final copiedRoot = await commands.copySubtree(
        sourceNodeId: a.id,
        targetParentId: null,
        targetPosition: 1,
      );

      expect(copiedRoot.id, isNot(a.id));
      expect(copiedRoot.content, 'A');
      expect(copiedRoot.parentId, isNull);

      final copiedAChildren = await repository.getChildren(copiedRoot.id);
      expect(copiedAChildren, hasLength(1));
      final copiedA1 = copiedAChildren.first;
      expect(copiedA1.id, isNot(a1.id));
      expect(copiedA1.content, 'A1');
      expect(copiedA1.parentId, copiedRoot.id);

      final copiedA1Children = await repository.getChildren(copiedA1.id);
      expect(copiedA1Children, hasLength(1));
      final copiedA11 = copiedA1Children.first;
      expect(copiedA11.id, isNot(a11.id));
      expect(copiedA11.content, 'A11');
      expect(copiedA11.parentId, copiedA1.id);
    },
  );

  // K. 归档
  testWidgets('K. long press archive hides node while parent remains', (
    tester,
  ) async {
    final b = await commands.createNode(parentId: null, content: 'ToArchive');
    await pumpApp(tester);

    await tester.longPress(find.text('ToArchive'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('归档'));
    await tester.pumpAndSettle();

    expect(find.text('ToArchive'), findsNothing);
    final nodeB = await repository.getNode(b.id);
    expect(nodeB!.isArchived, isTrue);
    expect(nodeB.parentId, isNull);
  });

  // L. 删除
  testWidgets('L. long press delete removes subtree completely', (
    tester,
  ) async {
    final b = await commands.createNode(parentId: null, content: 'ToDelete');
    await commands.createNode(parentId: b.id, content: 'ChildOfB');
    await pumpApp(tester);

    await tester.longPress(find.text('ToDelete'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('ToDelete'), findsNothing);
    expect(await repository.getNode(b.id), isNull);
    expect(await repository.getChildren(null), isEmpty);
  });

  // M. 返回键状态机简化: Editing -> Normal -> Pop
  testWidgets('M. back behavior transitions from Editing directly to Normal', (
    tester,
  ) async {
    await commands.createNode(parentId: null, content: 'Item');
    await pumpApp(tester);

    // Tap to edit
    await tester.tap(find.text('Item'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeepListApp)),
    );
    expect(
      container.read(nodePageControllerProvider(null)).mode,
      PageMode.editing,
    );

    // Trigger back via PopScope
    final dynamic popScope = tester.widget(find.byType(PopScope<void>));
    popScope.onPopInvokedWithResult(false, null);
    await tester.pumpAndSettle();

    // Transitions directly to Normal state, no Selected state
    expect(
      container.read(nodePageControllerProvider(null)).mode,
      PageMode.normal,
    );
  });

  // N. KeyboardToolbar ••• 打开操作菜单
  testWidgets('N. keyboard toolbar more button opens NodeActionMenu', (
    tester,
  ) async {
    await commands.createNode(parentId: null, content: 'Active');
    await pumpApp(tester);

    // Tap to edit
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('更多'), findsOneWidget);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    // NodeActionMenu opens
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('归档'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  // O. 左右滑动保持
  testWidgets('O. swipe right indents node', (tester) async {
    final first = await commands.createNode(parentId: null, content: 'First');
    final second = await commands.createNode(parentId: null, content: 'Second');
    await pumpApp(tester);

    // Swipe right on Second by 80dp
    await tester.drag(find.text('Second'), const Offset(80, 0));
    await tester.pumpAndSettle();

    final updated = await repository.getNode(second.id);
    expect(updated!.parentId, first.id);
  });
}
