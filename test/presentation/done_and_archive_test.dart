import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/app/app.dart';
import 'package:deep_list/app/providers.dart';
import 'package:deep_list/features/nodes/application/node_page_controller.dart';
import 'package:deep_list/features/nodes/application/tree_command_service.dart';
import 'package:deep_list/features/nodes/presentation/widgets/keyboard_toolbar.dart';
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

  group('完成功能 (Done toggle)', () {
    testWidgets(
      'Keyboard toolbar has pure icon done button without text and maintains focus on toggle',
      (tester) async {
        final node = await commands.createNode(
          parentId: null,
          content: 'Task 1',
        );
        await pumpApp(tester);

        // Tap task to edit
        await tester.tap(find.text('Task 1'));
        await tester.pumpAndSettle();

        // Keyboard toolbar is displayed
        expect(find.byType(KeyboardToolbar), findsOneWidget);
        expect(tester.getSize(find.byType(KeyboardToolbar)).height, 44.0);

        // No text button '完成', only icon button
        expect(find.text('完成'), findsNothing);
        expect(find.byTooltip('完成'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

        // Tap done icon button
        await tester.tap(find.byTooltip('完成'));
        await tester.pumpAndSettle();

        // Node is now done in repository
        final updatedNode = await repository.getNode(node.id);
        expect(updatedNode!.isDone, isTrue);

        // TextField stays focused and editing session remains active
        final controller = ProviderScope.containerOf(
          tester.element(find.byType(DeepListApp)),
        ).read(nodePageControllerProvider(null));
        expect(controller.mode, PageMode.editing);
        expect(controller.editingNodeId, node.id);

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.focusNode!.hasFocus, isTrue);

        // Icon changes to check_circle and tooltip to 取消完成
        expect(find.byTooltip('取消完成'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);

        // Tap again to toggle back to undone
        await tester.tap(find.byTooltip('取消完成'));
        await tester.pumpAndSettle();

        final revertedNode = await repository.getNode(node.id);
        expect(revertedNode!.isDone, isFalse);
        expect(find.byTooltip('完成'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(field.focusNode!.hasFocus, isTrue);
      },
    );

    testWidgets('Done node displays strikethrough and muted color', (
      tester,
    ) async {
      final node = await commands.createNode(parentId: null, content: 'DoneTask');
      await pumpApp(tester);

      // Verify not struck through initially
      Text getTextWidget() => tester.widget<Text>(
        find.descendant(
          of: find.byType(NodeRow),
          matching: find.text('DoneTask'),
        ),
      );
      expect(
        getTextWidget().style?.decoration,
        isNot(TextDecoration.lineThrough),
      );

      // Toggle done
      await commands.toggleDone(node.id);
      await tester.pumpAndSettle();

      expect(getTextWidget().style?.decoration, TextDecoration.lineThrough);
    });
  });

  group('归档与归档视图切换 (Archive and View Switching)', () {
    testWidgets(
      'Archive menu entry is completely hidden when archivedCount is 0',
      (tester) async {
        await commands.createNode(parentId: null, content: 'Active 1');
        await pumpApp(tester);

        // When archivedCount == 0, PopupMenuButton does not appear
        expect(find.byIcon(Icons.more_vert), findsNothing);
        expect(find.text('查看已归档'), findsNothing);
      },
    );

    testWidgets(
      'Archiving a node immediately hides it and reveals 查看已归档 in ⋯ menu',
      (tester) async {
        final nodeA = await commands.createNode(
          parentId: null,
          content: 'Node A',
        );
        await commands.createNode(parentId: null, content: 'Node B');
        await pumpApp(tester);

        // Archive Node A via long press
        await tester.longPress(find.text('Node A'));
        await tester.pumpAndSettle();
        expect(find.text('归档'), findsOneWidget);
        await tester.tap(find.text('归档'));
        await tester.pumpAndSettle();

        // 1. Node A immediately disappears from active list
        expect(find.text('Node A'), findsNothing);
        expect(find.text('Node B'), findsOneWidget);

        // 2. ⋯ menu now appears
        expect(find.byIcon(Icons.more_vert), findsOneWidget);

        // 3. Open ⋯ menu: 查看已归档 is present
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('查看已归档'), findsOneWidget);

        // Node in repository is archived
        final archived = await repository.getNode(nodeA.id);
        expect(archived!.isArchived, isTrue);
      },
    );

    testWidgets(
      'Switching to archived view updates title and shows only archived nodes',
      (tester) async {
        await commands.createNode(parentId: null, content: 'Active Item');
        final archivedNode = await commands.createNode(
          parentId: null,
          content: 'Archived Item',
        );
        await commands.archiveNode(archivedNode.id);
        await pumpApp(tester);

        // Default active view
        expect(find.text('DeepList'), findsOneWidget);
        expect(find.text('Active Item'), findsOneWidget);
        expect(find.text('Archived Item'), findsNothing);

        // Open menu -> 查看已归档
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('查看已归档'));
        await tester.pumpAndSettle();

        // Title updated to indicate archived filter
        expect(find.text('DeepList · 已归档'), findsOneWidget);

        // List now displays archived item only
        expect(find.text('Archived Item'), findsOneWidget);
        expect(find.text('Active Item'), findsNothing);

        // Menu now shows 查看未归档
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('查看未归档'), findsOneWidget);

        // Tap 查看未归档 -> switches back
        await tester.tap(find.text('查看未归档'));
        await tester.pumpAndSettle();

        expect(find.text('DeepList'), findsOneWidget);
        expect(find.text('Active Item'), findsOneWidget);
        expect(find.text('Archived Item'), findsNothing);
      },
    );

    testWidgets(
      'Restoring node in archived view displays 恢复 and restores node',
      (tester) async {
        await commands.createNode(parentId: null, content: 'Active 1');
        final archived1 = await commands.createNode(
          parentId: null,
          content: 'Archived 1',
        );
        final archived2 = await commands.createNode(
          parentId: null,
          content: 'Archived 2',
        );
        await commands.archiveNode(archived1.id);
        await commands.archiveNode(archived2.id);
        await pumpApp(tester);

        // Switch to archived view
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('查看已归档'));
        await tester.pumpAndSettle();

        expect(find.text('Archived 1'), findsOneWidget);
        expect(find.text('Archived 2'), findsOneWidget);

        // Long press Archived 1: menu shows 恢复 instead of 归档
        await tester.longPress(find.text('Archived 1'));
        await tester.pumpAndSettle();
        expect(find.text('恢复'), findsOneWidget);
        expect(find.text('归档'), findsNothing);

        // Tap 恢复
        await tester.tap(find.text('恢复'));
        await tester.pumpAndSettle();

        // Archived 1 is gone from archived view, Archived 2 remains
        expect(find.text('Archived 1'), findsNothing);
        expect(find.text('Archived 2'), findsOneWidget);

        final restored = await repository.getNode(archived1.id);
        expect(restored!.isArchived, isFalse);
      },
    );

    testWidgets(
      'Restoring the last archived node automatically returns to active view',
      (tester) async {
        await commands.createNode(parentId: null, content: 'Active Node');
        final singleArchived = await commands.createNode(
          parentId: null,
          content: 'Sole Archived',
        );
        await commands.archiveNode(singleArchived.id);
        await pumpApp(tester);

        // Switch to archived view
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('查看已归档'));
        await tester.pumpAndSettle();

        expect(find.text('DeepList · 已归档'), findsOneWidget);
        expect(find.text('Sole Archived'), findsOneWidget);

        // Restore Sole Archived
        await tester.longPress(find.text('Sole Archived'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('恢复'));
        await tester.pumpAndSettle();

        // Must automatically return to active view
        expect(find.text('DeepList'), findsOneWidget);
        expect(find.text('DeepList · 已归档'), findsNothing);
        expect(find.text('Active Node'), findsOneWidget);
        expect(find.text('Sole Archived'), findsOneWidget);

        // ⋯ menu is completely gone because archivedCount is now 0
        expect(find.byIcon(Icons.more_vert), findsNothing);
      },
    );
  });

  group('已归档视图中的结构限制 (Structure restrictions in archived view)', () {
    testWidgets('Blank area tap does not create nodes in archived view', (
      tester,
    ) async {
      final archived = await commands.createNode(
        parentId: null,
        content: 'Archived Only',
      );
      await commands.archiveNode(archived.id);
      await pumpApp(tester);

      // Go to archived view
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看已归档'));
      await tester.pumpAndSettle();

      // Tap blank area
      await tester.tap(find.byKey(const ValueKey('blank-area')));
      await tester.pumpAndSettle();

      // No new TextField or node created
      expect(find.byType(TextField), findsNothing);
      final allNodes = await repository.getChildren(
        null,
        includeArchived: true,
      );
      expect(allNodes, hasLength(1));
    });

    testWidgets('Enter key does not create sibling in archived view', (
      tester,
    ) async {
      final archived = await commands.createNode(
        parentId: null,
        content: 'Archived Node',
      );
      await commands.archiveNode(archived.id);
      await pumpApp(tester);

      // Go to archived view
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看已归档'));
      await tester.pumpAndSettle();

      // Tap to edit text
      await tester.tap(find.text('Archived Node'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // Press Enter
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // No new sibling was created
      final allNodes = await repository.getChildren(
        null,
        includeArchived: true,
      );
      expect(allNodes, hasLength(1));
    });

    testWidgets('Swipe does not indent or outdent in archived view', (
      tester,
    ) async {
      final a = await commands.createNode(
        parentId: null,
        content: 'Archived A',
      );
      final b = await commands.createNode(
        parentId: null,
        content: 'Archived B',
      );
      await commands.archiveNode(a.id);
      await commands.archiveNode(b.id);
      await pumpApp(tester);

      // Go to archived view
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看已归档'));
      await tester.pumpAndSettle();

      // Try swiping right on Archived B to indent
      await tester.drag(find.text('Archived B'), const Offset(80, 0));
      await tester.pumpAndSettle();

      // ParentId remains null
      final nodeB = await repository.getNode(b.id);
      expect(nodeB!.parentId, isNull);
    });

    testWidgets(
      'Archiving parent does not archive child (no subtree archive)',
      (tester) async {
        final parent = await commands.createNode(
          parentId: null,
          content: 'ParentNode',
        );
        final child = await commands.createNode(
          parentId: parent.id,
          content: 'ChildNode',
        );

        await commands.archiveNode(parent.id);

        final parentInDb = await repository.getNode(parent.id);
        final childInDb = await repository.getNode(child.id);

        expect(parentInDb!.isArchived, isTrue);
        expect(childInDb!.isArchived, isFalse);
        expect(childInDb.parentId, parent.id);
      },
    );
  });
}
