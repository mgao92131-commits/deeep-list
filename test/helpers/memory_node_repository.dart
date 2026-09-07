import 'dart:async';

import 'package:deep_list/features/nodes/domain/node.dart';
import 'package:deep_list/features/nodes/domain/node_id.dart';
import 'package:deep_list/features/nodes/domain/node_repository.dart';

class MemoryNodeRepository implements TreeMutationRepository {
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
  Stream<Map<NodeId, int>> watchAllChildCounts({
    bool includeArchived = false,
  }) async* {
    Map<NodeId, int> read() {
      final counts = <NodeId, int>{};
      for (final node in _nodes.values) {
        if (node.parentId != null && (includeArchived || !node.isArchived)) {
          counts[node.parentId!] = (counts[node.parentId!] ?? 0) + 1;
        }
      }
      return counts;
    }

    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Stream<List<Node>> watchFavorites() async* {
    List<Node> read() {
      final list = _nodes.values
          .where((node) => node.isFavorite && !node.isDone && !node.isArchived)
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }

    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Stream<List<Node>> watchDueNodes() async* {
    List<Node> read() {
      final list = _nodes.values
          .where((node) => node.dueDate != null && !node.isDone && !node.isArchived)
          .toList();
      list.sort((a, b) {
        final cmp = a.dueDate!.compareTo(b.dueDate!);
        if (cmp != 0) return cmp;
        final posCmp = a.position.compareTo(b.position);
        if (posCmp != 0) return posCmp;
        return a.id.compareTo(b.id);
      });
      return list;
    }

    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Future<List<Node>> getAncestors(NodeId nodeId) async {
    final ancestors = <Node>[];
    final visited = <NodeId>{nodeId};
    var currentId = nodeId;
    while (true) {
      final node = _nodes[currentId];
      if (node == null || node.parentId == null) break;
      if (!visited.add(node.parentId!)) break;
      final parent = _nodes[node.parentId!];
      if (parent == null) break;
      ancestors.insert(0, parent);
      currentId = parent.id;
    }
    return ancestors;
  }

  Duration? transactionDelay;

  @override
  Future<T> transaction<T>(TreeTransactionAction<T> action) async {
    if (transactionDelay != null) {
      await Future<void>.delayed(transactionDelay!);
    }
    final staged = Map<NodeId, Node>.from(_nodes);
    final result = await action(_MemoryTransaction(staged));
    _nodes = staged;
    _changes.add(null);
    return result;
  }

  /// Seeds malformed state for defensive tree-rule tests only.
  Future<void> putUnsafe(Node node) async {
    _nodes[node.id] = node;
    _changes.add(null);
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

class _MemoryTransaction implements TreeTransaction {
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
