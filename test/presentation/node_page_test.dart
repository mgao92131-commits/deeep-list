import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deep_list/app/app.dart';
import 'package:deep_list/app/providers.dart';
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

  testWidgets('new node enters edit mode with explicit focus', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add node'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isFalse);
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets(
    'Enter splits content and focuses the new sibling at its cursor',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Add node'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'HelloWorld');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      final nodes = await repository.getChildren(null);
      expect(nodes.map((node) => node.content), ['HelloWorld', '']);
      expect(find.byType(TextField), findsOneWidget);
      final newField = tester.widget<TextField>(find.byType(TextField));
      expect(newField.focusNode!.hasFocus, isTrue);
      expect(newField.controller!.selection.baseOffset, 0);
    },
  );

  testWidgets('Enter splits a middle cursor without losing the suffix', (
    tester,
  ) async {
    await commands.createNode(parentId: null, content: 'HelloWorld');
    await pumpApp(tester);

    await tester.tap(find.text('HelloWorld'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection = const TextSelection.collapsed(offset: 5);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect((await repository.getChildren(null)).map((node) => node.content), [
      'Hello',
      'World',
    ]);
    final newField = tester.widget<TextField>(find.byType(TextField));
    expect(newField.focusNode!.hasFocus, isTrue);
    expect(newField.controller!.selection.baseOffset, 0);
  });

  testWidgets('Backspace at the start merges and focuses the previous node', (
    tester,
  ) async {
    final first = await commands.createNode(parentId: null, content: 'ABC');
    await commands.createNode(parentId: null, content: 'DEF');
    await pumpApp(tester);

    await tester.tap(find.text('DEF'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect((await repository.getNode(first.id))!.content, 'ABCDEF');
    expect(await repository.getChildren(null), hasLength(1));
    final mergedField = tester.widget<TextField>(find.byType(TextField));
    expect(mergedField.focusNode!.hasFocus, isTrue);
    expect(mergedField.controller!.selection.baseOffset, 3);
  });

  testWidgets('first node backspace at start is a focused no-op', (
    tester,
  ) async {
    final node = await commands.createNode(parentId: null, content: 'ABC');
    await pumpApp(tester);

    await tester.tap(find.text('ABC'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect((await repository.getNode(node.id))!.content, 'ABC');
    expect(await repository.getChildren(null), hasLength(1));
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
  });

  testWidgets('mobile merge affordance handles backspace at the start', (
    tester,
  ) async {
    final first = await commands.createNode(parentId: null, content: 'ABC');
    await commands.createNode(parentId: null, content: 'DEF');
    await pumpApp(tester);

    await tester.tap(find.text('DEF'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();

    expect(find.byTooltip('Merge with previous'), findsOneWidget);
    await tester.tap(find.byTooltip('Merge with previous'));
    await tester.pumpAndSettle();

    expect((await repository.getNode(first.id))!.content, 'ABCDEF');
    expect(await repository.getChildren(null), hasLength(1));
  });

  testWidgets('debounced autosave persists text before navigation', (
    tester,
  ) async {
    final node = await commands.createNode(parentId: null, content: 'Before');
    await pumpApp(tester);

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
      expect(find.byType(TextField), findsOneWidget);
      final oldFocusNode = tester
          .widget<TextField>(find.byType(TextField))
          .focusNode!;
      expect(oldFocusNode.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField), 'Edited Parent');

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
}
