import 'dart:async';
import 'package:signals_flutter/signals_flutter.dart';
import '../repositories/node_repository.dart';
import '../models/node_item.dart';

typedef FocusRequest = ({int nodeId, int? cursor});

class NodeViewModel {
  final NodeRepository _repo;
  final int nodeId;

  late final StreamSignal<NodeItem?> node;

  final StreamController<FocusRequest> _focusRequests =
      StreamController.broadcast();
  Stream<FocusRequest> get focusRequests => _focusRequests.stream;

  NodeViewModel(this._repo, this.nodeId) {
    node = streamSignal(() => _repo.watchById(nodeId));
  }

  Stream<NodeItem?> watchById(int nodeId) => _repo.watchById(nodeId);

  Future<void> updateNode(NodeItem item) async {
    await _repo.updateNode(item);
  }

  Future<void> toggleDone(NodeItem item) async {
    item.isDone = !item.isDone;
    await _repo.updateNode(item);
  }

  Future<void> toggleFavorite(NodeItem item) async {
    item.isFavorite = !item.isFavorite;
    await _repo.updateNode(item);
  }

  Future<void> archive(NodeItem item) async {
    await _repo.archiveNode(item.id);
  }

  Future<void> delete(int itemId) async {
    await _repo.removeNode(itemId);
  }

  Future<int> addNode(String content) async {
    final newItem = NodeItem()..content = content;
    return await _repo.insertNode(newItem, parentId: nodeId);
  }

  Future<void> reorder(List<int> newChildrenIds) async {
    final parent = node.value.value;
    if (parent != null) {
      parent.children = newChildrenIds;
      await _repo.updateNode(parent);
    }
  }

  Future<void> handleEnter(NodeItem item, int cursorIndex, String text) async {
    // 1. Split
    final prefix = text.substring(0, cursorIndex);
    final suffix = text.substring(cursorIndex);

    // 2. Update current
    item.content = prefix;
    await _repo.updateNode(item);

    // 3. Insert new
    final parentId = item.parentId;
    if (parentId == null) return;

    final parent = await _repo.watchById(parentId).first;
    if (parent == null) return;

    final index = parent.children.indexOf(item.id);

    final newItem = NodeItem()..content = suffix;
    final newId = await _repo.insertNode(newItem, parentId: parentId);

    // Reorder if not at end (insertNode adds to end)
    // We need to fetch the *latest* parent state because insertNode updated it.
    final updatedParent = await _repo.watchById(parentId).first;
    if (updatedParent != null &&
        index != -1 &&
        index < updatedParent.children.length - 1) {
      final children = List<int>.from(updatedParent.children);
      // Ensure newId is in list (it should be at end)
      if (children.contains(newId)) {
        children.remove(newId);
        children.insert(index + 1, newId);
        updatedParent.children = children;
        await _repo.updateNode(updatedParent);
      }
    }

    // 4. Focus new
    _focusRequests.add((nodeId: newId, cursor: 0));
  }

  Future<void> handleBackspace(
    NodeItem item,
    int cursorIndex,
    String text,
  ) async {
    if (cursorIndex != 0) return;

    final parentId = item.parentId;
    if (parentId == null) return;

    final parent = await _repo.watchById(parentId).first;
    if (parent == null) return;

    final index = parent.children.indexOf(item.id);

    if (index > 0) {
      final prevId = parent.children[index - 1];
      final prevNode = await _repo.watchById(prevId).first;

      if (prevNode != null) {
        final oldLength = prevNode.content.length;

        // Merge text
        prevNode.content += text;
        await _repo.updateNode(prevNode);

        // Move children
        if (item.children.isNotEmpty) {
          // Create a copy of children list to iterate safely
          final childrenToMove = List<int>.from(item.children);
          for (final childId in childrenToMove) {
            await _repo.moveNode(childId, prevId);
          }
        }

        // Delete current
        await _repo.removeNode(item.id);

        // Focus prev
        _focusRequests.add((nodeId: prevId, cursor: oldLength));
      }
    } else {
      // First item? Maybe do nothing or delete if empty?
      if (text.isEmpty) {
        // If empty and at start, delete?
        // Usually if it's the ONLY item, don't delete?
        // Or focus parent?
        await _repo.removeNode(item.id);
      }
    }
  }
}
