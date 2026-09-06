import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../domain/node_id.dart';
import '../models/visible_node_item.dart';

final visibleNodesProvider = Provider.autoDispose
    .family<AsyncValue<List<VisibleNodeItem>>, NodeId?>((ref, parentId) {
      final childrenAsync = ref.watch(childrenProvider(parentId));
      final countsAsync = ref.watch(childCountsProvider);
      final counts = countsAsync.value ?? const {};

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
                childCount: counts[node.id] ?? 0,
              ),
            );
          }
          return AsyncValue.data(items);
        },
        loading: () => const AsyncValue.loading(),
        error: (error, stack) => AsyncValue.error(error, stack),
      );
    });
