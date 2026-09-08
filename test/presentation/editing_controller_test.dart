import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deep_list/features/nodes/presentation/controllers/editing_controller.dart';
import 'package:deep_list/features/nodes/presentation/editor_session.dart';

void main() {
  test('编辑、特殊交互、拖动和结束由同一状态源控制', () {
    final editing = EditingController();
    addTearDown(editing.dispose);
    editing.startEditing('a');
    editing.selectDueDate(true);
    expect(editing.value.editingNodeId, 'a');
    expect(editing.value.isSelectingDueDate, isTrue);
    editing.startEditing('b');
    expect(editing.value.editingNodeId, 'b');
    expect(editing.value.isSelectingDueDate, isFalse);
    editing.startDragging('a');
    expect(editing.value.editingNodeId, isNull);
    expect(editing.value.draggingNodeId, 'a');
    editing.endEditing();
    expect(editing.value.isNormal, isTrue);
    expect(editing.value.activeNodeId, isNull);
  });

  test('并发保存的完成和失败不会恢复已结束的编辑状态', () async {
    final editing = EditingController();
    addTearDown(editing.dispose);
    editing.startEditing('a');
    final first = Completer<void>();
    final second = Completer<void>();
    final saving1 = editing.saving(() => first.future);
    final saving2 = editing.saving(() => second.future);
    final failure = expectLater(saving2, throwsStateError);
    editing.endEditing();
    first.complete();
    await saving1;
    expect(editing.value.isSaving, isTrue);
    second.completeError(StateError('save failed'));
    await failure;
    expect(editing.value.isSaving, isFalse);
    expect(editing.value.editingNodeId, isNull);
  });

  testWidgets('焦点观察和过期请求不能覆盖编辑目标或重新开启已结束会话', (tester) async {
    final editing = EditingController();
    final session = EditorSession(editing: editing);
    final focus = FocusNode();
    final text = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(focusNode: focus, controller: text),
        ),
      ),
    );
    session.register(
      nodeId: 'a',
      focusNode: focus,
      controller: text,
      commit: (_) async {},
    );
    editing.startEditing('b');
    session.markActive('a');
    expect(editing.value.editingNodeId, 'b');
    session.focus('a');
    editing.endEditing();
    await tester.pump();
    expect(editing.value.editingNodeId, isNull);
    expect(focus.hasFocus, isFalse);
    session.dispose();
    editing.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    focus.dispose();
    text.dispose();
  });
}
