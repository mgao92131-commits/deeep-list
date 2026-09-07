import 'node_color.dart';
import 'node_id.dart';

const _unset = Object();

class Node {
  final NodeId id;
  final NodeId? parentId;
  final int position;
  final String content;
  final String? note;
  final bool isDone;
  final bool isFavorite;
  final bool isArchived;
  final NodeColor color;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Node({
    required this.id,
    required this.parentId,
    required this.position,
    required this.content,
    required this.note,
    required this.isDone,
    required this.isFavorite,
    required this.isArchived,
    this.color = NodeColor.none,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime? normalizeDate(DateTime? dt) {
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  Node copyWith({
    Object? parentId = _unset,
    int? position,
    String? content,
    Object? note = _unset,
    bool? isDone,
    bool? isFavorite,
    bool? isArchived,
    NodeColor? color,
    Object? dueDate = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Node(
      id: id,
      parentId: identical(parentId, _unset)
          ? this.parentId
          : parentId as NodeId?,
      position: position ?? this.position,
      content: content ?? this.content,
      note: identical(note, _unset) ? this.note : note as String?,
      isDone: isDone ?? this.isDone,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      color: color ?? this.color,
      dueDate: identical(dueDate, _unset)
          ? this.dueDate
          : dueDate as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Node($id, parentId: $parentId, position: $position)';
}
