import 'node_id.dart';

enum NodeFailureCode { notFound, archived, invalidParent }

sealed class NodeFailure extends StateError {
  final NodeFailureCode code;
  final NodeId nodeId;
  NodeFailure(this.code, this.nodeId, String message) : super(message);
}

class NodeNotFound extends NodeFailure {
  NodeNotFound(NodeId nodeId)
    : super(NodeFailureCode.notFound, nodeId, 'Node $nodeId does not exist.');
}

class ArchivedNode extends NodeFailure {
  ArchivedNode(NodeId nodeId)
    : super(
        NodeFailureCode.archived,
        nodeId,
        'Archived nodes cannot be edited.',
      );
}

class InvalidNodeParent extends NodeFailure {
  InvalidNodeParent(NodeId nodeId)
    : super(
        NodeFailureCode.invalidParent,
        nodeId,
        'Node $nodeId is not a child of its parent.',
      );
}
