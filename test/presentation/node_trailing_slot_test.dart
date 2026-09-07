import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'trailing slot shows chevron for leaf and count only for parent',
    (tester) async {
      await commands.createNode(parentId: null, content: 'Leaf');
      final parent = await commands.createNode(
        parentId: null,
        content: 'Parent',
      );
      for (var i = 1; i <= 3; i++) {
        await commands.createNode(parentId: parent.id, content: 'Child $i');
      }

      await pumpApp(tester);

      final leafRow = find.ancestor(
        of: find.text('Leaf'),
        matching: find.byType(NodeRow),
      );
      final parentRow = find.ancestor(
        of: find.text('Parent'),
        matching: find.byType(NodeRow),
      );

      expect(
        find.descendant(
          of: leafRow,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: parentRow, matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: parentRow,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNothing,
      );

      await tester.tap(
        find.descendant(of: parentRow, matching: find.text('3')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsOneWidget);
    },
  );
}
