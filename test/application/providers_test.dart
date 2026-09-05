import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deep_list/app/providers.dart';
import 'package:deep_list/features/nodes/application/node_page_controller.dart';

import '../helpers/test_database.dart';

void main() {
  late TestDatabase harness;
  late ProviderContainer container;

  setUp(() {
    harness = TestDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(harness.database)],
    );
  });

  tearDown(() async {
    container.dispose();
    await harness.close();
  });

  test(
    'childrenProvider(null) and childrenProvider(parent) stay scoped',
    () async {
      final rootSubscription = container.listen(
        childrenProvider(null),
        (_, _) {},
        fireImmediately: true,
      );
      final rootBefore = await container.read(childrenProvider(null).future);
      expect(rootBefore, isEmpty);

      final parent = await container
          .read(treeCommandServiceProvider)
          .createNode(parentId: null, content: 'parent');
      final child = await container
          .read(treeCommandServiceProvider)
          .createNode(parentId: parent.id, content: 'child');

      final childSubscription = container.listen(
        childrenProvider(parent.id),
        (_, _) {},
        fireImmediately: true,
      );
      final roots = await container.read(childrenProvider(null).future);
      final children = await container.read(childrenProvider(parent.id).future);
      expect(roots.map((node) => node.id), [parent.id]);
      expect(children.map((node) => node.id), [child.id]);
      rootSubscription.close();
      childSubscription.close();
    },
  );

  test('page controller state is isolated by parentId', () {
    final rootController = container.read(
      nodePageControllerProvider(null).notifier,
    );
    rootController.startEditing('root-node');

    expect(
      container.read(nodePageControllerProvider(null)).editingNodeId,
      'root-node',
    );
    expect(
      container.read(nodePageControllerProvider('parent-node')).editingNodeId,
      isNull,
    );

    rootController.endEditing();
    expect(
      container.read(nodePageControllerProvider(null)).editingNodeId,
      isNull,
    );
  });
}
