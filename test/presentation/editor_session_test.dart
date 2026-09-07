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

  testWidgets(
    'handoverFocus transfers focus and cursor from A to B without session.unfocus',
    (tester) async {
      final session = EditorSession();
      final focusNodeA = FocusNode();
      final controllerA = TextEditingController(text: 'Hello');
      final focusNodeB = FocusNode();
      final controllerB = TextEditingController(text: 'World');

      addTearDown(() {
        session.dispose();
        focusNodeA.dispose();
        controllerA.dispose();
        focusNodeB.dispose();
        controllerB.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: focusNodeA, controller: controllerA),
                TextField(focusNode: focusNodeB, controller: controllerB),
              ],
            ),
          ),
        ),
      );

      session.register(
        nodeId: 'a',
        focusNode: focusNodeA,
        controller: controllerA,
        commit: (_) async {},
      );
      session.register(
        nodeId: 'b',
        focusNode: focusNodeB,
        controller: controllerB,
        commit: (_) async {},
      );

      // Focus A initially
      session.focus('a', cursor: 5);
      await tester.pump();
      expect(focusNodeA.hasFocus, isTrue);
      expect(focusNodeB.hasFocus, isFalse);
      expect(session.activeNodeId, 'a');

      // Handover focus from A to B with cursor at 2
      session.handoverFocus('a', 'b', cursor: 2);
      await tester.pump();

      // A loses focus, B gains focus seamlessly
      expect(focusNodeA.hasFocus, isFalse);
      expect(focusNodeB.hasFocus, isTrue);
      expect(session.activeNodeId, 'b');
      expect(controllerB.selection.baseOffset, 2);
    },
  );
}
