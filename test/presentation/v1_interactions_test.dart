import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deep_list/app/app.dart';
import 'package:deep_list/app/providers.dart';
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
}
