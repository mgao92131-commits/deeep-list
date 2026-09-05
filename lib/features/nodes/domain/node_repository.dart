import 'node.dart';
import 'node_id.dart';

typedef TreeTransactionAction<T> =
    Future<T> Function(TreeTransaction transaction);

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
}

/// Mutation-only persistence port used by [TreeCommandService].
///
/// Presentation and ordinary query code should depend on [NodeRepository]
/// instead, so parent and position writes remain centralized in the command
/// service.
abstract interface class TreeMutationRepository implements NodeRepository {
  Future<T> transaction<T>(TreeTransactionAction<T> action);
}

abstract interface class TreeTransaction {
  Future<Node?> getNode(NodeId id);

  Future<List<Node>> getChildren(
    NodeId? parentId, {
    bool includeArchived = false,
  });

  Future<void> saveNode(Node node);

  Future<void> deleteNode(NodeId id);
}
