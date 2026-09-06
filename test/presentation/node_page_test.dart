import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deep_list/app/app.dart';
import 'package:deep_list/app/providers.dart';
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

  testWidgets(
    'new node is created by tapping trailing blank area and enters editing mode',
    (tester) async {
      await pumpApp(tester);

      // Spec 18: Tap trailing blank area to create transient empty node
      await tester.tap(find.text('点击空白处开始记录'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isFalse);
      expect(field.focusNode!.hasFocus, isTrue);
    },
  );

  testWidgets(
    'first tap selects node, second tap on text enters editing mode',
    (tester) async {
      await commands.createNode(parentId: null, content: 'TestNode');
      await pumpApp(tester);

      // 1st tap: select
      await tester.tap(find.text('TestNode'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(
        find.byTooltip('Open'),
        findsOneWidget,
      ); // Chevron visible in Selected state

      // 2nd tap: edit
      await tester.tap(find.text('TestNode'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.byTooltip('Open'),
        findsNothing,
      ); // Chevron hidden in Editing state
    },
  );

  testWidgets('Enter on non-empty node creates new sibling and focuses it', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('点击空白处开始记录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'HelloWorld');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final nodes = await repository.getChildren(null);
    expect(nodes.map((node) => node.content), ['HelloWorld', '']);
    expect(find.byType(TextField), findsOneWidget);
    final newField = tester.widget<TextField>(find.byType(TextField));
    expect(newField.focusNode!.hasFocus, isTrue);
    expect(newField.controller!.selection.baseOffset, 0);
  });

  testWidgets('Enter on empty node deletes the empty node', (tester) async {
    await commands.createNode(parentId: null, content: 'First');
    await pumpApp(tester);

    // Tap trailing blank area to create transient empty node
    await tester.tap(find.byKey(const ValueKey('blank-area')));
    await tester.pumpAndSettle();
    expect(await repository.getChildren(null), hasLength(2));

    // Press enter on empty node
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Empty node should be deleted
    final nodes = await repository.getChildren(null);
    expect(nodes.map((n) => n.content), ['First']);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'Enter on non-empty node preserves full text and creates empty node below (middle cursor)',
    (tester) async {
      await commands.createNode(parentId: null, content: 'HelloWorld');
      await pumpApp(tester);

      // Double tap to edit
      await tester.tap(find.text('HelloWorld'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HelloWorld'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.selection = const TextSelection.collapsed(offset: 5);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect((await repository.getChildren(null)).map((node) => node.content), [
        'HelloWorld',
        '',
      ]);
      final newField = tester.widget<TextField>(find.byType(TextField));
      expect(newField.focusNode!.hasFocus, isTrue);
      expect(newField.controller!.selection.baseOffset, 0);
    },
  );

  testWidgets(
    'Enter on non-empty node preserves full text and creates empty node below (start cursor)',
    (tester) async {
      await commands.createNode(parentId: null, content: 'HelloWorld');
      await pumpApp(tester);

      // Double tap to edit
      await tester.tap(find.text('HelloWorld'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HelloWorld'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.selection = const TextSelection.collapsed(offset: 0);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect((await repository.getChildren(null)).map((node) => node.content), [
        'HelloWorld',
        '',
      ]);
      final newField = tester.widget<TextField>(find.byType(TextField));
      expect(newField.focusNode!.hasFocus, isTrue);
      expect(newField.controller!.selection.baseOffset, 0);
    },
  );

  testWidgets(
    'Enter on non-empty node preserves full text and creates empty node below (end cursor)',
    (tester) async {
      await commands.createNode(parentId: null, content: 'HelloWorld');
      await pumpApp(tester);

      // Double tap to edit
      await tester.tap(find.text('HelloWorld'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HelloWorld'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.selection = const TextSelection.collapsed(offset: 10);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect((await repository.getChildren(null)).map((node) => node.content), [
        'HelloWorld',
        '',
      ]);
      final newField = tester.widget<TextField>(find.byType(TextField));
      expect(newField.focusNode!.hasFocus, isTrue);
      expect(newField.controller!.selection.baseOffset, 0);
    },
  );

  testWidgets('Backspace on empty node deletes it and focuses previous node', (
    tester,
  ) async {
    final first = await commands.createNode(parentId: null, content: 'First');
    await pumpApp(tester);

    // Create empty trailing node
    await tester.tap(find.byKey(const ValueKey('blank-area')));
    await tester.pumpAndSettle();
    expect(await repository.getChildren(null), hasLength(2));

    // Press backspace on empty node
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    // Empty node deleted, previous node focused
    expect(await repository.getChildren(null), hasLength(1));
    expect((await repository.getChildren(null)).single.id, first.id);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('debounced autosave persists text before navigation', (
    tester,
  ) async {
    final node = await commands.createNode(parentId: null, content: 'Before');
    await pumpApp(tester);

    await tester.tap(find.text('Before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Before'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Autosaved');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect((await repository.getNode(node.id))!.content, 'Autosaved');
  });

  testWidgets('lifecycle pause flushes the active editor', (tester) async {
    final node = await commands.createNode(parentId: null, content: 'Before');
    await pumpApp(tester);

    await tester.tap(find.text('Before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Before'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Flushed');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect((await repository.getNode(node.id))!.content, 'Flushed');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets(
    'navigating away commits and removes focus, and pop does not restore it',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Parent');
      await pumpApp(tester);

      await tester.tap(find.text('Parent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parent'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      final oldFocusNode = tester
          .widget<TextField>(find.byType(TextField))
          .focusNode!;
      expect(oldFocusNode.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField), 'Edited Parent');

      // Tap outside to commit and select
      await tester.tap(find.byKey(const ValueKey('blank-area')));
      await tester.pumpAndSettle();

      // Now selected, Chevron is visible
      await tester.tap(find.text('Edited Parent'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edited Parent'), findsOneWidget);
      expect(
        (await repository.getChildren(null)).single.content,
        'Edited Parent',
      );
      expect(oldFocusNode.hasFocus, isFalse);
      expect(find.byType(TextField), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(oldFocusNode.hasFocus, isFalse);
    },
  );

  testWidgets(
    'displays only direct children for current parent and reveals descendants upon navigation',
    (tester) async {
      Finder rowText(String text) =>
          find.descendant(of: find.byType(NodeRow), matching: find.text(text));

      final l1 = await commands.createNode(parentId: null, content: 'L1-Node');
      final l2 = await commands.createNode(parentId: l1.id, content: 'L2-Node');
      await commands.createNode(parentId: l2.id, content: 'L3-Node');
      await pumpApp(tester);

      // Root page: only direct root children are displayed in the list
      expect(rowText('L1-Node'), findsOneWidget);
      expect(rowText('L2-Node'), findsNothing);
      expect(rowText('L3-Node'), findsNothing);

      // 1. Enter L1-Node
      await tester.tap(rowText('L1-Node'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      // Inside L1 page: only direct children (L2) are displayed in the list
      expect(rowText('L1-Node'), findsNothing);
      expect(rowText('L2-Node'), findsOneWidget);
      expect(rowText('L3-Node'), findsNothing);
      // AppBar title reflects current parent
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('L1-Node'),
        ),
        findsOneWidget,
      );

      // 2. Enter L2-Node
      await tester.tap(rowText('L2-Node'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      // Inside L2 page: only direct children (L3) are displayed in the list
      expect(rowText('L2-Node'), findsNothing);
      expect(rowText('L3-Node'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('L2-Node'),
        ),
        findsOneWidget,
      );

      // 3. Pop back to L1
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(rowText('L2-Node'), findsOneWidget);
      expect(rowText('L3-Node'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('L1-Node'),
        ),
        findsOneWidget,
      );

      // 4. Pop back to Root
      // On L1 page, L2 was selected so first back transitions Selected -> Normal (Spec 35)
      await tester.pageBack();
      await tester.pumpAndSettle();
      // Second back pops to Root
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(rowText('L1-Node'), findsOneWidget);
      expect(rowText('L2-Node'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('DeepList'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Selected Bottom Toolbar allows deleting selected node', (
    tester,
  ) async {
    await commands.createNode(parentId: null, content: 'ToDelete');
    await pumpApp(tester);

    // Tap to select
    await tester.tap(find.text('ToDelete'));
    await tester.pumpAndSettle();

    // Selection toolbar is shown with delete button
    expect(find.text('删除'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('ToDelete'), findsNothing);
    expect(await repository.getChildren(null), isEmpty);
  });

  testWidgets(
    'optimistic reorder retains target order immediately upon drop even when DB write is delayed',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Item A');
      await commands.createNode(parentId: null, content: 'Item B');
      await commands.createNode(parentId: null, content: 'Item C');
      await pumpApp(tester);

      // Verify initial order: Item A, Item B, Item C
      var textWidgets = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(NodeRow),
              matching: find.byType(Text),
            ),
          )
          .where(
            (t) =>
                t.data == 'Item A' || t.data == 'Item B' || t.data == 'Item C',
          )
          .toList();
      expect(textWidgets.map((t) => t.data).toList(), [
        'Item A',
        'Item B',
        'Item C',
      ]);

      // Inject 200ms transaction delay into repository to simulate slow DB persistence
      repository.transactionDelay = const Duration(milliseconds: 200);

      // Trigger reorder of Item A (index 0) to after Item B (index 1), then finish dragging
      final reorderable = tester.widget<SliverReorderableList>(
        find.byType(SliverReorderableList),
      );
      reorderable.onReorderItem?.call(0, 1);
      reorderable.onReorderEnd?.call(1);

      // Rebuild one frame while DB write is still pending in 200ms delay
      await tester.pump();

      // At this point, the DB transaction has NOT finished yet,
      // but UI must show optimistic order (Item B, Item A, Item C), NOT flashing back!
      textWidgets = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(NodeRow),
              matching: find.byType(Text),
            ),
          )
          .where(
            (t) =>
                t.data == 'Item A' || t.data == 'Item B' || t.data == 'Item C',
          )
          .toList();
      expect(textWidgets.map((t) => t.data).toList(), [
        'Item B',
        'Item A',
        'Item C',
      ]);

      // Now advance time past the 200ms DB delay and let persistence finish
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Order is confirmed by DB and optimistic state is smoothly released.
      // The final order must strictly remain Item B, Item A, Item C!
      textWidgets = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(NodeRow),
              matching: find.byType(Text),
            ),
          )
          .where(
            (t) =>
                t.data == 'Item A' || t.data == 'Item B' || t.data == 'Item C',
          )
          .toList();
      expect(textWidgets.map((t) => t.data).toList(), [
        'Item B',
        'Item A',
        'Item C',
      ]);
    },
  );

  testWidgets(
    'NodeRow trailing slot displays childCount when > 0, blanks when 0, and switches to chevron in selected state',
    (tester) async {
      final parentA = await commands.createNode(
        parentId: null,
        content: 'Parent A',
      );
      await commands.createNode(parentId: null, content: 'Parent B');
      // Create 3 children under Parent A (2 active, 1 archived)
      await commands.createNode(parentId: parentA.id, content: 'Child A1');
      await commands.createNode(parentId: parentA.id, content: 'Child A2');
      final archivedChild = await commands.createNode(
        parentId: parentA.id,
        content: 'Child A3',
      );
      await commands.archiveNode(archivedChild.id);

      await pumpApp(tester);

      // Normal state:
      // Parent A has 2 unarchived children -> shows "2"
      expect(find.text('2'), findsOneWidget);

      // Parent B has 0 children -> no count text (find.text('0') does not exist)
      expect(find.text('0'), findsNothing);

      // Tap on count '2' area of Parent A -> taps whole node into Selected mode (warnIfMissed: false because IgnorePointer intentionally passes through)
      await tester.tap(find.text('2'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Now Parent A is in Selected state:
      // The count '2' is replaced by Chevron (›)
      expect(find.text('2'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Tap the Chevron -> navigates to /node/Parent A
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      // DeepList page header displays Parent A's title
      expect(find.text('Parent A'), findsWidgets);
      // In Parent A's page, unarchived children are visible
      expect(find.text('Child A1'), findsOneWidget);
      expect(find.text('Child A2'), findsOneWidget);
      expect(find.text('Child A3'), findsNothing);
    },
  );

  testWidgets(
    'NodeRow text right padding is permanently 48dp across Normal, Selected, and Editing states',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Stable Width Node');
      await pumpApp(tester);

      EdgeInsets getTextPadding() {
        final paddingWidget = tester.widget<Padding>(
          find
              .ancestor(
                of: find.text('Stable Width Node'),
                matching: find.byType(Padding),
              )
              .first,
        );
        return paddingWidget.padding as EdgeInsets;
      }

      // Normal state: right padding is 48.0
      expect(getTextPadding().right, 48.0);

      // Tap to enter Selected state
      await tester.tap(find.text('Stable Width Node'));
      await tester.pumpAndSettle();
      expect(getTextPadding().right, 48.0);

      // Tap again to enter Editing state
      await tester.tap(find.text('Stable Width Node'));
      await tester.pumpAndSettle();
      final editingPaddingWidget = tester.widget<Padding>(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect((editingPaddingWidget.padding as EdgeInsets).right, 48.0);
    },
  );
}
