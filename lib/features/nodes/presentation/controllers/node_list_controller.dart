import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../application/tree_command_service.dart';
import '../../domain/node.dart';
import '../../domain/node_id.dart';
import '../editor_session.dart';
import '../models/visible_node_item.dart';
import 'node_editing_coordinator.dart';

class NodeListController extends ChangeNotifier {
  final NodeEditingCoordinator editor;
  final TreeCommandService commands;
  final NodeId? parentId;
  final bool Function() isArchived;
  final void Function(Object) onError;
  final _structuralCommandsInFlight = <NodeId>{};
  Timer? _enterProtectionTimer;
  List<NodeId>? _optimisticOrder;
  bool mounted = true;
  EditorSession get _editorSession => editor.editorSession;
  set _isHandlingEnter(bool active) => editor.isHandlingEnter = active;
  NodeListController({
    required this.editor,
    required this.commands,
    required this.parentId,
    required this.isArchived,
    required this.onError,
  });

  Future<T?> _runMutation<T>(Future<T> Function() mutation) async {
    try {
      return await editor.runMutation(mutation);
    } catch (error) {
      onError(error);
      return null;
    }
  }

  List<VisibleNodeItem> displayItems(List<VisibleNodeItem> items) {
    final optimistic = _optimisticOrder;
    if (optimistic == null) return items;
    if (listEquals(items.map((item) => item.id).toList(), optimistic)) {
      _optimisticOrder = null;
      return items;
    }
    final map = {for (final item in items) item.id: item};
    final sorted = <VisibleNodeItem>[];
    for (final id in optimistic) {
      final item = map.remove(id);
      if (item != null) sorted.add(item);
    }
    sorted.addAll(map.values);
    return [
      for (var i = 0; i < sorted.length; i++)
        sorted[i].copyWith(
          hasPreviousSibling: i > 0,
          previousSiblingId: i > 0 ? sorted[i - 1].id : null,
          isLastInParent: i == sorted.length - 1,
        ),
    ];
  }

  @override
  void dispose() {
    mounted = false;
    _enterProtectionTimer?.cancel();
    super.dispose();
  }

  // Spec 12 & 14: Enter rules
  Future<void> enter(Node node, int cursor, String text) async {
    if (node.isArchived) {
      await editor.commit(node.id, text);
      _editorSession.unfocus();
      if (mounted) {
        editor.editing.endEditing();
      }
      return;
    }

    if (!_structuralCommandsInFlight.add(node.id)) return;
    _isHandlingEnter = true;
    _enterProtectionTimer?.cancel();
    _editorSession.suppressBlurCommit(node.id);
    var handoverScheduled = false;
    try {
      await editor.drainAutosave();

      // 空节点按 Enter: 单一职责，先解焦退回 Normal 状态，再安全执行单次删除
      if (text.trim().isEmpty) {
        _editorSession.unfocus();
        if (mounted) {
          editor.editing.endEditing();
        }
        await editor.deleteEmptyNode(node.id);
        return;
      }

      // 非空节点按 Enter: 保存当前完整文本，在正下方创建空同级节点，焦点无缝转移到新节点
      await editor.saveContent(node.id, text);
      final newNode = await _runMutation(
        () => commands.createNode(
          parentId: node.parentId,
          content: '',
          position: node.position + 1,
        ),
      );
      if (newNode == null || !mounted) return;

      editor.editing.startEditing(newNode.id);
      _editorSession.handoverFocus(node.id, newNode.id, cursor: 0);

      handoverScheduled = true;
      _enterProtectionTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isHandlingEnter = false;
        }
      });
    } finally {
      _editorSession.allowBlurCommit(node.id);
      _structuralCommandsInFlight.remove(node.id);
      if (!handoverScheduled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _isHandlingEnter = false;
          }
        });
      }
    }
  }

  // Spec 17: Backspace on empty node -> delete empty node & edit previous
  Future<void> backspaceEmpty(Node node, List<VisibleNodeItem> items) async {
    if (!_structuralCommandsInFlight.add(node.id)) return;
    _editorSession.suppressBlurCommit(node.id);
    try {
      final previousItem = items.findPreviousItem(node.id);

      await editor.deleteEmptyNode(node.id);
      if (!mounted) return;

      if (previousItem != null) {
        editor.editing.startEditing(previousItem.id);
        _editorSession.handoverFocus(
          node.id,
          previousItem.id,
          cursor: previousItem.node.content.length,
        );
      } else {
        editor.editing.endEditing();
      }
    } finally {
      _editorSession.allowBlurCommit(node.id);
      _structuralCommandsInFlight.remove(node.id);
    }
  }

  // Spec 20-22: Swipe Right -> Indent
  Future<void> indent(NodeId nodeId) async {
    if (isArchived()) {
      return;
    }
    final isEditingThis = _editorSession.activeNodeId == nodeId;
    final text = isEditingThis ? _editorSession.activeText : null;
    if (isEditingThis && text != null && text.trim().isEmpty) {
      _editorSession.unfocus();
      if (mounted) {
        editor.editing.endEditing();
      }
      await editor.deleteEmptyNode(nodeId);
      return;
    }

    await editor.flushPendingEdit(commitCurrent: true);
    await _runMutation(() => commands.indentNode(nodeId));
    if (mounted) {
      _editorSession.unfocus();
      editor.editing.endEditing();
    }
  }

  // Spec 23-24: Swipe Left -> Outdent
  Future<void> outdent(NodeId nodeId) async {
    if (isArchived()) {
      return;
    }
    final isEditingThis = _editorSession.activeNodeId == nodeId;
    final text = isEditingThis ? _editorSession.activeText : null;
    if (isEditingThis && text != null && text.trim().isEmpty) {
      _editorSession.unfocus();
      if (mounted) {
        editor.editing.endEditing();
      }
      await editor.deleteEmptyNode(nodeId);
      return;
    }

    await editor.flushPendingEdit(commitCurrent: true);
    await _runMutation(() => commands.outdentNode(nodeId));
    if (mounted) {
      _editorSession.unfocus();
      editor.editing.endEditing();
    }
  }

  // Spec 31-32: Sibling Reorder Only
  Future<void> reorder(NodeId? parentId, List<NodeId> orderedIds) async {
    if (isArchived()) {
      return;
    }
    _optimisticOrder = List.of(orderedIds);
    notifyListeners();
    try {
      await editor.runMutation(
        () => commands.reorderChildren(
          parentId: parentId,
          orderedIds: orderedIds,
        ),
      );
    } catch (error) {
      if (mounted) {
        _optimisticOrder = null;
        notifyListeners();
      }
      onError(error);
    }
  }

  // Blank Area Click -> create transient empty node and edit seamlessly
  Future<void> createTrailingNode() async {
    if (isArchived()) {
      return;
    }
    final currentEditingId = editor.activeNodeId;

    if (currentEditingId != null) {
      final activeText = _editorSession.activeText;
      if (activeText != null && activeText.trim().isEmpty) {
        _editorSession.suppressBlurCommit(currentEditingId);
        try {
          await editor.deleteEmptyNode(currentEditingId);
        } finally {
          _editorSession.allowBlurCommit(currentEditingId);
        }
      } else {
        await editor.flushPendingEdit(commitCurrent: true, unfocus: false);
      }

      final node = await _runMutation(
        () => commands.createNode(parentId: parentId, content: ''),
      );
      if (node == null || !mounted) return;
      editor.editing.startEditing(node.id);
      _editorSession.handoverFocus(currentEditingId, node.id, cursor: 0);
      return;
    }

    final node = await _runMutation(
      () => commands.createNode(parentId: parentId, content: ''),
    );
    if (node == null || !mounted) return;
    editor.editing.startEditing(node.id);
    _editorSession.focus(node.id, cursor: 0);
  }
}
