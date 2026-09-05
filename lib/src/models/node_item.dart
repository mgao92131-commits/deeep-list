import 'package:isar/isar.dart';

part 'node_item.g.dart';

const int kRootNodeId = 1;

@collection
class NodeItem {
  Id id = Isar.autoIncrement;

  @Index()
  int? parentId;

  String content = '';

  String? note;

  bool isDone = false;

  bool isFavorite = false;

  /// Stores the IDs of children in their display order.
  List<int> children = [];

  /// Stores the IDs of children that have been archived.
  List<int> archivedChildren = [];

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();
}
