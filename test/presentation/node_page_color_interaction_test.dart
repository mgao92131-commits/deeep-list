import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deep_list/app/app.dart';
import 'package:deep_list/app/providers.dart';
import 'package:deep_list/features/nodes/application/tree_command_service.dart';
import 'package:deep_list/features/nodes/domain/node_color.dart';

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

  testWidgets(
    'Editing flow: color palette entry, focus retention, color update, enter auto-exits color mode',
    (tester) async {
      final node = await commands.createNode(parentId: null, content: 'Node 1');
      await pumpApp(tester);

      // 1. Tap node to edit
      await tester.tap(find.text('Node 1'));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.focusNode.hasFocus, isTrue);

      // 2. Keyboard toolbar has palette button
      expect(find.byTooltip('颜色'), findsOneWidget);

      // 3. Tap palette button
      await tester.tap(find.byTooltip('颜色'));
      await tester.pumpAndSettle();

      // Color mode is active
      expect(find.byTooltip('返回'), findsOneWidget);
      // TextField FocusNode must stay focused
      expect(editableText.focusNode.hasFocus, isTrue);

      // 4. Tap '蓝' (Blue)
      await tester.tap(find.byTooltip('蓝'));
      await tester.pumpAndSettle();

      // Focus must remain intact
      expect(editableText.focusNode.hasFocus, isTrue);

      // Database should have updated to blue
      final updatedNode = await repository.getNode(node.id);
      expect(updatedNode?.color, NodeColor.blue);

      // Toolbar remains in color mode for continuous comparison
      expect(find.byTooltip('返回'), findsOneWidget);

      // 5. Press Enter to create a new sibling node
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // A new empty node is created and focused
      final allNodes = await repository.getChildren(null);
      expect(allNodes.length, 2);
      final newNode = allNodes[1];
      expect(newNode.color, NodeColor.none); // does NOT inherit previous color

      // Toolbar automatically resets to normal mode!
      expect(find.byTooltip('颜色'), findsOneWidget);
      expect(find.byTooltip('返回'), findsNothing);
    },
  );

  testWidgets(
    'Long-press context menu does not contain background color entry',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Long Press Me');
      await pumpApp(tester);

      // Long press node
      await tester.longPress(find.text('Long Press Me'));
      await tester.pumpAndSettle();

      // Check '背景色' is NOT in the action menu
      expect(find.text('背景色'), findsNothing);
      // Menu still contains standard actions
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('归档'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    },
  );
}
