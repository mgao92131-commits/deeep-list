import '../../domain/node_id.dart';
import 'visible_node_item.dart';

class Level1DisplayGroup {
  final VisibleNodeItem parent;
  final List<VisibleNodeItem> children;

  const Level1DisplayGroup({required this.parent, this.children = const []});

  NodeId get id => parent.id;
}

class TwoLevelTree {
  final List<Level1DisplayGroup> groups;

  const TwoLevelTree(this.groups);

  bool get isEmpty => groups.isEmpty;

  List<VisibleNodeItem> get allItems {
    final list = <VisibleNodeItem>[];
    for (final group in groups) {
      list.add(group.parent);
      list.addAll(group.children);
    }
    return list;
  }

  VisibleNodeItem? findItem(NodeId id) {
    for (final group in groups) {
      if (group.parent.id == id) return group.parent;
      for (final child in group.children) {
        if (child.id == id) return child;
      }
    }
    return null;
  }

  VisibleNodeItem? findPreviousItem(NodeId id) {
    final flat = allItems;
    final index = flat.indexWhere((it) => it.id == id);
    if (index > 0) return flat[index - 1];
    return null;
  }
}
