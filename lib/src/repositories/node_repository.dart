import 'dart:async';
import 'package:isar/isar.dart';
import '../models/node_item.dart';
import '../services/database_service.dart';

class NodeRepository {
  final DatabaseService _dbService;

  NodeRepository(this._dbService);

  Future<Isar> get _isar => _dbService.isar;

  int getRootNodeId() => kRootNodeId;

  Stream<NodeItem?> watchById(int nodeId) async* {
    final isar = await _isar;
    yield* isar.nodeItems.watchObject(nodeId, fireImmediately: true);
  }

  Stream<List<NodeItem>> watchChildren(int parentId) async* {
    final isar = await _isar;
    final controller = StreamController<List<NodeItem>>();

    // Helper to fetch and sort
    Future<void> fetchAndEmit() async {
      if (controller.isClosed) return;

      final parent = await isar.nodeItems.get(parentId);
      if (parent == null) {
        if (!controller.isClosed) controller.add([]);
        return;
      }

      // Fetch children nodes
      // We assume filtered by isArchived == false (from design doc: "默认过滤掉 isArchived 为 true 的节点")
      final allChildren =
          await isar.nodeItems.filter().parentIdEqualTo(parentId).findAll();
      final activeIds = parent.children.toSet();
      final children =
          allChildren.where((child) => activeIds.contains(child.id)).toList();

      // Sort based on parent.children list
      final orderMap = {
        for (var i = 0; i < parent.children.length; i++) parent.children[i]: i,
      };

      children.sort((a, b) {
        final idxA = orderMap[a.id] ?? 999999;
        final idxB = orderMap[b.id] ?? 999999;
        return idxA.compareTo(idxB);
      });

      if (!controller.isClosed) controller.add(children);
    }

    // Subscriptions
    final parentSub = isar.nodeItems
        .watchObject(parentId)
        .listen((_) => fetchAndEmit());
    final childrenSub = isar.nodeItems
        .filter()
        .parentIdEqualTo(parentId)
        .watchLazy()
        .listen((_) => fetchAndEmit());

    controller.onCancel = () {
      parentSub.cancel();
      childrenSub.cancel();
    };

    // Initial emit
    await fetchAndEmit();

    yield* controller.stream;
  }

  Future<int> insertNode(NodeItem item, {int? parentId}) async {
    final isar = await _isar;
    return isar.writeTxn(() async {
      item.parentId = parentId;
      // Ensure timestamps
      item.createdAt = DateTime.now();
      item.updatedAt = DateTime.now();

      final id = await isar.nodeItems.put(item);

      if (parentId != null) {
        final parent = await isar.nodeItems.get(parentId);
        if (parent != null) {
          // Add to end of list
          final newChildren = List<int>.from(parent.children)..add(id);
          parent.children = newChildren;
          parent.updatedAt = DateTime.now();
          await isar.nodeItems.put(parent);
        }
      }
      return id;
    });
  }

  Future<void> updateNode(NodeItem item) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      item.updatedAt = DateTime.now();
      await isar.nodeItems.put(item);
    });
  }

  Future<void> removeNode(int nodeId) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      // 1. Remove from parent's children list
      final node = await isar.nodeItems.get(nodeId);
      if (node != null && node.parentId != null) {
        final parent = await isar.nodeItems.get(node.parentId!);
        if (parent != null) {
          parent.children = List<int>.from(parent.children)..remove(nodeId);
          parent.archivedChildren =
              List<int>.from(parent.archivedChildren)..remove(nodeId);
          parent.updatedAt = DateTime.now();
          await isar.nodeItems.put(parent);
        }
      }

      // 2. Recursive delete
      await _deleteNodeRecursive(isar, nodeId);
    });
  }

  Future<void> _deleteNodeRecursive(Isar isar, int nodeId) async {
    // Find all children
    final children = await isar.nodeItems
        .filter()
        .parentIdEqualTo(nodeId)
        .findAll();
    for (var child in children) {
      await _deleteNodeRecursive(isar, child.id);
    }
    await isar.nodeItems.delete(nodeId);
  }

  /// Special method to handle Paste/Move operation transactionally
  Future<void> moveNode(int nodeId, int newParentId) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      final node = await isar.nodeItems.get(nodeId);
      if (node == null) return;

      final oldParentId = node.parentId;
      if (oldParentId == newParentId) return; // No-op if same parent

      // 1. Remove from old parent
      var wasArchived = false;
      if (oldParentId != null) {
        final oldParent = await isar.nodeItems.get(oldParentId);
        if (oldParent != null) {
          wasArchived = oldParent.archivedChildren.contains(nodeId);
          oldParent.children = List<int>.from(oldParent.children)..remove(nodeId);
          oldParent.archivedChildren =
              List<int>.from(oldParent.archivedChildren)..remove(nodeId);
          oldParent.updatedAt = DateTime.now();
          await isar.nodeItems.put(oldParent);
        }
      }

      // 2. Add to new parent
      final newParent = await isar.nodeItems.get(newParentId);
      if (newParent != null) {
        if (wasArchived) {
          if (!newParent.archivedChildren.contains(nodeId)) {
            newParent.archivedChildren =
                List<int>.from(newParent.archivedChildren)..add(nodeId);
          }
        } else {
          if (!newParent.children.contains(nodeId)) {
            newParent.children = List<int>.from(newParent.children)..add(nodeId);
          }
        }
        newParent.updatedAt = DateTime.now();
        await isar.nodeItems.put(newParent);
      }

      // 3. Update node
      node.parentId = newParentId;
      node.updatedAt = DateTime.now();
      await isar.nodeItems.put(node);
    });
  }

  Future<void> archiveNode(int nodeId) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      final node = await isar.nodeItems.get(nodeId);
      if (node == null) return;

      final parentId = node.parentId;
      if (parentId == null) return;

      final parent = await isar.nodeItems.get(parentId);
      if (parent == null) return;

      parent.children = List<int>.from(parent.children)..remove(nodeId);
      if (!parent.archivedChildren.contains(nodeId)) {
        parent.archivedChildren =
            List<int>.from(parent.archivedChildren)..add(nodeId);
      }

      final now = DateTime.now();
      parent.updatedAt = now;
      node.updatedAt = now;
      await isar.nodeItems.put(parent);
      await isar.nodeItems.put(node);
    });
  }

  Future<void> unarchiveNode(int nodeId) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      final node = await isar.nodeItems.get(nodeId);
      if (node == null) return;

      final parentId = node.parentId;
      if (parentId == null) return;

      final parent = await isar.nodeItems.get(parentId);
      if (parent == null) return;

      parent.archivedChildren =
          List<int>.from(parent.archivedChildren)..remove(nodeId);
      if (!parent.children.contains(nodeId)) {
        // Restore to the end.
        parent.children = List<int>.from(parent.children)..add(nodeId);
      }

      final now = DateTime.now();
      parent.updatedAt = now;
      node.updatedAt = now;
      await isar.nodeItems.put(parent);
      await isar.nodeItems.put(node);
    });
  }
}
