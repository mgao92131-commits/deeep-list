import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../domain/node.dart';
import '../../domain/node_repository.dart';
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

DateTime get _localTomorrow => _localToday.add(const Duration(days: 1));

Future<String> _buildNodePath(NodeRepository repository, Node node) async {
  if (node.parentId == null) {
    return 'DeepList';
  }
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
}

final favoritesNodesStreamProvider =
    StreamProvider.autoDispose<List<Node>>((ref) {
      return ref.watch(nodeRepositoryProvider).watchFavorites();
    });

final dueNodesStreamProvider =
    StreamProvider.autoDispose<List<Node>>((ref) {
      return ref.watch(nodeRepositoryProvider).watchDueNodes();
    });

final smartNodesProvider = FutureProvider.autoDispose
    .family<List<SmartNodeGroup>, SmartListType>((ref, type) async {
      final repository = ref.watch(nodeRepositoryProvider);
      final counts = ref.watch(childCountsProvider).value ?? const {};

      switch (type) {
        case SmartListType.favorites:
          final rawNodes = await ref.watch(favoritesNodesStreamProvider.future);
          final items = <VisibleNodeItem>[];
          for (var i = 0; i < rawNodes.length; i++) {
            final node = rawNodes[i];
            final pathText = await _buildNodePath(repository, node);
            items.add(
              VisibleNodeItem(
                node: node,
                parentId: node.parentId,
                hasPreviousSibling: i > 0,
                previousSiblingId: i > 0 ? rawNodes[i - 1].id : null,
                isLastInParent: i == rawNodes.length - 1,
                childCount: counts[node.id] ?? 0,
                pathText: pathText,
              ),
            );
          }
          if (items.isEmpty) return const [];
          return [SmartNodeGroup(title: null, items: items)];

        case SmartListType.today:
          final rawNodes = await ref.watch(dueNodesStreamProvider.future);

          final today = _localToday;
          final filtered = rawNodes.where((n) {
            final normalized = Node.normalizeDate(n.dueDate);
            if (normalized == null) return false;
            return !normalized.isAfter(today);
          }).toList();

          final overdueItems = <VisibleNodeItem>[];
          final todayItems = <VisibleNodeItem>[];

          for (final node in filtered) {
            final normalized = Node.normalizeDate(node.dueDate)!;
            final pathText = await _buildNodePath(repository, node);
            final item = VisibleNodeItem(
              node: node,
              parentId: node.parentId,
              hasPreviousSibling: false,
              childCount: counts[node.id] ?? 0,
              pathText: pathText,
            );
            if (normalized.isBefore(today)) {
              overdueItems.add(item);
            } else {
              todayItems.add(item);
            }
          }

          final groups = <SmartNodeGroup>[];
          if (overdueItems.isNotEmpty) {
            groups.add(
              SmartNodeGroup(
                title: '已逾期',
                items: overdueItems,
                isOverdue: true,
              ),
            );
          }
          if (todayItems.isNotEmpty) {
            groups.add(
              SmartNodeGroup(
                title: '今天',
                items: todayItems,
                isOverdue: false,
              ),
            );
          }
          return groups;

        case SmartListType.dueDates:
          final rawNodes = await ref.watch(dueNodesStreamProvider.future);

          final today = _localToday;
          final tomorrow = _localTomorrow;

          final overdueItems = <VisibleNodeItem>[];
          final todayItems = <VisibleNodeItem>[];
          final tomorrowItems = <VisibleNodeItem>[];
          final laterItems = <VisibleNodeItem>[];

          for (final node in rawNodes) {
            final normalized = Node.normalizeDate(node.dueDate);
            if (normalized == null) continue;
            final pathText = await _buildNodePath(repository, node);
            final item = VisibleNodeItem(
              node: node,
              parentId: node.parentId,
              hasPreviousSibling: false,
              childCount: counts[node.id] ?? 0,
              pathText: pathText,
            );

            if (normalized.isBefore(today)) {
              overdueItems.add(item);
            } else if (normalized.isAtSameMomentAs(today)) {
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
              SmartNodeGroup(
                title: '已逾期',
                items: overdueItems,
                isOverdue: true,
              ),
            );
          }
          if (todayItems.isNotEmpty) {
            groups.add(
              SmartNodeGroup(
                title: '今天',
                items: todayItems,
                isOverdue: false,
              ),
            );
          }
          if (tomorrowItems.isNotEmpty) {
            groups.add(
              SmartNodeGroup(
                title: '明天',
                items: tomorrowItems,
                isOverdue: false,
              ),
            );
          }
          if (laterItems.isNotEmpty) {
            groups.add(
              SmartNodeGroup(
                title: '以后',
                items: laterItems,
                isOverdue: false,
              ),
            );
          }
          return groups;
      }
    });
