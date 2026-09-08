import 'dart:async';

import '../../application/tree_command_service.dart';
import '../../domain/node.dart';
import '../../domain/node_failure.dart';
import '../../domain/node_id.dart';
import '../editor_session.dart';
import 'editing_controller.dart';
import 'editor_keyboard_policy.dart';

class NodeEditingCoordinator {
  final TreeCommandService treeCommandService;
  final EditorSession editorSession;
  final void Function(Object error) onError;

  final _mutationQueue = _MutationQueue();
  Timer? _autosaveTimer;
  NodeId? _pendingAutosaveNodeId;
  String? _pendingAutosaveText;
  Future<bool>? _autosaveInFlight;
  Future<bool>? _finishInFlight;
  late final _keyboard = EditorKeyboardPolicy(
    editorSession,
    () => isHandlingEnter,
  );
  bool isHandlingEnter = false;

  static const _autosaveDelay = Duration(milliseconds: 400);

  NodeEditingCoordinator({
    required this.treeCommandService,
    EditorSession? editorSession,
    required this.onError,
    EditingController? editing,
  }) : editorSession = editorSession ?? EditorSession(editing: editing);

  EditingController get editing => editorSession.editing;
  NodeId? get activeNodeId => editing.value.editingNodeId;

  Future<void> get idleQueue => _mutationQueue.idle;

  Future<T> runMutation<T>(Future<T> Function() mutation) {
    return _mutationQueue.add(mutation);
  }

  void initBottomInset(double inset) => _keyboard.initBottomInset(inset);

  void scheduleAutosave(NodeId nodeId, String text) {
    _pendingAutosaveNodeId = nodeId;
    _pendingAutosaveText = text;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, _startPendingAutosave);
  }

  void _startPendingAutosave() {
    _autosaveTimer = null;
    final nodeId = _pendingAutosaveNodeId;
    final text = _pendingAutosaveText;
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;
    if (nodeId == null || text == null) return;

    final save = saveContent(nodeId, text);
    _autosaveInFlight = save;
    unawaited(
      save.then((_) {
        if (identical(_autosaveInFlight, save)) {
          _autosaveInFlight = null;
        }
      }),
    );
  }

  Future<bool> saveContent(NodeId nodeId, String text) async {
    try {
      await _mutationQueue.add(
        () => editing.saving(
          () => treeCommandService.updateContent(nodeId, text),
        ),
      );
      return true;
    } catch (error) {
      onError(error);
      return false;
    }
  }

  Future<void> commit(NodeId nodeId, String text) async {
    if (_pendingAutosaveNodeId == nodeId) {
      _autosaveTimer?.cancel();
      _autosaveTimer = null;
      _pendingAutosaveNodeId = null;
      _pendingAutosaveText = null;
    }

    if (text.trim().isEmpty) {
      await deleteEmptyNode(nodeId);
      editorSession.unfocus();
      return;
    }

    await saveContent(nodeId, text);
  }

  Future<bool> flushPendingEdit({
    required bool commitCurrent,
    bool unfocus = true,
  }) async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    final pendingNodeId = _pendingAutosaveNodeId;
    final pendingText = _pendingAutosaveText;
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;

    var saved = true;
    if (commitCurrent && pendingNodeId != null && pendingText != null) {
      if (!await saveContent(pendingNodeId, pendingText)) saved = false;
    }

    if (commitCurrent) {
      final currentActiveId = activeNodeId;
      final activeText = editorSession.activeText;
      final pendingWasActive =
          pendingNodeId == currentActiveId && pendingText == activeText;
      if (currentActiveId != null && activeText != null && !pendingWasActive) {
        if (!await saveContent(currentActiveId, activeText)) saved = false;
      }
    }

    final inFlight = _autosaveInFlight;
    if (inFlight != null && !await inFlight) saved = false;
    await _mutationQueue.idle;
    if (unfocus) {
      editorSession.unfocus();
    }
    return saved;
  }

  Future<void> drainAutosave() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;
    final inFlight = _autosaveInFlight;
    if (inFlight != null) await inFlight;
    await _mutationQueue.idle;
  }

  Future<void> startEditing(Node node) async {
    final currentEditingId = activeNodeId;
    if (currentEditingId == node.id) return;

    if (currentEditingId != null) {
      final activeText = editorSession.activeText;
      if (activeText != null && activeText.trim().isEmpty) {
        editorSession.suppressBlurCommit(currentEditingId);
        try {
          await deleteEmptyNode(currentEditingId);
        } finally {
          editorSession.allowBlurCommit(currentEditingId);
        }
      } else {
        await flushPendingEdit(commitCurrent: true, unfocus: false);
      }

      editorSession.handoverFocus(
        currentEditingId,
        node.id,
        cursor: node.content.length,
      );
      return;
    }

    editorSession.focus(node.id, cursor: node.content.length);
  }

  Future<bool> finishActiveEditing({bool discardIfEmpty = true}) {
    final inFlight = _finishInFlight;
    if (inFlight != null) return inFlight;

    final finish = _finishActiveEditing(discardIfEmpty: discardIfEmpty);
    _finishInFlight = finish;
    unawaited(
      finish.then<void>(
        (_) {
          if (identical(_finishInFlight, finish)) _finishInFlight = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_finishInFlight, finish)) _finishInFlight = null;
        },
      ),
    );
    return finish;
  }

  Future<bool> _finishActiveEditing({required bool discardIfEmpty}) async {
    if (isHandlingEnter || editorSession.isHandingOver) return false;
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;

    final activeId = activeNodeId;

    if (activeId != null) {
      final activeText = editorSession.activeText;

      if (activeText != null && activeText.trim().isEmpty && discardIfEmpty) {
        editorSession.suppressBlurCommit(activeId);
        try {
          await deleteEmptyNode(activeId);
        } finally {
          editorSession.allowBlurCommit(activeId);
        }
        editorSession.unfocus();
        return true;
      }
    }

    final saved = await flushPendingEdit(commitCurrent: true);
    return saved;
  }

  Future<void> deleteEmptyNode(NodeId nodeId) async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;
    editorSession.suppressBlurCommit(nodeId);
    try {
      await _mutationQueue.add(() => treeCommandService.deleteSubtree(nodeId));
    } catch (error) {
      if (error is! NodeNotFound) {
        onError(error);
      }
    } finally {
      editorSession.allowBlurCommit(nodeId);
    }
  }

  void handleMetricsChange({
    required double bottomInset,
    required bool isCurrentlyEditing,
  }) {
    if (_keyboard.shouldFinishEditing(
      bottomInset: bottomInset,
      isCurrentlyEditing: isCurrentlyEditing,
    )) {
      unawaited(finishActiveEditing());
    }
  }

  void handleLifecyclePause() {
    unawaited(finishActiveEditing(discardIfEmpty: true));
  }

  void dispose() {
    _autosaveTimer?.cancel();
    editorSession.dispose();
  }
}

class _MutationQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> add<T>(Future<T> Function() operation) {
    final result = _tail.then<T>((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<void> get idle => _tail;
}
