import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../domain/node.dart';
import '../../domain/node_id.dart';
import '../models/two_level_tree.dart';
import '../models/visible_node_item.dart';

final twoLevelNodesProvider = Provider.autoDispose
    .family<AsyncValue<TwoLevelTree>, NodeId?>((ref, parentId) {
      final l1Async = ref.watch(childrenProvider(parentId));
      return l1Async.when(
        data: (l1Nodes) {
          final groups = <Level1DisplayGroup>[];
          for (var i = 0; i < l1Nodes.length; i++) {
            final l1 = l1Nodes[i];
            final parentItem = VisibleNodeItem(
              node: l1,
              level: 1,
              parentId: parentId,
              hasPreviousSibling: i > 0,
              previousSiblingId: i > 0 ? l1Nodes[i - 1].id : null,
              isLastInParent: i == l1Nodes.length - 1,
            );

            final l2Async = ref.watch(childrenProvider(l1.id));
            final l2Nodes = l2Async.value ?? const <Node>[];
            final childItems = <VisibleNodeItem>[];
            for (var j = 0; j < l2Nodes.length; j++) {
              final l2 = l2Nodes[j];
              childItems.add(
                VisibleNodeItem(
                  node: l2,
                  level: 2,
                  parentId: l1.id,
                  hasPreviousSibling: j > 0,
                  previousSiblingId: j > 0 ? l2Nodes[j - 1].id : null,
                  isLastInParent: j == l2Nodes.length - 1,
                ),
              );
            }
            groups.add(
              Level1DisplayGroup(parent: parentItem, children: childItems),
            );
          }
          return AsyncValue.data(TwoLevelTree(groups));
        },
        loading: () => const AsyncValue.loading(),
        error: (error, stack) => AsyncValue.error(error, stack),
      );
    });
