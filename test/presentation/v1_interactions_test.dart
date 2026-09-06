import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deep_list/app/app.dart';
import 'package:deep_list/app/providers.dart';
import 'package:deep_list/features/nodes/application/node_page_controller.dart';
import 'package:deep_list/features/nodes/application/tree_command_service.dart';
import 'package:deep_list/features/nodes/presentation/widgets/node_row.dart';

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

  testWidgets('tap another node transfers selection in one tap (Spec 9)', (
    tester,
  ) async {
    await commands.createNode(parentId: null, content: '工作');
    await commands.createNode(parentId: null, content: '生活');
    await pumpApp(tester);

    // 1st tap on 工作: selects 工作
    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();

    final controller = ProviderScope.containerOf(
      tester.element(find.byType(DeepListApp)),
    ).read(nodePageControllerProvider(null));
    expect(controller.mode, PageMode.selected);
    expect(find.text('工作'), findsOneWidget);

    // Single tap on 生活: transfers selection directly (Spec 9)
    await tester.tap(find.text('生活'));
    await tester.pumpAndSettle();

    final updatedController = ProviderScope.containerOf(
      tester.element(find.byType(DeepListApp)),
    ).read(nodePageControllerProvider(null));
    expect(updatedController.mode, PageMode.selected);
    expect(
      (await repository.getChildren(
        null,
      )).firstWhere((n) => n.content == '生活').id,
      updatedController.selectedNodeId,
    );
  });

  testWidgets(
    'tapping another node while editing empty node deletes it and selects target in one tap (Spec 15)',
    (tester) async {
      final target = await commands.createNode(parentId: null, content: '目标节点');
      await pumpApp(tester);

      // Tap trailing blank area to create empty node
      await tester.tap(find.byKey(const ValueKey('blank-area')));
      await tester.pumpAndSettle();
      expect(await repository.getChildren(null), hasLength(2));

      // Tap 目标节点
      await tester.tap(find.text('目标节点'));
      await tester.pumpAndSettle();

      // Empty node should be removed silently, 目标节点 is selected
      final remaining = await repository.getChildren(null);
      expect(remaining, hasLength(1));
      expect(remaining.single.id, target.id);

      final controller = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      ).read(nodePageControllerProvider(null));
      expect(controller.mode, PageMode.selected);
      expect(controller.selectedNodeId, target.id);
    },
  );

  testWidgets(
    'Keyboard toolbar appears during editing with Indent, Outdent and Done buttons (Spec 29)',
    (tester) async {
      final first = await commands.createNode(parentId: null, content: '工作');
      final second = await commands.createNode(parentId: null, content: '工作项');
      await pumpApp(tester);

      // Double tap 工作项 to enter editing
      await tester.tap(find.text('工作项'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('工作项'));
      await tester.pumpAndSettle();

      // Keyboard toolbar should be visible
      expect(find.byTooltip('Indent'), findsOneWidget);
      expect(find.byTooltip('Outdent'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);

      // 工作项 has a previous sibling, so Indent is enabled
      await tester.tap(find.byTooltip('Indent'));
      await tester.pumpAndSettle();

      // 工作项 should now be a child of 工作 (Level 2)
      final secondNode = await repository.getNode(second.id);
      expect(secondNode!.parentId, first.id);

      // Tapping 完成 finishes editing
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      final controller = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      ).read(nodePageControllerProvider(null));
      expect(controller.isNormal, isTrue);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    'Back behavior transitions through Editing -> Selected -> Normal (Spec 35)',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Item');
      await pumpApp(tester);

      // Double tap to edit
      await tester.tap(find.text('Item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Item'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      );
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.editing,
      );

      // Trigger back via ModalRoute / PopScope
      final dynamic popScope = tester.widget(find.byType(PopScope<void>));
      popScope.onPopInvokedWithResult(false, null);
      await tester.pumpAndSettle();

      // Should now be in Selected state
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.selected,
      );

      // Trigger back again
      popScope.onPopInvokedWithResult(false, null);
      await tester.pumpAndSettle();

      // Should now be in Normal state
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.normal,
      );
    },
  );

  testWidgets(
    'Horizontal swipe right triggers indent and resets to normal (Spec 20-27)',
    (tester) async {
      final first = await commands.createNode(
        parentId: null,
        content: 'ParentNode',
      );
      final second = await commands.createNode(
        parentId: null,
        content: 'ChildNode',
      );
      await pumpApp(tester);

      // Swipe right on ChildNode by 80dp (exceeds 55dp armed threshold)
      await tester.drag(find.text('ChildNode'), const Offset(80, 0));
      await tester.pumpAndSettle();

      // ChildNode should now be child of ParentNode
      final updatedSecond = await repository.getNode(second.id);
      expect(updatedSecond!.parentId, first.id);

      // Page should be in Normal state after swipe commit
      final controller = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      ).read(nodePageControllerProvider(null));
      expect(controller.isNormal, isTrue);
    },
  );

  testWidgets(
    'Selected + tap blank creates transient node and enters Editing in one tap (Issue 4)',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Existing');
      await pumpApp(tester);

      // Tap on Existing to select it
      await tester.tap(find.text('Existing'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      );
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.selected,
      );

      // Single tap on trailing blank area
      await tester.tap(find.byKey(const ValueKey('blank-area')));
      await tester.pumpAndSettle();

      // Should immediately create new node and enter Editing in 1 tap!
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.editing,
      );
      expect(find.byType(TextField), findsOneWidget);
    },
  );

  testWidgets(
    'Horizontal swipe left triggers outdent for Level 2 node and is no-op for Level 1 (Spec 23-24)',
    (tester) async {
      final l1 = await commands.createNode(parentId: null, content: 'L1');
      final l2 = await commands.createNode(parentId: l1.id, content: 'L2');
      await pumpApp(tester);

      // Swipe left on L2 by -80dp (exceeds -55dp armed threshold)
      await tester.drag(find.text('L2'), const Offset(-80, 0));
      await tester.pumpAndSettle();

      // L2 should now be elevated to top level (Level 1)
      final updatedL2 = await repository.getNode(l2.id);
      expect(updatedL2!.parentId, isNull);

      // Swipe left on L1 by -80dp -> no-op because L1 cannot outdent
      await tester.drag(find.text('L1'), const Offset(-80, 0));
      await tester.pumpAndSettle();

      final updatedL1 = await repository.getNode(l1.id);
      expect(updatedL1!.parentId, isNull);
    },
  );

  testWidgets('Focus blur on empty node deletes it completely (Issue 3)', (
    tester,
  ) async {
    await pumpApp(tester);

    // Tap blank area to create empty node
    await tester.tap(find.text('点击空白处开始记录'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(await repository.getChildren(null), hasLength(1));

    // Trigger blur by unfocusing
    final field = tester.widget<TextField>(find.byType(TextField));
    field.focusNode!.unfocus();
    await tester.pumpAndSettle();

    // Empty node must be deleted!
    expect(await repository.getChildren(null), isEmpty);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Non-empty node Backspace at cursor 0 does not merge (Issue 6)', (
    tester,
  ) async {
    final first = await commands.createNode(parentId: null, content: 'ABC');
    final second = await commands.createNode(parentId: null, content: 'DEF');
    await pumpApp(tester);

    // Double tap DEF to edit
    await tester.tap(find.text('DEF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEF'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    // Nodes must remain separate, NOT merged!
    expect((await repository.getNode(first.id))!.content, 'ABC');
    expect((await repository.getNode(second.id))!.content, 'DEF');
    expect(await repository.getChildren(null), hasLength(2));
  });

  Future<void> longPressDrag(
    WidgetTester tester,
    Finder startFinder,
    Finder endFinder,
  ) async {
    final start = tester.getCenter(startFinder);
    final end = tester.getCenter(endFinder);
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + kPressTimeout);
    await gesture.moveTo(end);
    await tester.pump(kPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('Level 1 downward drag reorder: A B C -> B A C', (tester) async {
    await commands.createNode(parentId: null, content: 'A');
    await commands.createNode(parentId: null, content: 'B');
    await commands.createNode(parentId: null, content: 'C');
    await pumpApp(tester);

    // Long press A and drag downward to C to place after B
    await longPressDrag(tester, find.text('A'), find.text('C'));

    final children = await repository.getChildren(null);
    expect(children.map((n) => n.content).toList(), ['B', 'A', 'C']);
  });

  testWidgets('Level 1 upward drag reorder: A B C -> A C B', (tester) async {
    await commands.createNode(parentId: null, content: 'A');
    await commands.createNode(parentId: null, content: 'B');
    await commands.createNode(parentId: null, content: 'C');
    await pumpApp(tester);

    // Long press C and drag upward to B to place between A and B
    await longPressDrag(tester, find.text('C'), find.text('B'));

    final children = await repository.getChildren(null);
    expect(children.map((n) => n.content).toList(), ['A', 'C', 'B']);
  });

  testWidgets(
    'Level 2 downward drag reorder within parent: A1 A2 A3 -> A2 A1 A3',
    (tester) async {
      final parent = await commands.createNode(
        parentId: null,
        content: 'Parent',
      );
      await commands.createNode(parentId: parent.id, content: 'A1');
      await commands.createNode(parentId: parent.id, content: 'A2');
      await commands.createNode(parentId: parent.id, content: 'A3');
      await pumpApp(tester);

      // Long press A1 and drag downward to A3 to place after A2
      await longPressDrag(tester, find.text('A1'), find.text('A3'));

      final children = await repository.getChildren(parent.id);
      expect(children.map((n) => n.content).toList(), ['A2', 'A1', 'A3']);
      // All children still have parent.id
      for (final child in children) {
        expect(child.parentId, parent.id);
      }
    },
  );

  testWidgets(
    'Level 2 upward drag reorder within parent: A1 A2 A3 -> A1 A3 A2',
    (tester) async {
      final parent = await commands.createNode(
        parentId: null,
        content: 'Parent',
      );
      await commands.createNode(parentId: parent.id, content: 'A1');
      await commands.createNode(parentId: parent.id, content: 'A2');
      await commands.createNode(parentId: parent.id, content: 'A3');
      await pumpApp(tester);

      // Long press A3 and drag upward to A2 to place between A1 and A2
      await longPressDrag(tester, find.text('A3'), find.text('A2'));

      final children = await repository.getChildren(parent.id);
      expect(children.map((n) => n.content).toList(), ['A1', 'A3', 'A2']);
      for (final child in children) {
        expect(child.parentId, parent.id);
      }
    },
  );

  testWidgets(
    'NodeRow width fills available list width for both short and long text (P0 Layout)',
    (tester) async {
      final shortNode = await commands.createNode(parentId: null, content: '短');
      final longNode = await commands.createNode(
        parentId: null,
        content: '这是一个非常长的一级节点文本用于验证组件绝对不会退化为根据文本内容自适应宽度导致被居中或卡片化',
      );
      await commands.createNode(parentId: shortNode.id, content: '二级节点');
      await pumpApp(tester);

      final screenWidth = tester.getSize(find.byType(DeepListApp)).width;

      // Find all NodeRows
      final nodeRowFinders = find.byType(NodeRow);
      expect(nodeRowFinders, findsNWidgets(3));

      // 1. Every NodeRow must span the entire screen width
      for (var i = 0; i < 3; i++) {
        final rowSize = tester.getSize(nodeRowFinders.at(i));
        expect(rowSize.width, screenWidth);
      }

      // 2. The AnimatedContainer inside each NodeRow spans screenWidth, and its inner content (Stack)
      // spans screenWidth - 16 (due to 8dp margin on each side)
      final animatedContainers = find.descendant(
        of: nodeRowFinders,
        matching: find.byType(AnimatedContainer),
      );
      for (var i = 0; i < 3; i++) {
        final containerSize = tester.getSize(animatedContainers.at(i));
        expect(containerSize.width, screenWidth);
        final stackFinder = find.descendant(
          of: animatedContainers.at(i),
          matching: find.byType(Stack),
        );
        expect(tester.getSize(stackFinder).width, screenWidth - 16.0);
        expect(tester.getTopLeft(stackFinder).dx, 8.0);
      }

      // 3. Text start x coordinates:
      // Level 1: 8dp margin + 12dp innerLeftPadding = 20.0
      // Level 2: 8dp margin + 36dp innerLeftPadding = 44.0
      final shortTextPos = tester.getTopLeft(find.text('短'));
      final longTextPos = tester.getTopLeft(find.text(longNode.content));
      final childTextPos = tester.getTopLeft(find.text('二级节点'));
      expect(shortTextPos.dx, 20.0);
      expect(longTextPos.dx, 20.0);
      expect(childTextPos.dx, 44.0);

      // 4. In Selected state:
      // Tap short node '短'
      await tester.tap(find.text('短'));
      await tester.pumpAndSettle();

      // The selected surface (Stack) still spans screenWidth - 16
      final selectedStack = find.descendant(
        of: nodeRowFinders.at(0),
        matching: find.byType(Stack),
      );
      expect(tester.getSize(selectedStack).width, screenWidth - 16.0);

      // The Chevron icon is anchored to the right edge of the screen:
      // Container right edge is at screenWidth - 8. Icon right edge is at screenWidth - 8 - 6 = screenWidth - 14.
      final chevronFinder = find.byIcon(Icons.chevron_right);
      expect(chevronFinder, findsOneWidget);
      final chevronTopRight = tester.getTopRight(chevronFinder);
      expect(chevronTopRight.dx, screenWidth - 14.0);
    },
  );

  testWidgets(
    'Light divider in Normal state follows level indent (20dp for L1, 44dp for L2) and hides in Selected',
    (tester) async {
      final l1 = await commands.createNode(parentId: null, content: '工作');
      await commands.createNode(parentId: l1.id, content: 'DeepList');
      await pumpApp(tester);

      // Normal state: 2 dividers for 2 nodes
      final dividers = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      expect(dividers, hasLength(2));

      // Level 1 divider starts at 20.0, Level 2 divider starts at 44.0
      expect(dividers[0].indent, 20.0);
      expect(dividers[0].endIndent, 0.0);
      expect(dividers[1].indent, 44.0);
      expect(dividers[1].endIndent, 0.0);

      // Tap L1 node to enter Selected state
      await tester.tap(find.text('工作'));
      await tester.pumpAndSettle();

      // Selected node hides its divider -> only 1 divider remaining (Level 2)
      final remainingDividers = tester
          .widgetList<Divider>(find.byType(Divider))
          .toList();
      expect(remainingDividers, hasLength(1));
      expect(remainingDividers[0].indent, 44.0);
    },
  );

  testWidgets('New empty node displays placeholder "输入内容…"', (tester) async {
    await pumpApp(tester);

    // Tap blank area to create transient empty node
    await tester.tap(find.text('点击空白处开始记录'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.decoration?.hintText, '输入内容…');
  });

  testWidgets(
    'Node with confirmed empty text is deleted on editing finish, whether newly created or cleared (Spec)',
    (tester) async {
      final formal = await commands.createNode(parentId: null, content: '正式节点');
      await pumpApp(tester);

      // 1st tap: select, 2nd tap: enter editing
      await tester.tap(find.text('正式节点'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('正式节点'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      // User clears the text of this existing node
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      // Tap outside on blank area to trigger finish editing
      await tester.tap(find.byKey(const ValueKey('blank-area')));
      await tester.pumpAndSettle();

      // Since the actual text was confirmed empty (trimmed), the node is deleted
      final children = await repository.getChildren(null);
      expect(children.map((n) => n.id), isNot(contains(formal.id)));
    },
  );

  testWidgets(
    'Node is NEVER deleted if activeText is null (Defensive anti-deletion)',
    (tester) async {
      final formal = await commands.createNode(parentId: null, content: '重要数据');
      await pumpApp(tester);

      // Select formal node
      await tester.tap(find.text('重要数据'));
      await tester.pumpAndSettle();

      // In selected mode, tap blank area (which calls _finishActiveEditing)
      // Since it is not in editing mode, activeText is null
      await tester.tap(find.byKey(const ValueKey('blank-area')));
      await tester.pumpAndSettle();

      // The formal node MUST remain intact!
      final children = await repository.getChildren(null);
      expect(children.map((n) => n.id), contains(formal.id));
      expect(children.map((n) => n.content), contains('重要数据'));
    },
  );

  testWidgets(
    'Keyboard dismissal immediately finishes editing and unfocuses node',
    (tester) async {
      await commands.createNode(parentId: null, content: '正在编辑');
      await pumpApp(tester);

      // Double tap to enter editing
      await tester.tap(find.text('正在编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('正在编辑'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      );
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.editing,
      );

      // Simulate keyboard opening (bottom inset becomes 300)
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      // Edit text
      await tester.enterText(find.byType(TextField), '已经修改');
      await tester.pump();

      // Simulate system keyboard dismissal (bottom inset drops to 0)
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      // Editing must be finished!
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.normal,
      );
      expect(find.byType(TextField), findsNothing);

      // Modified text must be persisted
      final nodes = await repository.getChildren(null);
      expect(nodes.first.content, '已经修改');
    },
  );

  testWidgets(
    'Keyboard dismissal on empty node finishes editing and deletes the empty node',
    (tester) async {
      await pumpApp(tester);

      // Tap blank area to create empty node and start editing
      await tester.tap(find.text('点击空白处开始记录'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      );
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.editing,
      );
      expect(await repository.getChildren(null), hasLength(1));

      // Simulate keyboard opening
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      // Simulate keyboard dismissal without typing anything
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      // Empty node must be cleaned up, and mode returns to normal!
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.normal,
      );
      expect(await repository.getChildren(null), isEmpty);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    'Node displays at 16sp font and allows full multiline text wrapping in normal and editing modes',
    (tester) async {
      await commands.createNode(
        parentId: null,
        content: '这是一段很长的文本，用来测试在普通态和编辑态下是否都会自动折行显示，而不会被截断为单行。',
      );
      await pumpApp(tester);

      // Verify normal display text: 16sp, no maxLines (multiline), no overflow ellipsis
      final textFinder = find.byType(Text);
      final textWidget = tester.widget<Text>(textFinder.first);
      expect(textWidget.style?.fontSize, 16);
      expect(textWidget.maxLines, isNull);
      expect(textWidget.overflow, isNull);

      // Enter editing mode (tap once to select, second tap to edit)
      await tester.tap(textFinder.first);
      await tester.pumpAndSettle();
      await tester.tap(textFinder.first);
      await tester.pumpAndSettle();

      // Verify editing mode TextField: 16sp, minLines 1, maxLines null (multiline)
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.fontSize, 16);
      expect(textField.minLines, 1);
      expect(textField.maxLines, isNull);
    },
  );
}
