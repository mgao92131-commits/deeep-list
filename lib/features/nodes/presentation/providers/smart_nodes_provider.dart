import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../domain/node.dart';
import '../../domain/node_id.dart';
import '../models/visible_node_item.dart';

enum SmartListType { today, favorites, dueDates }

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

DateTime get _localToday {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

final favoritesNodesStreamProvider = StreamProvider.autoDispose<List<Node>>((
  ref,
) {
  return ref.watch(nodeRepositoryProvider).watchFavorites();
});

final dueNodesStreamProvider = StreamProvider.autoDispose<List<Node>>((ref) {
  return ref.watch(nodeRepositoryProvider).watchDueNodes();
});

final nodePathProvider = FutureProvider.autoDispose.family<String, Node>((
  ref,
  node,
) async {
  if (node.parentId == null) {
    return 'DeepList';
  }
  final repository = ref.watch(nodeRepositoryProvider);
  final ancestors = await repository.getAncestors(node.id);
  if (ancestors.isEmpty) {
    return 'DeepList';
  }
  final names = ancestors
      .map((a) => a.content.trim().isEmpty ? '未命名' : a.content.trim())
      .toList();
  if (names.length > 2) {
    return '… › ${names.sublist(names.length - 2).join(' › ')}';
  }
  return 'DeepList › ${names.join(' › ')}';
});

List<SmartNodeGroup> buildSmartGroups({
  required SmartListType type,
  required List<Node> nodes,
  required DateTime today,
  Map<NodeId, int> counts = const {},
}) {
  final normalizedToday = Node.normalizeDate(today)!;
  final tomorrow = normalizedToday.add(const Duration(days: 1));

  switch (type) {
    case SmartListType.favorites:
      if (nodes.isEmpty) return const [];
      final items = <VisibleNodeItem>[];
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        items.add(
          VisibleNodeItem(
            node: node,
            parentId: node.parentId,
            hasPreviousSibling: i > 0,
            previousSiblingId: i > 0 ? nodes[i - 1].id : null,
            isLastInParent: i == nodes.length - 1,
            childCount: counts[node.id] ?? 0,
          ),
        );
      }
      return [SmartNodeGroup(title: null, items: items)];

    case SmartListType.today:
      final overdueItems = <VisibleNodeItem>[];
      final todayItems = <VisibleNodeItem>[];

      for (final node in nodes) {
        final normalized = Node.normalizeDate(node.dueDate);
        if (normalized == null) continue;
        if (normalized.isAfter(normalizedToday)) continue;

        final item = VisibleNodeItem(
          node: node,
          parentId: node.parentId,
          hasPreviousSibling: false,
          childCount: counts[node.id] ?? 0,
        );
        if (normalized.isBefore(normalizedToday)) {
          overdueItems.add(item);
        } else {
          todayItems.add(item);
        }
      }

      final groups = <SmartNodeGroup>[];
      if (overdueItems.isNotEmpty) {
        groups.add(
          SmartNodeGroup(title: '已逾期', items: overdueItems, isOverdue: true),
        );
      }
      if (todayItems.isNotEmpty) {
        groups.add(
          SmartNodeGroup(title: '今天', items: todayItems, isOverdue: false),
        );
      }
      return groups;

    case SmartListType.dueDates:
      final overdueItems = <VisibleNodeItem>[];
      final todayItems = <VisibleNodeItem>[];
      final tomorrowItems = <VisibleNodeItem>[];
      final laterItems = <VisibleNodeItem>[];

      for (final node in nodes) {
        final normalized = Node.normalizeDate(node.dueDate);
        if (normalized == null) continue;

        final item = VisibleNodeItem(
          node: node,
          parentId: node.parentId,
          hasPreviousSibling: false,
          childCount: counts[node.id] ?? 0,
        );

        if (normalized.isBefore(normalizedToday)) {
          overdueItems.add(item);
        } else if (normalized.isAtSameMomentAs(normalizedToday)) {
          todayItems.add(item);
        } else if (normalized.isAtSameMomentAs(tomorrow)) {
          tomorrowItems.add(item);
        } else {
          laterItems.add(item);
        }
      }

      final groups = <SmartNodeGroup>[];
      if (overdueItems.isNotEmpty) {
        groups.add(
          SmartNodeGroup(title: '已逾期', items: overdueItems, isOverdue: true),
        );
      }
      if (todayItems.isNotEmpty) {
        groups.add(
          SmartNodeGroup(title: '今天', items: todayItems, isOverdue: false),
        );
      }
      if (tomorrowItems.isNotEmpty) {
        groups.add(
          SmartNodeGroup(title: '明天', items: tomorrowItems, isOverdue: false),
        );
      }
      if (laterItems.isNotEmpty) {
        groups.add(
          SmartNodeGroup(title: '以后', items: laterItems, isOverdue: false),
        );
      }
      return groups;
  }
}

final smartNodesProvider = Provider.autoDispose
    .family<AsyncValue<List<SmartNodeGroup>>, SmartListType>((ref, type) {
      final nodesAsync = switch (type) {
        SmartListType.favorites => ref.watch(favoritesNodesStreamProvider),
        SmartListType.today ||
        SmartListType.dueDates => ref.watch(dueNodesStreamProvider),
      };
      final counts = ref.watch(childCountsProvider).value ?? const {};

      return nodesAsync.whenData((nodes) {
        return buildSmartGroups(
          type: type,
          nodes: nodes,
          today: _localToday,
          counts: counts,
        );
      });
    });
