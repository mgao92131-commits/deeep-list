import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/node.dart' as domain;
import '../domain/node_id.dart';
import '../domain/node_repository.dart';

class DriftNodeRepository implements TreeMutationRepository {
  final db.AppDatabase database;

  DriftNodeRepository(this.database);

  @override
  Future<domain.Node?> getNode(NodeId id) async {
    final row = await _selectNode(id).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Stream<domain.Node?> watchNode(NodeId id) {
    return _selectNode(
      id,
    ).watchSingleOrNull().map((row) => row == null ? null : _toDomain(row));
  }

  @override
  Future<List<domain.Node>> getChildren(
    NodeId? parentId, {
    bool includeArchived = false,
  }) {
    return _selectChildren(
      parentId,
      includeArchived: includeArchived,
    ).get().then((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Stream<List<domain.Node>> watchChildren(
    NodeId? parentId, {
    bool includeArchived = false,
  }) {
    return _selectChildren(
      parentId,
      includeArchived: includeArchived,
    ).watch().map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Stream<Map<NodeId, int>> watchAllChildCounts({
    bool includeArchived = false,
  }) {
    final countCol = database.nodes.id.count();
    final query = database.selectOnly(database.nodes)
      ..addColumns([database.nodes.parentId, countCol])
      ..where(
        database.nodes.parentId.isNotNull() &
            (includeArchived
                ? const Constant(true)
                : database.nodes.isArchived.equals(false)),
      )
      ..groupBy([database.nodes.parentId]);

    return query.watch().map((rows) {
      final result = <NodeId, int>{};
      for (final row in rows) {
        final pid = row.read(database.nodes.parentId);
        final count = row.read(countCol) ?? 0;
        if (pid != null) {
          result[pid] = count;
        }
      }
      return result;
    });
  }

  @override
  Future<T> transaction<T>(TreeTransactionAction<T> action) {
    return database.transaction(
      () => action(_DriftNodeRepositoryTransaction(database)),
    );
  }

  SimpleSelectStatement<db.$NodesTable, db.Node> _selectNode(NodeId id) {
    return database.select(database.nodes)
      ..where((table) => table.id.equals(id));
  }

  SimpleSelectStatement<db.$NodesTable, db.Node> _selectChildren(
    NodeId? parentId, {
    required bool includeArchived,
  }) {
    final query = database.select(database.nodes)
      ..where((table) {
        final parentCondition = parentId == null
            ? table.parentId.isNull()
            : table.parentId.equals(parentId);
        return includeArchived
            ? parentCondition
            : parentCondition & table.isArchived.equals(false);
      })
      ..orderBy([
        (table) => OrderingTerm(expression: table.position),
        (table) => OrderingTerm(expression: table.id),
      ]);
    return query;
  }

  domain.Node _toDomain(db.Node row) {
    return domain.Node(
      id: row.id,
      parentId: row.parentId,
      position: row.position,
      content: row.content,
      note: row.note,
      isDone: row.isDone,
      isFavorite: row.isFavorite,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

class _DriftNodeRepositoryTransaction implements TreeTransaction {
  final db.AppDatabase database;

  _DriftNodeRepositoryTransaction(this.database);

  @override
  Future<domain.Node?> getNode(NodeId id) async {
    final row = await (database.select(
      database.nodes,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<domain.Node>> getChildren(
    NodeId? parentId, {
    bool includeArchived = false,
  }) async {
    final query = database.select(database.nodes)
      ..where((table) {
        final parentCondition = parentId == null
            ? table.parentId.isNull()
            : table.parentId.equals(parentId);
        return includeArchived
            ? parentCondition
            : parentCondition & table.isArchived.equals(false);
      })
      ..orderBy([
        (table) => OrderingTerm(expression: table.position),
        (table) => OrderingTerm(expression: table.id),
      ]);
    final rows = await query.get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> saveNode(domain.Node node) async {
    final companion = _toCompanion(node);
    final updated = await (database.update(
      database.nodes,
    )..where((table) => table.id.equals(node.id))).write(companion);
    if (updated == 0) {
      await database.into(database.nodes).insert(companion);
    }
  }

  @override
  Future<void> deleteNode(NodeId id) async {
    await (database.delete(
      database.nodes,
    )..where((table) => table.id.equals(id))).go();
  }

  domain.Node _toDomain(db.Node row) {
    return domain.Node(
      id: row.id,
      parentId: row.parentId,
      position: row.position,
      content: row.content,
      note: row.note,
      isDone: row.isDone,
      isFavorite: row.isFavorite,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  db.NodesCompanion _toCompanion(domain.Node node) {
    return db.NodesCompanion.insert(
      id: node.id,
      parentId: Value(node.parentId),
      position: node.position,
      content: node.content,
      note: Value(node.note),
      isDone: Value(node.isDone),
      isFavorite: Value(node.isFavorite),
      isArchived: Value(node.isArchived),
      createdAt: node.createdAt,
      updatedAt: node.updatedAt,
    );
  }
}
