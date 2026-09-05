import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/features/nodes/presentation/editor_session.dart';

void main() {
  testWidgets('focus request survives until a NodeCard registers', (
    tester,
  ) async {
    final session = EditorSession();
    final focusNode = FocusNode();
    final controller = TextEditingController(text: 'abc');

    addTearDown(() {
      session.dispose();
      focusNode.dispose();
      controller.dispose();
    });

    session.focus('node', cursor: 2);
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(focusNode: focusNode, controller: controller),
        ),
      ),
    );
    session.register(
      nodeId: 'node',
      focusNode: focusNode,
      controller: controller,
      commit: (_) async {},
    );
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    expect(controller.selection.baseOffset, 2);
  });
}
