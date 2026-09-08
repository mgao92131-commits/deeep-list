import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../../../core/time/today_provider.dart';
import '../../domain/node.dart';
import '../../application/smart_list_query.dart';
export '../../application/smart_list_query.dart' show SmartListType;
import '../../domain/node_id.dart';
import '../models/visible_node_item.dart';

class SmartNodeGroup {
  final String? title;
  final List<VisibleNodeItem> items;
  final bool isOverdue;

  const SmartNodeGroup({
    this.title,
    required this.items,
    this.isOverdue = false,
  });
}

final favoritesNodesStreamProvider = StreamProvider.autoDispose<List<Node>>((
  ref,
) {
  return ref.watch(nodeRepositoryProvider).watchFavorites();
});

final dueNodesStreamProvider = StreamProvider.autoDispose<List<Node>>((ref) {
  return ref.watch(nodeRepositoryProvider).watchDueNodes();
});

final smartNodePathsProvider = StreamProvider.autoDispose
    .family<Map<NodeId, String>, SmartListType>((ref, type) {
      final groups =
          ref.watch(smartNodesProvider(type)).value ?? const <SmartNodeGroup>[];
      final ids = [
        for (final group in groups)
          for (final item in group.items) item.id,
      ];
      return ref
          .watch(nodeRepositoryProvider)
          .watchAncestorPaths(ids)
          .map(
            (paths) => {
              for (final entry in paths.entries)
                entry.key: _formatPath(entry.value),
            },
          );
    });

String _formatPath(List<Node> ancestors) {
  if (ancestors.isEmpty) return 'DeepList';
  final names = ancestors
      .map((node) => node.content.trim().isEmpty ? '未命名' : node.content.trim())
      .toList();
  if (names.length > 2) {
    return '… › ${names.sublist(names.length - 2).join(' › ')}';
  }
  return 'DeepList › ${names.join(' › ')}';
}

List<SmartNodeGroup> buildSmartGroups({
  required SmartListType type,
  required List<Node> nodes,
  required DateTime today,
  Map<NodeId, int> counts = const {},
}) {
  final filtered = nodes
      .where((node) => SmartListQuery.includes(type, node, today))
      .toList();
  List<VisibleNodeItem> items(List<Node> values) => [
    for (var i = 0; i < values.length; i++)
      VisibleNodeItem(
        node: values[i],
        parentId: values[i].parentId,
        hasPreviousSibling: type == SmartListType.favorites && i > 0,
        previousSiblingId: type == SmartListType.favorites && i > 0
            ? values[i - 1].id
            : null,
        isLastInParent:
            type == SmartListType.favorites && i == values.length - 1,
        childCount: counts[values[i].id] ?? 0,
      ),
  ];
  if (type == SmartListType.favorites) {
    return filtered.isEmpty ? [] : [SmartNodeGroup(items: items(filtered))];
  }
  const titles = {
    SmartDateGroup.overdue: '已逾期',
    SmartDateGroup.today: '今天',
    SmartDateGroup.tomorrow: '明天',
    SmartDateGroup.later: '以后',
  };
  final buckets = <SmartDateGroup, List<Node>>{};
  for (final node in filtered) {
    (buckets[SmartListQuery.dateGroup(node.dueDate!, today)] ??= []).add(node);
  }
  return [
    for (final group in SmartDateGroup.values)
      if (buckets[group]?.isNotEmpty ?? false)
        SmartNodeGroup(
          title: titles[group],
          items: items(buckets[group]!),
          isOverdue: group == SmartDateGroup.overdue,
        ),
  ];
}

final smartNodesProvider = Provider.autoDispose
    .family<AsyncValue<List<SmartNodeGroup>>, SmartListType>((ref, type) {
      final nodesAsync = switch (type) {
        SmartListType.favorites => ref.watch(favoritesNodesStreamProvider),
        SmartListType.today ||
        SmartListType.dueDates => ref.watch(dueNodesStreamProvider),
      };
      final counts = ref.watch(childCountsProvider).value ?? const {};
      final today = ref.watch(todayProvider);

      return nodesAsync.whenData((nodes) {
        return buildSmartGroups(
          type: type,
          nodes: nodes,
          today: today,
          counts: counts,
        );
      });
    });
