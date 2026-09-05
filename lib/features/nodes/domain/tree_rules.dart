import 'node_id.dart';

enum TreeRuleCode {
  selfParent,
  cycle,
  duplicateOrderId,
  incompleteOrderIds,
  invalidPosition,
  danglingParent,
}

class TreeRuleViolation implements Exception {
  final TreeRuleCode code;
  final String message;

  const TreeRuleViolation(this.code, this.message);

  @override
  String toString() => 'TreeRuleViolation($code): $message';
}

class TreeRules {
  const TreeRules._();

  static void validateMove({
    required NodeId nodeId,
    required NodeId? newParentId,
    required Iterable<NodeId> targetAndAncestorIds,
  }) {
    if (newParentId == nodeId) {
      throw const TreeRuleViolation(
        TreeRuleCode.selfParent,
        'A node cannot be its own parent.',
      );
    }

    if (targetAndAncestorIds.contains(nodeId)) {
      throw const TreeRuleViolation(
        TreeRuleCode.cycle,
        'A node cannot move below its own descendant.',
      );
    }
  }

  static void validateReorder({
    required Iterable<NodeId> orderedIds,
    required Iterable<NodeId> activeSiblingIds,
  }) {
    final ordered = orderedIds.toList(growable: false);
    final expected = activeSiblingIds.toSet();
    final actual = ordered.toSet();

    if (ordered.length != actual.length) {
      throw const TreeRuleViolation(
        TreeRuleCode.duplicateOrderId,
        'Reorder input contains duplicate node IDs.',
      );
    }
    if (actual.length != expected.length) {
      throw const TreeRuleViolation(
        TreeRuleCode.incompleteOrderIds,
        'Reorder input must contain every active sibling exactly once.',
      );
    }
    if (!actual.containsAll(expected) || !expected.containsAll(actual)) {
      throw const TreeRuleViolation(
        TreeRuleCode.incompleteOrderIds,
        'Reorder input contains a node from another parent or misses a sibling.',
      );
    }
  }

  static void validatePositions(Iterable<int> positions) {
    final values = positions.toList()..sort();
    for (var index = 0; index < values.length; index++) {
      if (values[index] != index) {
        throw const TreeRuleViolation(
          TreeRuleCode.invalidPosition,
          'Sibling positions must be contiguous and zero-based.',
        );
      }
    }
  }
}
