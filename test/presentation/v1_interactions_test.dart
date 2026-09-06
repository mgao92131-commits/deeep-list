import 'package:flutter/material.dart';
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
}
