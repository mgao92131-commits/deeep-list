import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../domain/node.dart';
import '../../domain/node_id.dart';
import '../models/visible_node_item.dart';

enum ArchiveView { active, archived }

class ArchiveViewNotifier extends Notifier<ArchiveView> {
  final NodeId? parentId;
  ArchiveViewNotifier(this.parentId);

  @override
  ArchiveView build() => ArchiveView.active;

  void toggle() {
    state = state == ArchiveView.active
        ? ArchiveView.archived
        : ArchiveView.active;
  }

  void setView(ArchiveView view) {
    state = view;
  }
}

final archiveViewProvider = NotifierProvider.autoDispose
    .family<ArchiveViewNotifier, ArchiveView, NodeId?>(
      (arg) => ArchiveViewNotifier(arg),
    );

final allChildrenProvider = StreamProvider.autoDispose
    .family<List<Node>, NodeId?>((ref, parentId) {
      return ref
          .watch(nodeRepositoryProvider)
          .watchChildren(parentId, includeArchived: true);
    });

final archivedCountProvider = Provider.autoDispose.family<int, NodeId?>((
  ref,
  parentId,
) {
  final allNodes = ref.watch(allChildrenProvider(parentId)).value ?? const [];
  return allNodes.where((n) => n.isArchived).length;
});

final visibleNodesProvider = Provider.autoDispose
    .family<AsyncValue<List<VisibleNodeItem>>, NodeId?>((ref, parentId) {
      final allChildrenAsync = ref.watch(allChildrenProvider(parentId));
      final countsAsync = ref.watch(childCountsProvider);
      final counts = countsAsync.value ?? const {};
      final archiveView = ref.watch(archiveViewProvider(parentId));
      final isArchived = archiveView == ArchiveView.archived;

      return allChildrenAsync.when(
        data: (allNodes) {
          final nodes = allNodes
              .where((n) => n.isArchived == isArchived)
              .toList();
          final items = <VisibleNodeItem>[];
          for (var i = 0; i < nodes.length; i++) {
            final node = nodes[i];
            items.add(
              VisibleNodeItem(
                node: node,
                parentId: parentId,
                hasPreviousSibling: !isArchived && i > 0,
                previousSiblingId: !isArchived && i > 0
                    ? nodes[i - 1].id
                    : null,
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
