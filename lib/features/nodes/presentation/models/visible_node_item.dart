import '../../domain/node.dart';
import '../../domain/node_id.dart';

class VisibleNodeItem {
  final Node node;
  final NodeId? parentId;
  final bool hasPreviousSibling;
  final NodeId? previousSiblingId;
  final bool isLastInParent;
  final int childCount;

  const VisibleNodeItem({
    required this.node,
    required this.parentId,
    required this.hasPreviousSibling,
    this.previousSiblingId,
    this.isLastInParent = false,
    this.childCount = 0,
  });

  VisibleNodeItem copyWith({
    Node? node,
    NodeId? parentId,
    bool? hasPreviousSibling,
    NodeId? previousSiblingId,
    bool? isLastInParent,
    int? childCount,
  }) {
    return VisibleNodeItem(
      node: node ?? this.node,
      parentId: parentId ?? this.parentId,
      hasPreviousSibling: hasPreviousSibling ?? this.hasPreviousSibling,
      previousSiblingId: previousSiblingId ?? this.previousSiblingId,
      isLastInParent: isLastInParent ?? this.isLastInParent,
      childCount: childCount ?? this.childCount,
    );
  }

  NodeId get id => node.id;
  String get content => node.content;
  bool get isDone => node.isDone;

  /// 右滑 -> Indent: 成为上一个同级节点的子节点 (must have previous sibling)
  bool get canIndent => hasPreviousSibling;

  /// 左滑 -> Outdent: 提升一级，移动到 Parent 的同级层 (root nodes cannot outdent)
  bool get canOutdent => parentId != null;
}

extension VisibleNodeItemListX on List<VisibleNodeItem> {
  VisibleNodeItem? findItem(NodeId id) {
    for (final item in this) {
      if (item.id == id) return item;
    }
    return null;
  }

  VisibleNodeItem? findPreviousItem(NodeId id) {
    final index = indexWhere((it) => it.id == id);
    if (index > 0) return this[index - 1];
    return null;
  }
}
