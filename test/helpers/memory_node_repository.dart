import 'dart:async';

import 'package:deep_list/features/nodes/domain/node.dart';
import 'package:deep_list/features/nodes/domain/node_id.dart';
import 'package:deep_list/features/nodes/domain/node_repository.dart';

class MemoryNodeRepository implements NodeRepository {
  Map<NodeId, Node> _nodes = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Future<Node?> getNode(NodeId id) async => _nodes[id];

  @override
  Stream<Node?> watchNode(NodeId id) async* {
    yield _nodes[id];
    yield* _changes.stream.map((_) => _nodes[id]);
  }

  @override
  Future<List<Node>> getChildren(
    NodeId? parentId, {
    bool includeArchived = false,
  }) async {
    return _select(parentId, includeArchived: includeArchived);
  }

  @override
  Stream<List<Node>> watchChildren(
    NodeId? parentId, {
    bool includeArchived = false,
  }) async* {
    List<Node> read() => _select(parentId, includeArchived: includeArchived);

    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Future<T> transaction<T>(NodeTransactionAction<T> action) async {
    final staged = Map<NodeId, Node>.from(_nodes);
    final result = await action(_MemoryTransaction(staged));
    _nodes = staged;
    _changes.add(null);
    return result;
  }

  List<Node> _select(NodeId? parentId, {required bool includeArchived}) {
    final selected = _nodes.values
        .where(
          (node) =>
              node.parentId == parentId &&
              (includeArchived || !node.isArchived),
        )
        .toList();
    selected.sort(
      (a, b) => a.position == b.position
          ? a.id.compareTo(b.id)
          : a.position.compareTo(b.position),
    );
    return selected;
  }

  Future<void> close() => _changes.close();
}

class _MemoryTransaction implements NodeRepositoryTransaction {
  final Map<NodeId, Node> nodes;

  _MemoryTransaction(this.nodes);

  @override
  Future<Node?> getNode(NodeId id) async => nodes[id];

  @override
  Future<List<Node>> getChildren(
    NodeId? parentId, {
    bool includeArchived = false,
  }) async {
    final selected = nodes.values
        .where(
          (node) =>
              node.parentId == parentId &&
              (includeArchived || !node.isArchived),
        )
        .toList();
    selected.sort(
      (a, b) => a.position == b.position
          ? a.id.compareTo(b.id)
          : a.position.compareTo(b.position),
    );
    return selected;
  }

  @override
  Future<void> saveNode(Node node) async {
    nodes[node.id] = node;
  }

  @override
  Future<void> deleteNode(NodeId id) async {
    nodes.remove(id);
  }
}
