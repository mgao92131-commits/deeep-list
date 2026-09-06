import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../domain/node_id.dart';
import '../models/visible_node_item.dart';

final visibleNodesProvider = Provider.autoDispose
    .family<AsyncValue<List<VisibleNodeItem>>, NodeId?>((ref, parentId) {
      final childrenAsync = ref.watch(childrenProvider(parentId));
      return childrenAsync.when(
        data: (nodes) {
          final items = <VisibleNodeItem>[];
          for (var i = 0; i < nodes.length; i++) {
            final node = nodes[i];
            items.add(
              VisibleNodeItem(
                node: node,
                parentId: parentId,
                hasPreviousSibling: i > 0,
                previousSiblingId: i > 0 ? nodes[i - 1].id : null,
                isLastInParent: i == nodes.length - 1,
              ),
            );
          }
          return AsyncValue.data(items);
        },
        loading: () => const AsyncValue.loading(),
        error: (error, stack) => AsyncValue.error(error, stack),
      );
    });

final twoLevelNodesProvider = visibleNodesProvider;
