import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../application/node_page_controller.dart';
import '../domain/node.dart';
import '../domain/node_id.dart';
import 'editor_session.dart';
import 'models/visible_node_item.dart';
import 'node_list.dart';
import 'providers/visible_nodes_provider.dart';
import 'widgets/keyboard_toolbar.dart';
import 'widgets/selection_toolbar.dart';

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
  bool _routeSubscribed = false;
  bool _isHandlingEnter = false;
  Timer? _enterProtectionTimer;

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

    if (keyboardWasVisible && !keyboardIsVisible) {
      if (_isHandlingEnter) {
        _lastBottomInset = bottomInset;
        return;
      }
      if (mounted) {
        final currentMode = ref
            .read(nodePageControllerProvider(widget.parentId))
            .mode;
        if (currentMode == PageMode.editing) {
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
    if (_isHandlingEnter) return false;
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
    if (currentEditingId != null && currentEditingId != node.id) {
      await _finishActiveEditing(discardIfEmpty: true);
    }

    if (!mounted) return;
    ref
        .read(nodePageControllerProvider(widget.parentId).notifier)
        .startEditing(node.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editorSession.focus(node.id, cursor: node.content.length);
    });
  }

  Future<void> _selectNode(NodeId nodeId) async {
    final currentEditingId = ref
        .read(nodePageControllerProvider(widget.parentId))
        .editingNodeId;
    if (currentEditingId != null) {
      await _finishActiveEditing(discardIfEmpty: true);
    }

    if (!mounted) return;
    ref
        .read(nodePageControllerProvider(widget.parentId).notifier)
        .selectNode(nodeId);
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

  Future<bool> _flushPendingEdit({required bool commitCurrent}) async {
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
    _editorSession.unfocus();
    return saved;
  }

  // Spec 12 & 14: Enter rules
  Future<void> _handleEnter(Node node, int cursor, String text) async {
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
      _editorSession.focus(newNode.id, cursor: 0);

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
        _editorSession.focus(
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
    await _runMutation(
      () => ref
          .read(treeCommandServiceProvider)
          .reorderChildren(parentId: parentId, orderedIds: orderedIds),
    );
  }

  // Spec 18-19 & Issue 4: Blank Area Click -> 1 tap creates transient empty node and edits
  Future<void> _createTrailingNode() async {
    await _finishActiveEditing(discardIfEmpty: true);
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

  Future<void> _deleteSelectedNode(NodeId nodeId) async {
    await _runMutation(
      () => ref.read(treeCommandServiceProvider).deleteSubtree(nodeId),
    );
    if (mounted) {
      ref.read(nodePageControllerProvider(widget.parentId).notifier).toNormal();
    }
  }

  // Spec 35: Back behavior
  Future<void> _handleBack() async {
    final pageState = ref.read(nodePageControllerProvider(widget.parentId));
    final controller = ref.read(
      nodePageControllerProvider(widget.parentId).notifier,
    );

    switch (pageState.mode) {
      case PageMode.editing:
        final activeId = pageState.editingNodeId;
        final activeText = _editorSession.activeText;
        if (activeId != null &&
            (activeText == null || activeText.trim().isEmpty)) {
          await _deleteEmptyNode(activeId);
          controller.toNormal();
        } else {
          await _flushPendingEdit(commitCurrent: true);
          if (activeId != null) {
            controller.selectNode(activeId);
          } else {
            controller.toNormal();
          }
        }
        break;
      case PageMode.selected:
        controller.toNormal();
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
    final parent = widget.parentId == null
        ? null
        : ref.watch(nodeProvider(widget.parentId!)).value;

    final isNormal = pageState.isNormal;

    return PopScope<void>(
      canPop: isNormal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.parentId == null ? 'DeepList' : parent?.content ?? '',
          ),
          leading: widget.parentId == null
              ? null
              : IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => unawaited(_handleBack()),
                ),
        ),
        body: nodesAsync.when(
          data: (items) {
            final activeItem = pageState.editingNodeId != null
                ? items.findItem(pageState.editingNodeId!)
                : null;

            return Column(
              children: [
                Expanded(
                  child: NodeList(
                    items: items,
                    parentId: widget.parentId,
                    selectedNodeId: pageState.selectedNodeId,
                    editingNodeId: pageState.editingNodeId,
                    editorSession: _editorSession,
                    onSelect: (id) => unawaited(_selectNode(id)),
                    onStartEditing: _startEditing,
                    onCommit: _commit,
                    onChanged: (node, text) => _scheduleAutosave(node.id, text),
                    onBlur: (text) {
                      if (_isHandlingEnter) return;
                      if (text.trim().isEmpty) {
                        unawaited(_finishActiveEditing(discardIfEmpty: true));
                      }
                    },
                    onEnter: (node, cursor, text) =>
                        _handleEnter(node, cursor, text),
                    onBackspaceEmpty: (node) =>
                        _handleBackspaceEmpty(node, items),
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
                // Spec 29: Keyboard Toolbar above keyboard during Editing
                if (pageState.mode == PageMode.editing && activeItem != null)
                  KeyboardToolbar(
                    canOutdent: activeItem.canOutdent,
                    canIndent: activeItem.canIndent,
                    onOutdent: () => unawaited(_handleOutdent(activeItem.id)),
                    onIndent: () => unawaited(_handleIndent(activeItem.id)),
                    onDone: () async {
                      await _finishActiveEditing(discardIfEmpty: true);
                    },
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('Unable to load nodes: $error')),
        ),
        // Spec 33 & Issue 1: Selected Bottom Toolbar (hidden when dragging)
        floatingActionButton:
            pageState.mode == PageMode.selected &&
                !pageState.isDragging &&
                pageState.selectedNodeId != null
            ? SelectionToolbar(
                onDelete: () =>
                    unawaited(_deleteSelectedNode(pageState.selectedNodeId!)),
                onMore: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.archive_outlined),
                            title: const Text('归档节点'),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              final id = pageState.selectedNodeId;
                              if (id != null) {
                                await ref
                                    .read(treeCommandServiceProvider)
                                    .archiveNode(id);
                                if (mounted) {
                                  ref
                                      .read(
                                        nodePageControllerProvider(
                                          widget.parentId,
                                        ).notifier,
                                      )
                                      .toNormal();
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
