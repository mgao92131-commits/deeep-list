import '../../domain/node.dart';
import '../../domain/node_id.dart';

const _unset = Object();

class VisibleNodeItem {
  final Node node;
  final NodeId? parentId;
  final bool hasPreviousSibling;
  final NodeId? previousSiblingId;
  final bool isLastInParent;
  final int childCount;
  final String? pathText;

  const VisibleNodeItem({
    required this.node,
    required this.parentId,
    required this.hasPreviousSibling,
    this.previousSiblingId,
    this.isLastInParent = false,
    this.childCount = 0,
    this.pathText,
  });

  VisibleNodeItem copyWith({
    Node? node,
    NodeId? parentId,
    bool? hasPreviousSibling,
    NodeId? previousSiblingId,
    bool? isLastInParent,
    int? childCount,
    Object? pathText = _unset,
  }) {
    return VisibleNodeItem(
      node: node ?? this.node,
      parentId: parentId ?? this.parentId,
      hasPreviousSibling: hasPreviousSibling ?? this.hasPreviousSibling,
      previousSiblingId: previousSiblingId ?? this.previousSiblingId,
      isLastInParent: isLastInParent ?? this.isLastInParent,
      childCount: childCount ?? this.childCount,
      pathText: identical(pathText, _unset) ? this.pathText : pathText as String?,
    );
  }

  NodeId get id => node.id;
  String get content => node.content;
  bool get isDone => node.isDone;
  bool get isArchived => node.isArchived;

  /// 右滑 -> Indent: 成为上一个同级节点的子节点 (must have previous sibling and not archived)
  bool get canIndent => !isArchived && hasPreviousSibling;

  /// 左滑 -> Outdent: 提升一级，移动到 Parent 的同级层 (root nodes cannot outdent, cannot outdent if archived)
  bool get canOutdent => !isArchived && parentId != null;
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
