import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/features/nodes/presentation/editor_session.dart';

class _MockRetryFocusNode extends FocusNode {
  int requestCount = 0;
  bool failFirst = true;

  @override
  void requestFocus([FocusNode? node]) {
    requestCount++;
    if (failFirst && requestCount == 1) {
      return;
    }
    super.requestFocus(node);
  }
}

void main() {
  testWidgets('Test A: focus pending only needs one post-frame', (
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

    expect(session.hasPendingFocus, isFalse);
    expect(session.isFocused('node'), isFalse);

    session.focus('node', cursor: 3);
    expect(session.hasPendingFocus, isTrue);
    expect(session.pendingFocusNodeId, 'node');

    // Exactly one pump (one post-frame)
    await tester.pump();

    expect(session.hasPendingFocus, isFalse);
    expect(session.activeNodeId, 'node');
    expect(focusNode.hasFocus, isTrue);
    expect(session.isFocused('node'), isTrue);
  });

  testWidgets(
    'Test B: focus retry succeeds on second frame and limits to 1 retry',
    (tester) async {
      final session = EditorSession();
      final focusNode = _MockRetryFocusNode();
      final controller = TextEditingController(text: 'retry-content');

      addTearDown(() {
        session.dispose();
        focusNode.dispose();
        controller.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(focusNode: focusNode, controller: controller),
          ),
        ),
      );

      session.register(
        nodeId: 'retry-node',
        focusNode: focusNode,
        controller: controller,
        commit: (_) async {},
      );

      session.focus('retry-node', cursor: 5);

      // Frame 1: first requestFocus is called, but failFirst prevents actual focus
      await tester.pump();
      expect(focusNode.requestCount, 1);
      expect(focusNode.hasFocus, isFalse);
      expect(session.isFocused('retry-node'), isFalse);

      // Frame 2: verification runs, sees hasFocus == false, retries requestFocus once
      await tester.pump();
      expect(focusNode.requestCount, 2);
      expect(focusNode.hasFocus, isTrue);
      expect(session.isFocused('retry-node'), isTrue);

      // Frame 3: no further retries (capped at 1 retry)
      await tester.pump();
      expect(focusNode.requestCount, 2);
    },
  );

  testWidgets(
    'Test B2: focus retry does not steal focus if handover intervened',
    (tester) async {
      final session = EditorSession();
      final focusNodeA = _MockRetryFocusNode();
      final controllerA = TextEditingController(text: 'NodeA');
      final focusNodeB = FocusNode();
      final controllerB = TextEditingController(text: 'NodeB');

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

      // Focus A; first request will fail
      session.focus('a');
      await tester.pump();
      expect(focusNodeA.requestCount, 1);
      expect(focusNodeA.hasFocus, isFalse);

      // Before frame 2 verification runs, handover focus to B
      session.handoverFocus('a', 'b');
      expect(session.activeNodeId, 'b');

      // Run next frame: verification for A must NOT retry because generation changed
      await tester.pump();
      expect(focusNodeA.requestCount, 1);
      expect(focusNodeB.hasFocus, isTrue);
      expect(session.activeNodeId, 'b');
    },
  );

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
    expect(session.hasPendingFocus, isTrue);
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

    expect(session.hasPendingFocus, isFalse);
    expect(focusNode.hasFocus, isTrue);
    expect(controller.selection.baseOffset, 2);
  });

  testWidgets(
    'Test C: handoverFocus transfers focus and cursor from A to B without session.unfocus',
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
      expect(session.isFocused('a'), isTrue);

      // Handover focus from A to B with cursor at 2
      session.handoverFocus('a', 'b', cursor: 2);
      expect(session.isHandingOver, isTrue);
      expect(session.handoverTarget, 'b');
      expect(session.handoverSource, 'a');

      await tester.pump();

      // A loses focus, B gains focus seamlessly, and handover finishes
      expect(focusNodeA.hasFocus, isFalse);
      expect(focusNodeB.hasFocus, isTrue);
      expect(session.activeNodeId, 'b');
      expect(session.isFocused('b'), isTrue);
      expect(session.hasPendingFocus, isFalse);
      expect(session.isHandingOver, isFalse);
      expect(session.handoverTarget, isNull);
      expect(controllerB.selection.baseOffset, 2);
    },
  );

  testWidgets(
    'Test D: unfocus or unregister clears handover state safely',
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

      session.register(
        nodeId: 'a',
        focusNode: focusNodeA,
        controller: controllerA,
        commit: (_) async {},
      );

      session.handoverFocus('a', 'b');
      expect(session.isHandingOver, isTrue);
      expect(session.handoverTarget, 'b');

      session.unfocus();
      expect(session.isHandingOver, isFalse);
      expect(session.handoverTarget, isNull);
    },
  );
}
