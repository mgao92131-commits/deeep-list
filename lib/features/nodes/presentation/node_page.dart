import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import 'controllers/editor_lifecycle.dart';
import '../../../core/time/today_provider.dart';
import '../presentation/controllers/clipboard_controller.dart';
import '../presentation/controllers/node_page_controller.dart';
import '../domain/node.dart';
import '../domain/node_id.dart';
import 'controllers/node_editing_coordinator.dart';
import 'controllers/node_list_controller.dart';
import 'controllers/node_actions_controller.dart';
import 'editor_session.dart';
import 'models/visible_node_item.dart';
import 'node_list.dart';
import 'providers/visible_nodes_provider.dart';
import 'widgets/keyboard_toolbar.dart';
import 'widgets/node_action_menu.dart';
import 'widgets/smart_entries_bar.dart';
import 'widgets/archive_status_bar.dart';

class NodePage extends ConsumerStatefulWidget {
  final NodeId? parentId;

  const NodePage({super.key, required this.parentId});

  @override
  ConsumerState<NodePage> createState() => _NodePageState();
}

class _NodePageState extends ConsumerState<NodePage> {
  late final NodeEditingCoordinator _coordinator;
  late final NodePageController _pageController;
  late final NodeActionsController _actions;
  late final NodeListController _list;
  late final EditorLifecycle _lifecycle;

  EditorSession get _editorSession => _coordinator.editorSession;
  bool get _isHandlingEnter => _coordinator.isHandlingEnter;

  @override
  void initState() {
    super.initState();
    _pageController = ref.read(
      nodePageControllerProvider(widget.parentId).notifier,
    );
    _coordinator = NodeEditingCoordinator(
      treeCommandService: ref.read(treeCommandServiceProvider),
      onError: _showMutationError,
      editing: _pageController.editing,
    );
    _actions = NodeActionsController(
      editor: _coordinator,
      commands: ref.read(treeCommandServiceProvider),

      today: () => ref.read(todayProvider),
      onError: _showMutationError,
      clipboard: () => ref.read(clipboardControllerProvider),
      copyToClipboard: (id) =>
          ref.read(clipboardControllerProvider.notifier).copy(id),
      clearClipboard: () =>
          ref.read(clipboardControllerProvider.notifier).clear(),
    );
    _list = NodeListController(
      editor: _coordinator,
      commands: ref.read(treeCommandServiceProvider),
      parentId: widget.parentId,
      isArchived: () =>
          ref.read(archiveViewProvider(widget.parentId)) ==
          ArchiveView.archived,
      onError: _showMutationError,
    )..addListener(_listChanged);
    _lifecycle = EditorLifecycle(_coordinator);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lifecycle.attach(context);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _list.removeListener(_listChanged);
    _list.dispose();
    _pageController.detachEditingSync();
    _coordinator.dispose();
    super.dispose();
  }

  Future<bool> _finishActiveEditing({bool discardIfEmpty = true}) =>
      _coordinator.finishActiveEditing(discardIfEmpty: discardIfEmpty);

  Future<void> _startEditing(Node node) => _coordinator.startEditing(node);

  void _listChanged() {
    if (mounted) setState(() {});
  }

  void _scheduleAutosave(NodeId id, String text) =>
      _coordinator.scheduleAutosave(id, text);
  Future<void> _commit(NodeId id, String text) => _coordinator.commit(id, text);

  void _restoreFocus(NodeId nodeId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editorSession.activeNodeId == nodeId) {
        _editorSession.focus(nodeId);
      }
    });
  }

  Future<void> _openNode(Node node) async {
    await _finishActiveEditing(discardIfEmpty: true);
    if (!mounted) return;
    context.push('/node/${node.id}');
  }

  Future<void> _openActionMenu(Node node, Offset position) async {
    final clipboardNodeId = ref.read(clipboardControllerProvider);
    final canPaste = clipboardNodeId != null;

    await NodeActionMenu.show(
      context,
      position: position,
      node: node,
      canPaste: canPaste,
      onCopy: () => unawaited(_actions.copy(node)),
      onPaste: canPaste
          ? () async {
              final result = await _actions.paste(node);
              if (mounted && result == PasteResult.missingSource) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('复制的节点已不存在')));
              }
            }
          : null,
      onArchive: () => _actions.archive(node),
      onRestore: () => _actions.restore(node),
      onDelete: () => _actions.delete(node),
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

    final baseTitle = parent?.content ?? '';

    return PopScope<void>(
      canPop: isNormal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: isRoot,
          leadingWidth: 48,
          titleSpacing: 0,
          leading: isRoot
              ? const SizedBox(width: 48)
              : IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => unawaited(_handleBack()),
                ),
          title: isRoot
              ? SmartEntriesBar(
                  onTodayTap: () => context.push('/today'),
                  onFavoritesTap: () => context.push('/favorites'),
                  onDueDatesTap: () => context.push('/due-dates'),
                )
              : Text(
                  baseTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
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
              )
            else if (isRoot)
              const SizedBox(width: 48),
          ],
        ),
        body: nodesAsync.when(
          data: (items) {
            final displayItems = _list.displayItems(items);

            final activeItem = pageState.editingNodeId != null
                ? displayItems.findItem(pageState.editingNodeId!)
                : null;

            return Column(
              children: [
                if (archiveView == ArchiveView.archived)
                  ArchiveStatusBar(
                    count: archivedCount,
                    onShowActive: () => ref
                        .read(archiveViewProvider(widget.parentId).notifier)
                        .setView(ArchiveView.active),
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
                        _list.enter(node, cursor, text),
                    onBackspaceEmpty: (node) =>
                        _list.backspaceEmpty(node, displayItems),
                    onNavigate: _openNode,
                    onIndent: _list.indent,
                    onOutdent: _list.outdent,
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
                    onReorderSiblings: _list.reorder,
                    onBlankAreaTap: () => unawaited(_list.createTrailingNode()),
                  ),
                ),
                // Keyboard Toolbar above keyboard during Editing
                if (pageState.mode == PageMode.editing && activeItem != null)
                  KeyboardToolbar(
                    today: ref.watch(todayProvider),
                    activeNodeId: activeItem.id,
                    currentColor: activeItem.node.color,
                    isDone: activeItem.isDone,
                    isFavorite: activeItem.node.isFavorite,
                    dueDate: activeItem.node.dueDate,
                    onColorSelected: (color) =>
                        _actions.updateColor(activeItem.node, color),
                    onToggleDone: () => _actions.toggleDone(activeItem.node),
                    onToggleFavorite: () =>
                        _actions.toggleFavorite(activeItem.node),
                    onDueDateInteractionChanged: (active) =>
                        _editorSession.isSelectingDueDate = active,
                    onDueDateChanged: (date) =>
                        _actions.updateDueDate(activeItem.node, date),
                    onRequestRestoreFocus: () => _restoreFocus(activeItem.id),
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
