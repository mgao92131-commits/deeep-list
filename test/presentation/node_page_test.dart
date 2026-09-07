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

  testWidgets('tap directly enters editing mode without selected state', (
    tester,
  ) async {
    final node = await commands.createNode(parentId: null, content: 'TestNode');
    await pumpApp(tester);

    // 1st tap: edit directly
    await tester.tap(find.text('TestNode'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);

    final controller = ProviderScope.containerOf(
      tester.element(find.byType(DeepListApp)),
    ).read(nodePageControllerProvider(null));
    expect(controller.mode, PageMode.editing);
    expect(controller.editingNodeId, node.id);
  });

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

      // Tap once to edit
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

      // Tap once to edit
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

      // Tap once to edit
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

      // 1. Enter L1-Node (has 1 child -> tap count '1')
      await tester.tap(find.text('1').first);
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

      // 2. Enter L2-Node (has 1 child -> tap count '1')
      await tester.tap(find.text('1').first);
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

      // 4. Pop back to Root (page was in Normal state because direct navigation was used)
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

  testWidgets('long press node opens NodeActionMenu and allows deleting', (
    tester,
  ) async {
    await commands.createNode(parentId: null, content: 'ToDelete');
    await pumpApp(tester);

    // Long press to open menu
    await tester.longPress(find.text('ToDelete'));
    await tester.pumpAndSettle();

    // NodeActionMenu is shown with delete button
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
    'NodeRow trailing slot displays childCount when > 0 and chevron permanently across Normal, Editing, and Dragging; navigates directly',
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

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      );

      // Rule: childCount > 0 shows number, leaf nodes show chevron
      // Parent A has 2 unarchived children -> shows "2"
      expect(find.text('2'), findsOneWidget);
      // Parent B shows chevron_right
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Tap count '2' or chevron in Normal directly enters subpage!
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(find.text('Child A1'), findsOneWidget);
      expect(find.text('Child A2'), findsOneWidget);
      expect(find.text('Child A3'), findsNothing);

      // Back to root
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Tap chevron on Parent B directly enters empty subpage!
      await tester.tap(find.byIcon(Icons.chevron_right).last);
      await tester.pumpAndSettle();
      expect(find.text('Parent B'), findsWidgets);
      expect(find.text('点击空白处开始记录'), findsOneWidget);

      // Back to root
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Tap Parent B text once -> directly enters Editing mode
      await tester.tap(find.text('Parent B'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // In Editing mode, Parent B chevron remains visible
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Exit editing to normal
      container.read(nodePageControllerProvider(null).notifier).toNormal();
      await tester.pumpAndSettle();

      // Dragging mode -> trailing slot preserves child count and chevron
      container
          .read(nodePageControllerProvider(null).notifier)
          .startDragging(parentA.id);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    },
  );

  testWidgets(
    'NodeRow text right padding is permanently 48dp across Normal, Editing, and Dragging states',
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

  testWidgets('entering editing mode does not show primary card border', (
    tester,
  ) async {
    await commands.createNode(parentId: null, content: 'BorderCheck');
    await pumpApp(tester);

    await tester.tap(find.text('BorderCheck'));
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(TextField),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border, isNull);
  });

  testWidgets(
    'stale keyboard close metrics event does not kill new editing session during handover',
    (tester) async {
      final a = await commands.createNode(parentId: null, content: 'NodeA');
      final b = await commands.createNode(parentId: null, content: 'NodeB');
      await pumpApp(tester);

      // Start editing A
      await tester.tap(find.text('NodeA'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      );
      expect(
        container.read(nodePageControllerProvider(null)).editingNodeId,
        a.id,
      );

      // Simulate keyboard open
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pump();

      // Tap B to start editing B (focus generation increments)
      await tester.tap(find.text('NodeB'));
      await tester.pump();

      // Simulate stale old keyboard closing metrics: bottomInset reaches 0
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();

      // Verify B is still editing and focused, not killed by stale didChangeMetrics
      final pageState = container.read(nodePageControllerProvider(null));
      expect(pageState.mode, PageMode.editing);
      expect(pageState.editingNodeId, b.id);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
    },
  );

  testWidgets(
    'user blur and dismiss keyboard safely finishes editing session and saves',
    (tester) async {
      final a = await commands.createNode(parentId: null, content: 'Initial');
      await pumpApp(tester);

      // Edit A
      await tester.tap(find.text('Initial'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      );
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.editing,
      );

      // Edit text
      await tester.enterText(find.byType(TextField), 'Updated Content');
      await tester.pump();

      // Simulate keyboard open
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pump();

      // User unfocuses the TextField
      final field = tester.widget<TextField>(find.byType(TextField));
      field.focusNode!.unfocus();
      await tester.pump();

      // Soft keyboard dismissed (bottomInset becomes 0)
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      // Verify editing session finished and returned to normal
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.normal,
      );
      expect(
        container.read(nodePageControllerProvider(null)).editingNodeId,
        isNull,
      );

      // Verify content is saved
      final savedNode = await repository.getNode(a.id);
      expect(savedNode?.content, 'Updated Content');
    },
  );

  testWidgets('root node switch survives IME metrics jitter', (tester) async {
    final a = await commands.createNode(parentId: null, content: 'NodeA');
    final b = await commands.createNode(parentId: null, content: 'NodeB');
    await pumpApp(tester);

    // 4. 点击 A 进入编辑
    await tester.tap(find.text('NodeA'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeepListApp)),
    );
    expect(
      container.read(nodePageControllerProvider(null)).editingNodeId,
      a.id,
    );

    // 5. 模拟键盘：viewInsets.bottom = 300
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.pump();

    // 6. 修改 A 内容
    await tester.enterText(find.byType(TextField), 'NodeA Modified');
    await tester.pump();

    // 7. 点击 B (一次点击切换焦点)
    await tester.tap(find.text('NodeB'));

    // 8. 在焦点 handover 过程中模拟 IME metrics jitter:
    // bottomInset = 0 -> pump -> bottomInset = 300 -> pump
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    // 9. 最终断言：
    final pageState = container.read(nodePageControllerProvider(null));
    expect(pageState.mode, PageMode.editing);
    expect(pageState.editingNodeId, b.id);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
    expect(find.byType(TextField), findsOneWidget);

    final savedA = await repository.getNode(a.id);
    expect(savedA?.content, 'NodeA Modified');
  });

  testWidgets('child node switch survives IME metrics jitter', (tester) async {
    final parent = await commands.createNode(parentId: null, content: 'Parent');
    final a = await commands.createNode(parentId: parent.id, content: 'ChildA');
    final b = await commands.createNode(parentId: parent.id, content: 'ChildB');
    await pumpApp(tester);

    // 进入 Parent 页面
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeepListApp)),
    );
    expect(find.text('ChildA'), findsOneWidget);
    expect(find.text('ChildB'), findsOneWidget);

    // 点击 A 进入编辑
    await tester.tap(find.text('ChildA'));
    await tester.pumpAndSettle();

    expect(
      container.read(nodePageControllerProvider(parent.id)).editingNodeId,
      a.id,
    );

    // 模拟键盘：viewInsets.bottom = 300
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.pump();

    // 修改 A 内容
    await tester.enterText(find.byType(TextField), 'ChildA Modified');
    await tester.pump();

    // 点击 B
    await tester.tap(find.text('ChildB'));

    // 在焦点 handover 过程中模拟 IME metrics jitter:
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    // 最终断言：
    final pageState = container.read(nodePageControllerProvider(parent.id));
    expect(pageState.mode, PageMode.editing);
    expect(pageState.editingNodeId, b.id);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
    expect(find.byType(TextField), findsOneWidget);

    final savedA = await repository.getNode(a.id);
    expect(savedA?.content, 'ChildA Modified');
  });

  testWidgets(
    'user blur and dismiss keyboard discards empty node and finishes editing session',
    (tester) async {
      final a = await commands.createNode(parentId: null, content: 'Initial');
      await pumpApp(tester);

      // Edit A
      await tester.tap(find.text('Initial'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      );
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.editing,
      );

      // Clear text so node is empty
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      // Keyboard open
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pump();

      // User unfocuses the TextField
      final field = tester.widget<TextField>(find.byType(TextField));
      field.focusNode!.unfocus();
      await tester.pump();

      // Soft keyboard dismissed (bottomInset becomes 0)
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      // Verify editing session finished and returned to normal
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.normal,
      );
      expect(
        container.read(nodePageControllerProvider(null)).editingNodeId,
        isNull,
      );

      // Verify empty node was deleted
      final savedNode = await repository.getNode(a.id);
      expect(savedNode, isNull);
    },
  );

  testWidgets(
    'Non-empty node Enter: newly created empty node persists and maintains focus across keyboard jitter',
    (tester) async {
      final a = await commands.createNode(parentId: null, content: 'FirstNode');
      await pumpApp(tester);

      // Edit A
      await tester.tap(find.text('FirstNode'));
      await tester.pumpAndSettle();

      // Simulate keyboard open
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pump();

      // Press Enter to create new sibling node
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // Simulate keyboard metrics jitter during Enter handover
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeepListApp)),
      );
      final pageState = container.read(nodePageControllerProvider(null));
      expect(pageState.mode, PageMode.editing);
      expect(pageState.editingNodeId, isNotNull);
      expect(pageState.editingNodeId, isNot(a.id));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);

      // Wait out any enter timer protection and verify empty node still persists
      await tester.pumpAndSettle();
      expect(
        container.read(nodePageControllerProvider(null)).mode,
        PageMode.editing,
      );
    },
  );
}
