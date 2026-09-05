import 'node.dart';
import 'node_id.dart';

typedef NodeTransactionAction<T> =
    Future<T> Function(NodeRepositoryTransaction transaction);

abstract interface class NodeRepository {
  Future<Node?> getNode(NodeId id);

  Stream<Node?> watchNode(NodeId id);

  Future<List<Node>> getChildren(
    NodeId? parentId, {
    bool includeArchived = false,
  });

  Stream<List<Node>> watchChildren(
    NodeId? parentId, {
    bool includeArchived = false,
  });

  Future<T> transaction<T>(NodeTransactionAction<T> action);
}

abstract interface class NodeRepositoryTransaction {
  Future<Node?> getNode(NodeId id);

  Future<List<Node>> getChildren(
    NodeId? parentId, {
    bool includeArchived = false,
  });

  Future<void> saveNode(Node node);

  Future<void> deleteNode(NodeId id);
}
