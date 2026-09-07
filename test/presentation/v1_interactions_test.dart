import 'package:flutter/gestures.dart';
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

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
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

      // B is now editing and has actual focus
      final pageState = container.read(nodePageControllerProvider(null));
      expect(pageState.mode, PageMode.editing);
      expect(pageState.editingNodeId, b.id);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);

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

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
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

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
    },
  );

  // E. 长按菜单（长按不移动打开菜单，顺序不变）
  testWidgets(
    'E. long press node without moving opens NodeActionMenu while mode stays normal and order unchanged',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Item 1');
      await commands.createNode(parentId: null, content: 'Item 2');
      await pumpApp(tester);

      expect(find.byIcon(Icons.drag_indicator), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Item 1')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      // Menu options exist
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('粘贴'), findsOneWidget);
      expect(find.text('归档'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      expect(find.text('背景色'), findsNothing);

      final controller = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      ).read(nodePageControllerProvider(null));
      expect(controller.mode, PageMode.normal);

      // Order unchanged
      final siblings = await repository.getChildren(null);
      expect(siblings.map((n) => n.content).toList(), ['Item 1', 'Item 2']);
    },
  );

  // F. 编辑时长按 TextField 不触发菜单或 reorder
  testWidgets(
    'F. long press during editing does not open NodeActionMenu or trigger reorder',
    (tester) async {
      await commands.createNode(parentId: null, content: 'EditingNode');
      await commands.createNode(parentId: null, content: 'SecondNode');
      await pumpApp(tester);

      expect(find.byIcon(Icons.drag_indicator), findsNothing);

      // Enter editing
      await tester.tap(find.text('EditingNode'));
      await tester.pumpAndSettle();

      // Long press text field and move
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TextField)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // NodeActionMenu should not be open
      expect(find.text('归档'), findsNothing);
      expect(find.text('删除'), findsNothing);

      final siblings = await repository.getChildren(null);
      expect(siblings.map((n) => n.content).toList(), [
        'EditingNode',
        'SecondNode',
      ]);
    },
  );

  // G. 长按后明显移动执行同级 reorder，不打开菜单，且 parentId 保持不变
  testWidgets(
    'G. long press and move vertically reorders siblings without opening menu, and preserves parentId',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Item 1');
      await commands.createNode(parentId: null, content: 'Item 2');
      await commands.createNode(parentId: null, content: 'Item 3');
      await pumpApp(tester);

      // No drag handle exists
      expect(find.byIcon(Icons.drag_indicator), findsNothing);

      // Start gesture on Item 1, wait for kLongPressTimeout, then drag down
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Item 1')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      // Move down significantly (> 12dp, e.g. 120dp)
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Menu should NOT open
      expect(find.text('删除'), findsNothing);
      expect(find.text('复制'), findsNothing);

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

  // H1. 长按后移动约 4dp 仍打开菜单
  testWidgets(
    'H1. long press and slight move (~4dp) still opens menu upon release',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Item 1');
      await commands.createNode(parentId: null, content: 'Item 2');
      await pumpApp(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Item 1')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      // Move 4dp (< 12dp threshold)
      await gesture.moveBy(const Offset(0, 4));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('删除'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);

      final siblings = await repository.getChildren(null);
      expect(siblings.map((n) => n.content).toList(), ['Item 1', 'Item 2']);
    },
  );

  // H2. 普通上下拖动不 reorder，只滚动列表
  testWidgets('H2. normal vertical drag does not reorder, only scrolls list', (
    tester,
  ) async {
    for (var i = 1; i <= 20; i++) {
      await commands.createNode(parentId: null, content: 'ScrollItem $i');
    }
    await pumpApp(tester);

    expect(find.byIcon(Icons.drag_indicator), findsNothing);

    // Drag up without waiting for long press timeout
    await tester.drag(find.text('ScrollItem 1'), const Offset(0, -200));
    await tester.pumpAndSettle();

    // Menu should NOT be open
    expect(find.text('删除'), findsNothing);

    // Sibling order in repository remains strictly identical
    final siblings = await repository.getChildren(null);
    expect(siblings[0].content, 'ScrollItem 1');
    expect(siblings[1].content, 'ScrollItem 2');
    expect(siblings[2].content, 'ScrollItem 3');
  });

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

  // N. KeyboardToolbar 保留完成与颜色按钮，无更多/缩进入口
  testWidgets('N. keyboard toolbar has done and color buttons and does not contain more or indent buttons', (
    tester,
  ) async {
    await commands.createNode(parentId: null, content: 'Active');
    await pumpApp(tester);

    // Tap to edit
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('完成'), findsOneWidget);
    expect(find.byTooltip('颜色'), findsOneWidget);
    expect(find.byTooltip('更多'), findsNothing);
    expect(find.byTooltip('Indent'), findsNothing);
    expect(find.byTooltip('Outdent'), findsNothing);
  });

  // O. 左右滑动保持 (indent / outdent)
  testWidgets('O. swipe right indents node and swipe left outdents node', (
    tester,
  ) async {
    final first = await commands.createNode(parentId: null, content: 'First');
    final second = await commands.createNode(parentId: null, content: 'Second');
    await pumpApp(tester);

    // Swipe right on Second by 80dp to indent under first
    await tester.drag(find.text('Second'), const Offset(80, 0));
    await tester.pumpAndSettle();

    final updated = await repository.getNode(second.id);
    expect(updated!.parentId, first.id);

    // Enter subpage of First where Second is now located
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    // Swipe left on Second by -80dp to outdent back to root
    await tester.drag(find.text('Second'), const Offset(-80, 0));
    await tester.pumpAndSettle();

    final outdented = await repository.getNode(second.id);
    expect(outdented!.parentId, isNull);
  });

  // Case 1: Copy A -> Delete A -> Paste under B -> fails gracefully, clipboard cleared, snackbar
  testWidgets(
    'Case 1: Paste fails gracefully with notification if source was deleted',
    (tester) async {
      final a = await commands.createNode(parentId: null, content: 'A');
      final b = await commands.createNode(parentId: null, content: 'B');
      await pumpApp(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      );

      // Copy A
      await tester.longPress(find.text('A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();
      expect(container.read(clipboardControllerProvider), a.id);

      // Delete A from database
      await commands.deleteSubtree(a.id);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);

      // Long press B -> Paste
      await tester.longPress(find.text('B'));
      await tester.pumpAndSettle();
      expect(find.text('粘贴'), findsOneWidget);
      await tester.tap(find.text('粘贴'));
      await tester.pumpAndSettle();

      // Clipboard is cleared
      expect(container.read(clipboardControllerProvider), isNull);
      // Snackbar appeared
      expect(find.text('复制的节点已不存在'), findsOneWidget);
      // Only B remains, no new node created
      final siblings = await repository.getChildren(null);
      expect(siblings, hasLength(1));
      expect(siblings.single.id, b.id);
    },
  );

  // Case 4: Editing state -> type fresh text -> More -> Copy -> Paste copies latest text
  testWidgets(
    'Case 4: Copying actively editing node flushes pending changes immediately',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Initial Text');
      await commands.createNode(parentId: null, content: 'TargetNode');
      await pumpApp(tester);

      // Tap Initial Text to edit
      await tester.tap(find.text('Initial Text'));
      await tester.pumpAndSettle();

      // Type new text without waiting for 400ms autosave
      await tester.enterText(find.byType(TextField), 'Freshly Typed');
      await tester.pump();

      // Exit editing mode via PopScope (back)
      final dynamic popScope = tester.widget(find.byType(PopScope<void>));
      popScope.onPopInvokedWithResult(false, null);
      await tester.pumpAndSettle();

      // Long press the node to copy
      await tester.longPress(find.text('Freshly Typed'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();

      // Paste under TargetNode
      await tester.longPress(find.text('TargetNode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('粘贴'));
      await tester.pumpAndSettle();

      // The pasted node must contain the freshly typed content, not the initial text
      final siblings = await repository.getChildren(null);
      final pasted = siblings.last;
      expect(pasted.content, 'Freshly Typed');
    },
  );
}
