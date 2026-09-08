import '../../application/smart_list_query.dart';
import '../../application/tree_command_service.dart';
import '../../domain/node.dart';
import '../../domain/node_id.dart';
import '../../domain/node_color.dart';
import '../../domain/node_failure.dart';
import 'node_editing_coordinator.dart';

enum PasteResult { saved, missingSource, failed }

/// Interaction policy shared by ordinary and smart lists; no UI or routing.
class NodeActionsController {
  final NodeEditingCoordinator editor;
  final TreeCommandService commands;
  final SmartListType? smartList;
  final DateTime Function() today;
  final void Function(Object) onError;
  final NodeId? Function() clipboard;
  final void Function(NodeId) copyToClipboard;
  final void Function() clearClipboard;

  NodeActionsController({
    required this.editor,
    required this.commands,
    this.smartList,
    required this.today,
    required this.onError,
    required this.clipboard,
    required this.copyToClipboard,
    required this.clearClipboard,
  });

  Future<bool> run(Future<void> Function() command) async {
    try {
      await editor.runMutation(command);
      return true;
    } catch (error) {
      onError(error);
      return false;
    }
  }

  bool _leaves(Node node) =>
      smartList != null && !SmartListQuery.includes(smartList!, node, today());

  Future<bool> _update(
    Node node,
    Node next,
    Future<void> Function() command,
  ) async {
    final leaves = _leaves(next);
    if (leaves && editor.activeNodeId == node.id) {
      await editor.finishActiveEditing(discardIfEmpty: false);
    }
    final saved = await run(command);
    if (saved &&
        !leaves &&
        editor.activeNodeId == node.id &&
        smartList != null) {
      editor.editorSession.focus(node.id);
    }
    return saved;
  }

  /// True means the completed node left a smart list and warrants undo feedback.
  Future<bool> toggleDone(Node node) async {
    final next = node.copyWith(isDone: !node.isDone);
    final saved = await _update(node, next, () => commands.toggleDone(node.id));
    return saved && _leaves(next);
  }

  Future<void> undoDone(NodeId id) async {
    await run(() => commands.toggleDone(id));
  }

  Future<void> toggleFavorite(Node node) async {
    await _update(
      node,
      node.copyWith(isFavorite: !node.isFavorite),
      () => commands.toggleFavorite(node.id),
    );
  }

  Future<void> updateDueDate(Node node, DateTime? date) async {
    await _update(
      node,
      node.copyWith(dueDate: date),
      () => commands.updateDueDate(node.id, date),
    );
  }

  Future<void> updateColor(Node node, NodeColor color) async {
    await run(() => commands.updateColor(node.id, color));
  }

  Future<void> copy(Node node) async {
    if (editor.activeNodeId == node.id) {
      await editor.flushPendingEdit(commitCurrent: true, unfocus: false);
    }
    copyToClipboard(node.id);
  }

  Future<PasteResult> paste(Node target) async {
    final source = clipboard();
    if (source == null) return PasteResult.failed;
    try {
      await editor.runMutation(
        () => commands.copySubtree(
          sourceNodeId: source,
          targetParentId: target.parentId,
          targetPosition: target.position + 1,
        ),
      );
      return PasteResult.saved;
    } on NodeNotFound catch (error) {
      if (error.nodeId == source) {
        clearClipboard();
        return PasteResult.missingSource;
      }
      onError(error);
    } catch (error) {
      onError(error);
    }
    return PasteResult.failed;
  }

  Future<void> archive(Node node) async {
    if (editor.activeNodeId != null &&
        (smartList == null || editor.activeNodeId == node.id)) {
      await editor.finishActiveEditing(discardIfEmpty: false);
    }
    await run(() => commands.archiveNode(node.id));
  }

  Future<void> restore(Node node) async {
    if (smartList == null && editor.activeNodeId != null) {
      await editor.finishActiveEditing(discardIfEmpty: false);
    }
    await run(() => commands.restoreNode(node.id));
  }

  Future<void> delete(Node node) async {
    if (smartList == null) {
      if (editor.activeNodeId != null && editor.activeNodeId != node.id) {
        await editor.flushPendingEdit(commitCurrent: true, unfocus: false);
      } else {
        await editor.drainAutosave();
      }
      editor.editorSession.unfocus();
    } else if (editor.activeNodeId == node.id) {
      await editor.finishActiveEditing(discardIfEmpty: false);
    }
    await run(() => commands.deleteSubtree(node.id));
  }
}
