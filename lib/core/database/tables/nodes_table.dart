import 'package:drift/drift.dart';

import '../../../features/nodes/domain/node_color.dart';

@TableIndex(name: 'nodes_parent_position', columns: {#parentId, #position})
@TableIndex(
  name: 'nodes_parent_archive_position',
  columns: {#parentId, #isArchived, #position},
)
class Nodes extends Table {
  TextColumn get id => text()();

  TextColumn get parentId => text().nullable().references(Nodes, #id)();

  IntColumn get position => integer()();

  TextColumn get content => text()();

  TextColumn get note => text().nullable()();

  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  TextColumn get color =>
      textEnum<NodeColor>().withDefault(const Constant('none'))();

  DateTimeColumn get dueDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (parent_id IS NULL OR parent_id <> id)',
  ];
}
