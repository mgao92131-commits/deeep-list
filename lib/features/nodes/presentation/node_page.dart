import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../application/clipboard_controller.dart';
import '../application/node_page_controller.dart';
import '../domain/node.dart';
import '../domain/node_id.dart';
import 'editor_session.dart';
import 'models/visible_node_item.dart';
import 'node_list.dart';
import 'providers/visible_nodes_provider.dart';
import 'widgets/keyboard_toolbar.dart';
import 'widgets/node_action_menu.dart';
import 'widgets/smart_entries_bar.dart';

class NodePage extends ConsumerStatefulWidget {
  final NodeId? parentId;

  const NodePage({super.key, required this.parentId});

  @override
  ConsumerState<NodePage> createState() => _NodePageState();
}

class _NodePageState extends ConsumerState<NodePage>
    with RouteAware, WidgetsBindingObserver {
  static const _autosaveDelay = Duration(milliseconds: 400);

  late final EditorSession _editorSession;
  final _mutationQueue = _MutationQueue();
  final _structuralCommandsInFlight = <NodeId>{};
  Timer? _autosaveTimer;
  NodeId? _pendingAutosaveNodeId;
  String? _pendingAutosaveText;
  Future<bool>? _autosaveInFlight;
  double _lastBottomInset = 0.0;
  int? _keyboardSessionGeneration;
  bool _routeSubscribed = false;
  bool _isHandlingEnter = false;
  Timer? _enterProtectionTimer;
  List<NodeId>? _optimisticOrder;

  @override
  void initState() {
    super.initState();
    _editorSession = EditorSession();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view =
        View.maybeOf(context) ??
        WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view != null) {
      _lastBottomInset = view.viewInsets.bottom / view.devicePixelRatio;
      if (_lastBottomInset > 0) {
        _keyboardSessionGeneration = _editorSession.focusGeneration;
      }
    }
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      routeObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void didPushNext() {
    unawaited(_finishActiveEditing(discardIfEmpty: true));
  }

  @override
  void didPop() {
    unawaited(_finishActiveEditing(discardIfEmpty: true));
  }

  @override
  void didPopNext() {
    unawaited(_finishActiveEditing(discardIfEmpty: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_finishActiveEditing(discardIfEmpty: true));
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view =
        View.maybeOf(context) ??
        WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view == null) return;

    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    final keyboardWasVisible = _lastBottomInset > 0;
    final keyboardIsVisible = bottomInset > 0;

    if (keyboardIsVisible) {
      _keyboardSessionGeneration = _editorSession.focusGeneration;
    }

    if (_editorSession.hasPendingFocus) {
      _lastBottomInset = bottomInset;
      return;
    }

    if (keyboardWasVisible && !keyboardIsVisible) {
      if (_editorSession.isHandingOver) {
        _lastBottomInset = bottomInset;
        return;
      }
      if (_isHandlingEnter) {
        _lastBottomInset = bottomInset;
        return;
      }
      if (mounted) {
        final pageState = ref.read(nodePageControllerProvider(widget.parentId));
        final editingId = pageState.editingNodeId;
        final isSameGeneration =
            _keyboardSessionGeneration == null ||
            _keyboardSessionGeneration == _editorSession.focusGeneration;

        final shouldFinish =
            !_isHandlingEnter &&
            !_editorSession.isHandingOver &&
            !_editorSession.hasPendingFocus &&
            editingId != null &&
            !_editorSession.isFocused(editingId) &&
            isSameGeneration;

        if (shouldFinish && pageState.mode == PageMode.editing) {
          unawaited(_finishActiveEditing(discardIfEmpty: true));
        }
      }
    }

    _lastBottomInset = bottomInset;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _enterProtectionTimer?.cancel();
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
    }
    _editorSession.dispose();
    super.dispose();
  }

  // Issue 3: Universal single exit point for editing sessions
  // Safe empty node cleanup: only delete when activeText is confirmed non-null and trim().isEmpty.
  // Never delete when activeText == null (state unready, blur race, or controller unavailable).
  Future<bool> _finishActiveEditing({bool discardIfEmpty = true}) async {
    if (_isHandlingEnter || _editorSession.isHandingOver) return false;
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;

    final activeId =
        _editorSession.activeNodeId ??
        ref.read(nodePageControllerProvider(widget.parentId)).editingNodeId;

    if (activeId != null) {
      final activeText = _editorSession.activeText;

      if (activeText != null && activeText.trim().isEmpty && discardIfEmpty) {
        _editorSession.suppressBlurCommit(activeId);
        try {
          await _deleteEmptyNode(activeId);
        } finally {
          _editorSession.allowBlurCommit(activeId);
        }
        _editorSession.unfocus();
        if (mounted) {
          final currentMode = ref
              .read(nodePageControllerProvider(widget.parentId))
              .mode;
          if (currentMode == PageMode.editing) {
            ref
                .read(nodePageControllerProvider(widget.parentId).notifier)
                .toNormal();
          }
        }
        return true;
      }
    }

    final saved = await _flushPendingEdit(commitCurrent: true);
    if (mounted) {
      final currentMode = ref
          .read(nodePageControllerProvider(widget.parentId))
          .mode;
      if (currentMode == PageMode.editing) {
        ref
            .read(nodePageControllerProvider(widget.parentId).notifier)
            .toNormal();
      }
    }
    return saved;
  }

  Future<void> _startEditing(Node node) async {
    final currentEditingId = ref
        .read(nodePageControllerProvider(widget.parentId))
        .editingNodeId;
    if (currentEditingId == node.id) return;

    if (currentEditingId != null) {
      final activeText = _editorSession.activeText;
      if (activeText != null && activeText.trim().isEmpty) {
        _editorSession.suppressBlurCommit(currentEditingId);
        try {
          await _deleteEmptyNode(currentEditingId);
        } finally {
          _editorSession.allowBlurCommit(currentEditingId);
        }
      } else {
        await _flushPendingEdit(commitCurrent: true, unfocus: false);
      }

      if (!mounted) return;
      ref
          .read(nodePageControllerProvider(widget.parentId).notifier)
          .startEditing(node.id);
      _editorSession.handoverFocus(
        currentEditingId,
        node.id,
        cursor: node.content.length,
      );
      return;
    }

    if (!mounted) return;
    ref
        .read(nodePageControllerProvider(widget.parentId).notifier)
        .startEditing(node.id);
    _editorSession.focus(node.id, cursor: node.content.length);
  }

  Future<void> _deleteEmptyNode(NodeId nodeId) async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;
    _editorSession.suppressBlurCommit(nodeId);
    try {
      await _mutationQueue.add(
        () => ref.read(treeCommandServiceProvider).deleteSubtree(nodeId),
      );
    } catch (error) {
      if (error is! StateError || !error.message.contains('does not exist')) {
        _showMutationError(error);
      }
    } finally {
      _editorSession.allowBlurCommit(nodeId);
    }
  }

  void _scheduleAutosave(NodeId nodeId, String text) {
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

    final save = _saveContent(nodeId, text);
    _autosaveInFlight = save;
    unawaited(
      save.then((_) {
        if (identical(_autosaveInFlight, save)) {
          _autosaveInFlight = null;
        }
      }),
    );
  }

  Future<bool> _saveContent(NodeId nodeId, String text) async {
    try {
      final commands = ref.read(treeCommandServiceProvider);
      await _mutationQueue.add(() => commands.updateContent(nodeId, text));
      return true;
    } catch (error) {
      _showMutationError(error);
      return false;
    }
  }

  Future<void> _commit(NodeId nodeId, String text) async {
    if (_pendingAutosaveNodeId == nodeId) {
      _autosaveTimer?.cancel();
      _autosaveTimer = null;
      _pendingAutosaveNodeId = null;
      _pendingAutosaveText = null;
    }

    if (text.trim().isEmpty) {
      await _deleteEmptyNode(nodeId);
      if (mounted) {
        ref
            .read(nodePageControllerProvider(widget.parentId).notifier)
            .toNormal();
      }
      return;
    }

    await _saveContent(nodeId, text);
  }

  Future<T?> _runMutation<T>(Future<T> Function() mutation) async {
    try {
      return await _mutationQueue.add(mutation);
    } catch (error) {
      _showMutationError(error);
      return null;
    }
  }

  Future<void> _drainAutosaveForStructuralCommand() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;
    final inFlight = _autosaveInFlight;
    if (inFlight != null) await inFlight;
    await _mutationQueue.idle;
  }

  Future<bool> _flushPendingEdit({
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
      if (!await _saveContent(pendingNodeId, pendingText)) saved = false;
    }

    if (commitCurrent) {
      final activeNodeId = _editorSession.activeNodeId;
      final activeText = _editorSession.activeText;
      final pendingWasActive =
          pendingNodeId == activeNodeId && pendingText == activeText;
      if (activeNodeId != null && activeText != null && !pendingWasActive) {
        if (!await _saveContent(activeNodeId, activeText)) saved = false;
      }
    }

    final inFlight = _autosaveInFlight;
    if (inFlight != null && !await inFlight) saved = false;
    await _mutationQueue.idle;
    if (unfocus) {
      _editorSession.unfocus();
    }
    return saved;
  }

  // Spec 12 & 14: Enter rules
  Future<void> _handleEnter(Node node, int cursor, String text) async {
    if (node.isArchived) {
      await _commit(node.id, text);
      _editorSession.unfocus();
      if (mounted) {
        ref
            .read(nodePageControllerProvider(widget.parentId).notifier)
            .toNormal();
      }
      return;
    }

    if (!_structuralCommandsInFlight.add(node.id)) return;
    _isHandlingEnter = true;
    _enterProtectionTimer?.cancel();
    _editorSession.suppressBlurCommit(node.id);
    var handoverScheduled = false;
    try {
      await _drainAutosaveForStructuralCommand();

      // 空节点按 Enter: 单一职责，先解焦退回 Normal 状态，再安全执行单次删除
      if (text.trim().isEmpty) {
        _editorSession.unfocus();
        if (mounted) {
          ref
              .read(nodePageControllerProvider(widget.parentId).notifier)
              .toNormal();
        }
        await _deleteEmptyNode(node.id);
        return;
      }

      // 非空节点按 Enter: 保存当前完整文本，在正下方创建空同级节点，焦点无缝转移到新节点
      await _saveContent(node.id, text);
      final newNode = await _runMutation(
        () => ref
            .read(treeCommandServiceProvider)
            .createNode(
              parentId: node.parentId,
              content: '',
              position: node.position + 1,
            ),
      );
      if (newNode == null || !mounted) return;

      ref
          .read(nodePageControllerProvider(widget.parentId).notifier)
          .startEditing(newNode.id);
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
  Future<void> _handleBackspaceEmpty(
    Node node,
    List<VisibleNodeItem> items,
  ) async {
    if (!_structuralCommandsInFlight.add(node.id)) return;
    _editorSession.suppressBlurCommit(node.id);
    try {
      final previousItem = items.findPreviousItem(node.id);

      await _deleteEmptyNode(node.id);
      if (!mounted) return;

      if (previousItem != null) {
        ref
            .read(nodePageControllerProvider(widget.parentId).notifier)
            .startEditing(previousItem.id);
        _editorSession.handoverFocus(
          node.id,
          previousItem.id,
          cursor: previousItem.node.content.length,
        );
      } else {
        ref
            .read(nodePageControllerProvider(widget.parentId).notifier)
            .toNormal();
      }
    } finally {
      _editorSession.allowBlurCommit(node.id);
      _structuralCommandsInFlight.remove(node.id);
    }
  }

  // Spec 20-22: Swipe Right -> Indent
  Future<void> _handleIndent(NodeId nodeId) async {
    if (ref.read(archiveViewProvider(widget.parentId)) ==
        ArchiveView.archived) {
      return;
    }
    final isEditingThis = _editorSession.activeNodeId == nodeId;
    final text = isEditingThis ? _editorSession.activeText : null;
    if (isEditingThis && text != null && text.trim().isEmpty) {
      _editorSession.unfocus();
      if (mounted) {
        ref
            .read(nodePageControllerProvider(widget.parentId).notifier)
            .toNormal();
      }
      await _deleteEmptyNode(nodeId);
      return;
    }

    await _flushPendingEdit(commitCurrent: true);
    await _runMutation(
      () => ref.read(treeCommandServiceProvider).indentNode(nodeId),
    );
    if (mounted) {
      _editorSession.unfocus();
      ref.read(nodePageControllerProvider(widget.parentId).notifier).toNormal();
    }
  }

  // Spec 23-24: Swipe Left -> Outdent
  Future<void> _handleOutdent(NodeId nodeId) async {
    if (ref.read(archiveViewProvider(widget.parentId)) ==
        ArchiveView.archived) {
      return;
    }
    final isEditingThis = _editorSession.activeNodeId == nodeId;
    final text = isEditingThis ? _editorSession.activeText : null;
    if (isEditingThis && text != null && text.trim().isEmpty) {
      _editorSession.unfocus();
      if (mounted) {
        ref
            .read(nodePageControllerProvider(widget.parentId).notifier)
            .toNormal();
      }
      await _deleteEmptyNode(nodeId);
      return;
    }

    await _flushPendingEdit(commitCurrent: true);
    await _runMutation(
      () => ref.read(treeCommandServiceProvider).outdentNode(nodeId),
    );
    if (mounted) {
      _editorSession.unfocus();
      ref.read(nodePageControllerProvider(widget.parentId).notifier).toNormal();
    }
  }

  // Spec 31-32: Sibling Reorder Only
  Future<void> _handleReorderSiblings(
    NodeId? parentId,
    List<NodeId> orderedIds,
  ) async {
    if (ref.read(archiveViewProvider(widget.parentId)) ==
        ArchiveView.archived) {
      return;
    }
    setState(() {
      _optimisticOrder = orderedIds;
    });
    try {
      await _runMutation(
        () => ref
            .read(treeCommandServiceProvider)
            .reorderChildren(parentId: parentId, orderedIds: orderedIds),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _optimisticOrder = null;
        });
      }
      rethrow;
    }
  }

  // Blank Area Click -> create transient empty node and edit seamlessly
  Future<void> _createTrailingNode() async {
    if (ref.read(archiveViewProvider(widget.parentId)) ==
        ArchiveView.archived) {
      return;
    }
    final currentEditingId = ref
        .read(nodePageControllerProvider(widget.parentId))
        .editingNodeId;

    if (currentEditingId != null) {
      final activeText = _editorSession.activeText;
      if (activeText != null && activeText.trim().isEmpty) {
        _editorSession.suppressBlurCommit(currentEditingId);
        try {
          await _deleteEmptyNode(currentEditingId);
        } finally {
          _editorSession.allowBlurCommit(currentEditingId);
        }
      } else {
        await _flushPendingEdit(commitCurrent: true, unfocus: false);
      }

      final node = await _runMutation(
        () => ref
            .read(treeCommandServiceProvider)
            .createNode(parentId: widget.parentId, content: ''),
      );
      if (node == null || !mounted) return;
      ref
          .read(nodePageControllerProvider(widget.parentId).notifier)
          .startEditing(node.id);
      _editorSession.handoverFocus(currentEditingId, node.id, cursor: 0);
      return;
    }

    final node = await _runMutation(
      () => ref
          .read(treeCommandServiceProvider)
          .createNode(parentId: widget.parentId, content: ''),
    );
    if (node == null || !mounted) return;
    ref
        .read(nodePageControllerProvider(widget.parentId).notifier)
        .startEditing(node.id);
    _editorSession.focus(node.id, cursor: 0);
  }

  Future<void> _openNode(Node node) async {
    await _finishActiveEditing(discardIfEmpty: true);
    if (!mounted) return;
    context.push('/node/${node.id}');
  }

  Future<void> _copyNode(Node node) async {
    final currentEditingId = ref
        .read(nodePageControllerProvider(widget.parentId))
        .editingNodeId;

    if (currentEditingId == node.id) {
      await _flushPendingEdit(commitCurrent: true, unfocus: false);
    }

    ref.read(clipboardControllerProvider.notifier).copy(node.id);
  }

  Future<void> _openActionMenu(Node node, Offset position) async {
    final clipboardNodeId = ref.read(clipboardControllerProvider);
    final canPaste = clipboardNodeId != null;

    await NodeActionMenu.show(
      context,
      position: position,
      node: node,
      canPaste: canPaste,
      onCopy: () => unawaited(_copyNode(node)),
      onPaste: canPaste
          ? () async {
              try {
                await _mutationQueue.add(
                  () => ref
                      .read(treeCommandServiceProvider)
                      .copySubtree(
                        sourceNodeId: clipboardNodeId,
                        targetParentId: node.parentId,
                        targetPosition: node.position + 1,
                      ),
                );
              } on StateError {
                ref.read(clipboardControllerProvider.notifier).clear();
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('复制的节点已不存在')));
                }
              } catch (error) {
                _showMutationError(error);
              }
            }
          : null,
      onArchive: () async {
        final currentEditingId = ref
            .read(nodePageControllerProvider(widget.parentId))
            .editingNodeId;
        if (currentEditingId != null) {
          await _finishActiveEditing(discardIfEmpty: false);
        }
        await _runMutation(
          () => ref.read(treeCommandServiceProvider).archiveNode(node.id),
        );
        if (mounted) {
          ref
              .read(nodePageControllerProvider(widget.parentId).notifier)
              .toNormal();
        }
      },
      onRestore: () async {
        final currentEditingId = ref
            .read(nodePageControllerProvider(widget.parentId))
            .editingNodeId;
        if (currentEditingId != null) {
          await _finishActiveEditing(discardIfEmpty: false);
        }
        await _runMutation(
          () => ref.read(treeCommandServiceProvider).restoreNode(node.id),
        );
        if (mounted) {
          ref
              .read(nodePageControllerProvider(widget.parentId).notifier)
              .toNormal();
        }
      },
      onDelete: () async {
        final currentEditingId = ref
            .read(nodePageControllerProvider(widget.parentId))
            .editingNodeId;
        if (currentEditingId != null) {
          _editorSession.unfocus();
          if (mounted) {
            ref
                .read(nodePageControllerProvider(widget.parentId).notifier)
                .toNormal();
          }
        }
        await _runMutation(
          () => ref.read(treeCommandServiceProvider).deleteSubtree(node.id),
        );
      },
    );
  }

  Future<void> _handleBack() async {
    final pageState = ref.read(nodePageControllerProvider(widget.parentId));
    final controller = ref.read(
      nodePageControllerProvider(widget.parentId).notifier,
    );

    switch (pageState.mode) {
      case PageMode.editing:
        await _finishActiveEditing(discardIfEmpty: true);
        break;
      case PageMode.dragging:
        controller.toNormal();
        break;
      case PageMode.normal:
        if (mounted && context.canPop()) {
          context.pop();
        }
        break;
    }
  }

  void _showMutationError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not save that change: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodesAsync = ref.watch(visibleNodesProvider(widget.parentId));
    final pageState = ref.watch(nodePageControllerProvider(widget.parentId));
    final archiveView = ref.watch(archiveViewProvider(widget.parentId));
    final archivedCount = ref.watch(archivedCountProvider(widget.parentId));
    final parent = widget.parentId == null
        ? null
        : ref.watch(nodeProvider(widget.parentId!)).value;

    final isNormal = pageState.isNormal;
    final isRoot = widget.parentId == null;

    ref.listen<int>(archivedCountProvider(widget.parentId), (previous, next) {
      if (next == 0) {
        final currentView = ref.read(archiveViewProvider(widget.parentId));
        if (currentView == ArchiveView.archived) {
          ref
              .read(archiveViewProvider(widget.parentId).notifier)
              .setView(ArchiveView.active);
        }
      }
    });

    final baseTitle = isRoot ? 'DeepList' : parent?.content ?? '';
    final displayTitle = archiveView == ArchiveView.archived
        ? '$baseTitle · 已归档'
        : baseTitle;

    return PopScope<void>(
      canPop: isNormal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: isRoot ? null : 48,
          titleSpacing: isRoot ? 16 : 0,
          leading: isRoot
              ? null
              : IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => unawaited(_handleBack()),
                ),
          title: Text(
            displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          actions: [
            if (archivedCount > 0 || archiveView == ArchiveView.archived)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: '更多',
                onSelected: (value) {
                  if (value == 'toggle_archive') {
                    ref
                        .read(archiveViewProvider(widget.parentId).notifier)
                        .toggle();
                  }
                },
                itemBuilder: (context) {
                  if (archiveView == ArchiveView.active) {
                    return [
                      const PopupMenuItem(
                        value: 'toggle_archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('查看已归档'),
                          ],
                        ),
                      ),
                    ];
                  } else {
                    return [
                      const PopupMenuItem(
                        value: 'toggle_archive',
                        child: Row(
                          children: [
                            Icon(Icons.unarchive_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('查看未归档'),
                          ],
                        ),
                      ),
                    ];
                  }
                },
              ),
          ],
        ),
        body: nodesAsync.when(
          data: (items) {
            var displayItems = items;
            final optimistic = _optimisticOrder;
            if (optimistic != null) {
              final currentIds = items.map((it) => it.id).toList();
              if (listEquals(currentIds, optimistic)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _optimisticOrder != null) {
                    setState(() {
                      _optimisticOrder = null;
                    });
                  }
                });
              } else {
                final itemMap = {for (final it in items) it.id: it};
                final sorted = <VisibleNodeItem>[];
                for (final id in optimistic) {
                  final it = itemMap.remove(id);
                  if (it != null) sorted.add(it);
                }
                sorted.addAll(itemMap.values);
                displayItems = [
                  for (var i = 0; i < sorted.length; i++)
                    sorted[i].copyWith(
                      hasPreviousSibling: i > 0,
                      previousSiblingId: i > 0 ? sorted[i - 1].id : null,
                      isLastInParent: i == sorted.length - 1,
                    ),
                ];
              }
            }

            final activeItem = pageState.editingNodeId != null
                ? displayItems.findItem(pageState.editingNodeId!)
                : null;

            final showSmartEntries =
                isRoot && archiveView == ArchiveView.active;

            return Column(
              children: [
                if (showSmartEntries)
                  SmartEntriesBar(
                    onTodayTap: () => context.push('/today'),
                    onFavoritesTap: () => context.push('/favorites'),
                    onDueDatesTap: () => context.push('/due-dates'),
                  ),
                Expanded(
                  child: NodeList(
                    items: displayItems,
                    parentId: widget.parentId,
                    isArchivedView: archiveView == ArchiveView.archived,
                    editingNodeId: pageState.editingNodeId,
                    editorSession: _editorSession,
                    onLongPress: (node, position) =>
                        unawaited(_openActionMenu(node, position)),
                    onStartEditing: _startEditing,
                    onCommit: _commit,
                    onChanged: (node, text) => _scheduleAutosave(node.id, text),
                    onBlur: (text) {
                      if (_isHandlingEnter || _editorSession.isHandingOver) {
                        return;
                      }
                      if (text.trim().isEmpty) {
                        unawaited(_finishActiveEditing(discardIfEmpty: true));
                      }
                    },
                    onEnter: (node, cursor, text) =>
                        _handleEnter(node, cursor, text),
                    onBackspaceEmpty: (node) =>
                        _handleBackspaceEmpty(node, displayItems),
                    onNavigate: _openNode,
                    onIndent: _handleIndent,
                    onOutdent: _handleOutdent,
                    onReorderStart: (id) {
                      ref
                          .read(
                            nodePageControllerProvider(
                              widget.parentId,
                            ).notifier,
                          )
                          .startDragging(id);
                    },
                    onReorderEnd: () {
                      ref
                          .read(
                            nodePageControllerProvider(
                              widget.parentId,
                            ).notifier,
                          )
                          .toNormal();
                    },
                    onReorderSiblings: _handleReorderSiblings,
                    onBlankAreaTap: () => unawaited(_createTrailingNode()),
                  ),
                ),
                // Keyboard Toolbar above keyboard during Editing
                if (pageState.mode == PageMode.editing && activeItem != null)
                  KeyboardToolbar(
                    activeNodeId: activeItem.id,
                    currentColor: activeItem.node.color,
                    isDone: activeItem.isDone,
                    isFavorite: activeItem.node.isFavorite,
                    dueDate: activeItem.node.dueDate,
                    onColorSelected: (color) {
                      unawaited(
                        _runMutation(
                          () => ref
                              .read(treeCommandServiceProvider)
                              .updateColor(activeItem.id, color),
                        ),
                      );
                    },
                    onToggleDone: () {
                      unawaited(
                        _runMutation(
                          () => ref
                              .read(treeCommandServiceProvider)
                              .toggleDone(activeItem.id),
                        ),
                      );
                    },
                    onToggleFavorite: () {
                      unawaited(
                        _runMutation(
                          () => ref
                              .read(treeCommandServiceProvider)
                              .toggleFavorite(activeItem.id),
                        ),
                      );
                    },
                    onDueDateChanged: (date) {
                      unawaited(
                        _runMutation(
                          () => ref
                              .read(treeCommandServiceProvider)
                              .updateDueDate(activeItem.id, date),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('Unable to load nodes: $error')),
        ),
      ),
    );
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
