import '../../domain/node.dart';
import '../../domain/node_id.dart';

class VisibleNodeItem {
  final Node node;
  final int level;
  final NodeId? parentId;
  final bool hasPreviousSibling;
  final NodeId? previousSiblingId;
  final bool isLastInParent;

  const VisibleNodeItem({
    required this.node,
    required this.level,
    required this.parentId,
    required this.hasPreviousSibling,
    this.previousSiblingId,
    this.isLastInParent = false,
  });

  NodeId get id => node.id;
  String get content => node.content;
  bool get isDone => node.isDone;

  /// Spec 20-22:
  /// 右滑 -> Indent:
  /// - 成为上一个同级节点的子节点 (must have previous sibling)
  /// - 第二层不允许继续右滑 (level 2 cannot indent, otherwise exceeds 2 visible levels)
  bool get canIndent => level == 1 && hasPreviousSibling;

  /// Spec 23-24:
  /// 左滑 -> Outdent:
  /// - 提升一级，移动到 Parent 的同级层
  /// - 已经无法提升的 Node (level 1 cannot outdent)
  bool get canOutdent => level == 2;
}
