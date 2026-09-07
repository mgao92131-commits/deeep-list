import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/features/nodes/domain/node_color.dart';
import 'package:deep_list/features/nodes/presentation/widgets/keyboard_toolbar.dart';

void main() {
  group('KeyboardToolbar', () {
    testWidgets(
      'renders simplified normal toolbar with palette and done button at 44dp height',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KeyboardToolbar(
                activeNodeId: 'node-1',
                currentColor: NodeColor.none,
                isDone: false,
                onColorSelected: (_) {},
                onToggleDone: () {},
              ),
            ),
          ),
        );

        // Verify 44dp height
        expect(tester.getSize(find.byType(KeyboardToolbar)).height, 44.0);

        // Does NOT contain Indent / Outdent
        expect(find.byTooltip('Indent'), findsNothing);
        expect(find.byTooltip('Outdent'), findsNothing);
        expect(find.byIcon(Icons.format_indent_decrease), findsNothing);
        expect(find.byIcon(Icons.format_indent_increase), findsNothing);

        // Contains color palette entry
        expect(find.byTooltip('颜色'), findsOneWidget);
        expect(find.byIcon(Icons.palette_outlined), findsOneWidget);

        // Does NOT contain more button
        expect(find.byTooltip('更多'), findsNothing);
        expect(find.byIcon(Icons.more_horiz), findsNothing);

        // Contains done button
        expect(find.text('完成'), findsNothing);
        expect(find.byTooltip('完成'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      },
    );

    testWidgets(
      'clicking palette transitions to color selection toolbar at same 44dp height',
      (tester) async {
        NodeColor? selectedColor;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return KeyboardToolbar(
                    activeNodeId: 'node-1',
                    currentColor: selectedColor ?? NodeColor.none,
                    isDone: false,
                    onColorSelected: (color) {
                      setState(() {
                        selectedColor = color;
                      });
                    },
                    onToggleDone: () {},
                  );
                },
              ),
            ),
          ),
        );

        // Verify normal mode height
        expect(tester.getSize(find.byType(KeyboardToolbar)).height, 44.0);

        // Click palette button
        await tester.tap(find.byTooltip('颜色'));
        await tester.pumpAndSettle();

        // Height remains exactly 44dp in color mode
        expect(tester.getSize(find.byType(KeyboardToolbar)).height, 44.0);

        // Normal buttons are hidden
        expect(find.byTooltip('完成'), findsNothing);

        // Color toolbar elements are visible
        expect(find.byTooltip('返回'), findsOneWidget);
        for (final color in NodeColor.values) {
          expect(find.byTooltip(color.label), findsOneWidget);
        }

        // Tap yellow color
        await tester.tap(find.byTooltip('黄'));
        await tester.pumpAndSettle();

        expect(selectedColor, NodeColor.yellow);
        // Stays in color mode after picking
        expect(find.byTooltip('返回'), findsOneWidget);

        // Tap back button returns to normal toolbar
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();

        expect(find.byTooltip('颜色'), findsOneWidget);
        expect(find.byTooltip('完成'), findsOneWidget);
      },
    );

    testWidgets(
      'changing activeNodeId automatically exits color mode back to normal',
      (tester) async {
        var currentId = 'node-1';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentId = 'node-2';
                          });
                        },
                        child: const Text('Switch Node'),
                      ),
                      KeyboardToolbar(
                        activeNodeId: currentId,
                        currentColor: NodeColor.none,
                        isDone: false,
                        onColorSelected: (_) {},
                        onToggleDone: () {},
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        // Enter color mode
        await tester.tap(find.byTooltip('颜色'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('返回'), findsOneWidget);

        // Switch node
        await tester.tap(find.text('Switch Node'));
        await tester.pumpAndSettle();

        // Automatically reset to normal mode
        expect(find.byTooltip('颜色'), findsOneWidget);
        expect(find.byTooltip('返回'), findsNothing);
      },
    );
  });
}
