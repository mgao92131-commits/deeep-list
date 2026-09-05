import 'package:uuid/uuid.dart';

import '../domain/node.dart';
import '../domain/node_id.dart';
import '../domain/node_repository.dart';
import '../domain/results/merge_result.dart';
import '../domain/results/split_result.dart';
import '../domain/tree_rules.dart';

class TreeCommandService {
  final TreeMutationRepository _repository;
  final Uuid _uuid;
  final DateTime Function() _clock;

  TreeCommandService(this._repository, {Uuid? uuid, DateTime Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _clock = clock ?? DateTime.now;

  Future<Node> createNode({
    required NodeId? parentId,
    required String content,
    int? position,
  }) {
    return _repository.transaction((transaction) async {
      if (parentId != null) {
        await _requireNode(transaction, parentId);
      }

      final siblings = await transaction.getChildren(
        parentId,
        includeArchived: true,
      );
      final insertion = _clampPosition(position, siblings.length);
      final now = _clock();
      final newNode = Node(
        id: _uuid.v4(),
        parentId: parentId,
        position: insertion,
        content: content,
        note: null,
        isDone: false,
        isFavorite: false,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      final ordered = [...siblings]..insert(insertion, newNode);
      await _saveOrdered(transaction, ordered);
      return ordered[insertion];
    });
  }

  Future<void> deleteSubtree(NodeId nodeId) {
    return _repository.transaction((transaction) async {
      final node = await _requireNode(transaction, nodeId);
      final visited = <NodeId>{};
      await _deleteSubtree(transaction, nodeId, visited);

      final remaining = await transaction.getChildren(
        node.parentId,
        includeArchived: true,
      );
      await _saveOrdered(transaction, remaining);
    });
  }

  Future<void> moveNode({
    required NodeId nodeId,
    required NodeId? newParentId,
    int? newPosition,
  }) {
    return _repository.transaction(
      (transaction) => _moveNodeInTransaction(
        transaction,
        nodeId: nodeId,
        newParentId: newParentId,
        newPosition: newPosition,
      ),
    );
  }

  Future<void> reorderChildren({
    required NodeId? parentId,
    required List<NodeId> orderedIds,
  }) {
    return _repository.transaction((transaction) async {
      final allSiblings = await transaction.getChildren(
        parentId,
        includeArchived: true,
      );
      final activeSiblings = allSiblings
          .where((node) => !node.isArchived)
          .toList();
      TreeRules.validateReorder(
        orderedIds: orderedIds,
        activeSiblingIds: activeSiblings.map((node) => node.id),
      );

      final activeById = {for (final node in activeSiblings) node.id: node};
      var activeIndex = 0;
      final reordered = allSiblings.map((node) {
        if (node.isArchived) return node;
        return activeById[orderedIds[activeIndex++]]!;
      }).toList();

      await _saveOrdered(transaction, reordered);
    });
  }

  Future<void> archiveNode(NodeId nodeId) {
    return _setArchived(nodeId, true);
  }

  Future<void> restoreNode(NodeId nodeId) {
    return _setArchived(nodeId, false);
  }

  Future<void> updateContent(NodeId nodeId, String content) {
    return _repository.transaction((transaction) async {
      final node = await _requireNode(transaction, nodeId);
      await transaction.saveNode(
        node.copyWith(content: content, updatedAt: _clock()),
      );
    });
  }

  Future<void> toggleDone(NodeId nodeId) {
    return _repository.transaction((transaction) async {
      final node = await _requireNode(transaction, nodeId);
      await transaction.saveNode(
        node.copyWith(isDone: !node.isDone, updatedAt: _clock()),
      );
    });
  }

  Future<void> toggleFavorite(NodeId nodeId) {
    return _repository.transaction((transaction) async {
      final node = await _requireNode(transaction, nodeId);
      await transaction.saveNode(
        node.copyWith(isFavorite: !node.isFavorite, updatedAt: _clock()),
      );
    });
  }

  Future<SplitResult> splitNode({
    required NodeId nodeId,
    required int cursorPosition,
    required String text,
  }) {
    return _repository.transaction((transaction) async {
      final node = await _requireNode(transaction, nodeId);
      _ensureEditable(node);

      final cursor = cursorPosition.clamp(0, text.length).toInt();
      final prefix = text.substring(0, cursor);
      final suffix = text.substring(cursor);
      final siblings = await transaction.getChildren(
        node.parentId,
        includeArchived: true,
      );
      final nodeIndex = siblings.indexWhere((sibling) => sibling.id == nodeId);
      if (nodeIndex < 0) {
        throw StateError('Node $nodeId is not a child of its parent.');
      }

      final now = _clock();
      final updatedCurrent = node.copyWith(content: prefix, updatedAt: now);
      final newNode = Node(
        id: _uuid.v4(),
        parentId: node.parentId,
        position: nodeIndex + 1,
        content: suffix,
        note: null,
        isDone: false,
        isFavorite: false,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );
      final ordered = [...siblings]
        ..[nodeIndex] = updatedCurrent
        ..insert(nodeIndex + 1, newNode);
      await _saveOrdered(transaction, ordered);

      return SplitResult(newNodeId: newNode.id, cursorPosition: 0);
    });
  }

  Future<MergeResult?> mergeWithPrevious(NodeId nodeId) {
    return _repository.transaction((transaction) async {
      final node = await _requireNode(transaction, nodeId);
      _ensureEditable(node);

      final siblings = await transaction.getChildren(
        node.parentId,
        includeArchived: true,
      );
      final visibleSiblings = siblings
          .where((sibling) => !sibling.isArchived)
          .toList();
      final visibleIndex = visibleSiblings.indexWhere(
        (sibling) => sibling.id == nodeId,
      );
      if (visibleIndex <= 0) return null;

      final previous = visibleSiblings[visibleIndex - 1];
      final previousChildren = await transaction.getChildren(
        previous.id,
        includeArchived: true,
      );
      final currentChildren = await transaction.getChildren(
        node.id,
        includeArchived: true,
      );
      final now = _clock();
      final cursor = previous.content.length;
      final updatedPrevious = previous.copyWith(
        content: previous.content + node.content,
        updatedAt: now,
      );
      await transaction.saveNode(updatedPrevious);

      final mergedChildren = [...previousChildren, ...currentChildren];
      for (var index = 0; index < mergedChildren.length; index++) {
        await transaction.saveNode(
          mergedChildren[index].copyWith(
            parentId: previous.id,
            position: index,
            updatedAt: now,
          ),
        );
      }

      await transaction.deleteNode(node.id);
      final remainingSiblings = siblings
          .where((sibling) => sibling.id != node.id)
          .map(
            (sibling) => sibling.id == previous.id ? updatedPrevious : sibling,
          )
          .toList();
      await _saveOrdered(transaction, remainingSiblings);

      return MergeResult(targetNodeId: previous.id, cursorPosition: cursor);
    });
  }

  Future<void> indentNode(NodeId nodeId) {
    return _repository.transaction((transaction) async {
      final node = await _requireNode(transaction, nodeId);
      final siblings = (await transaction.getChildren(
        node.parentId,
        includeArchived: true,
      )).where((sibling) => !sibling.isArchived).toList();
      final index = siblings.indexWhere((sibling) => sibling.id == nodeId);
      if (index <= 0) return;

      final targetParent = siblings[index - 1];
      final targetChildren = await transaction.getChildren(
        targetParent.id,
        includeArchived: true,
      );
      await _moveNodeInTransaction(
        transaction,
        nodeId: nodeId,
        newParentId: targetParent.id,
        newPosition: targetChildren.length,
      );
    });
  }

  Future<void> outdentNode(NodeId nodeId) {
    return _repository.transaction((transaction) async {
      final node = await _requireNode(transaction, nodeId);
      final parentId = node.parentId;
      if (parentId == null) return;

      final parent = await _requireNode(transaction, parentId);
      final grandparentSiblings = await transaction.getChildren(
        parent.parentId,
        includeArchived: true,
      );
      final parentIndex = grandparentSiblings.indexWhere(
        (sibling) => sibling.id == parent.id,
      );
      if (parentIndex < 0) {
        throw const TreeRuleViolation(
          TreeRuleCode.danglingParent,
          'The current parent is not attached to its own parent.',
        );
      }

      await _moveNodeInTransaction(
        transaction,
        nodeId: nodeId,
        newParentId: parent.parentId,
        newPosition: parentIndex + 1,
      );
    });
  }

  Future<void> _setArchived(NodeId nodeId, bool archived) {
    return _repository.transaction((transaction) async {
      final node = await _requireNode(transaction, nodeId);
      await transaction.saveNode(
        node.copyWith(isArchived: archived, updatedAt: _clock()),
      );
    });
  }

  Future<void> _moveNodeInTransaction(
    TreeTransaction transaction, {
    required NodeId nodeId,
    required NodeId? newParentId,
    required int? newPosition,
  }) async {
    final node = await _requireNode(transaction, nodeId);
    if (newParentId != null) {
      await _requireNode(transaction, newParentId);
    }

    final targetAncestors = await _ancestorChain(transaction, newParentId);
    TreeRules.validateMove(
      nodeId: nodeId,
      newParentId: newParentId,
      targetAndAncestorIds: targetAncestors,
    );

    final oldParentId = node.parentId;
    final oldSiblings = await transaction.getChildren(
      oldParentId,
      includeArchived: true,
    );
    final sourceWithoutNode = oldSiblings
        .where((sibling) => sibling.id != nodeId)
        .toList();
    final targetSiblings = oldParentId == newParentId
        ? sourceWithoutNode
        : await transaction.getChildren(newParentId, includeArchived: true);

    if (oldParentId != newParentId) {
      await _saveOrdered(transaction, sourceWithoutNode);
    }

    final insertion = _clampPosition(newPosition, targetSiblings.length);
    final movedNode = node.copyWith(
      parentId: newParentId,
      position: insertion,
      updatedAt: _clock(),
    );
    final newOrdered = [...targetSiblings]..insert(insertion, movedNode);
    await _saveOrdered(transaction, newOrdered);
  }

  Future<List<NodeId>> _ancestorChain(
    TreeTransaction transaction,
    NodeId? start,
  ) async {
    final chain = <NodeId>[];
    final visited = <NodeId>{};
    var current = start;
    while (current != null) {
      if (!visited.add(current)) {
        throw const TreeRuleViolation(
          TreeRuleCode.cycle,
          'The existing parent chain already contains a cycle.',
        );
      }
      final node = await transaction.getNode(current);
      if (node == null) {
        throw const TreeRuleViolation(
          TreeRuleCode.danglingParent,
          'The target parent chain contains a missing node.',
        );
      }
      chain.add(current);
      current = node.parentId;
    }
    return chain;
  }

  Future<Node> _requireNode(TreeTransaction transaction, NodeId nodeId) async {
    final node = await transaction.getNode(nodeId);
    if (node == null) {
      throw StateError('Node $nodeId does not exist.');
    }
    return node;
  }

  Future<void> _deleteSubtree(
    TreeTransaction transaction,
    NodeId nodeId,
    Set<NodeId> visited,
  ) async {
    if (!visited.add(nodeId)) return;
    final children = await transaction.getChildren(
      nodeId,
      includeArchived: true,
    );
    for (final child in children) {
      await _deleteSubtree(transaction, child.id, visited);
    }
    await transaction.deleteNode(nodeId);
  }

  Future<void> _saveOrdered(
    TreeTransaction transaction,
    List<Node> nodes,
  ) async {
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      await transaction.saveNode(
        node.copyWith(position: index, updatedAt: _clock()),
      );
    }
  }

  void _ensureEditable(Node node) {
    if (node.isArchived) {
      throw StateError('Archived nodes cannot be edited.');
    }
  }

  int _clampPosition(int? position, int siblingCount) {
    return (position ?? siblingCount).clamp(0, siblingCount).toInt();
  }
}
