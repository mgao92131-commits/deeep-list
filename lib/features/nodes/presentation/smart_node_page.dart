import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../application/clipboard_controller.dart';
import '../domain/node.dart';
import '../domain/node_color.dart';
import '../domain/node_id.dart';
import 'controllers/node_editing_coordinator.dart';
import 'editor_session.dart';
import 'models/visible_node_item.dart';
import 'providers/smart_nodes_provider.dart';
import 'widgets/keyboard_toolbar.dart';
import 'widgets/node_action_menu.dart';
import 'widgets/node_row.dart';

class SmartNodePage extends ConsumerStatefulWidget {
  final SmartListType type;

  const SmartNodePage({super.key, required this.type});

  @override
  ConsumerState<SmartNodePage> createState() => _SmartNodePageState();
}

class _SmartNodePageState extends ConsumerState<SmartNodePage>
    with RouteAware, WidgetsBindingObserver {
  late final NodeEditingCoordinator _coordinator;
  NodeId? _editingNodeId;
  bool _routeSubscribed = false;

  EditorSession get _editorSession => _coordinator.editorSession;

  @override
  void initState() {
    super.initState();
    _coordinator = NodeEditingCoordinator(
      treeCommandService: ref.read(treeCommandServiceProvider),
      onError: _showMutationError,
      activeNodeIdProvider: () => _editingNodeId,
      onEditingStarted: (nodeId) {
        if (!mounted) return;
        setState(() {
          _editingNodeId = nodeId;
        });
      },
      onEditingEnded: () {
        if (!mounted) return;
        setState(() {
          _editingNodeId = null;
        });
      },
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view =
        View.maybeOf(context) ??
        WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view != null) {
      final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
      _coordinator.initBottomInset(bottomInset);
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
    unawaited(_coordinator.finishActiveEditing(discardIfEmpty: true));
  }

  @override
  void didPop() {
    unawaited(_coordinator.finishActiveEditing(discardIfEmpty: true));
  }

  @override
  void didPopNext() {
    unawaited(_coordinator.finishActiveEditing(discardIfEmpty: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _coordinator.handleLifecyclePause();
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
    if (mounted) {
      _coordinator.handleMetricsChange(
        bottomInset: bottomInset,
        isCurrentlyEditing: _editingNodeId != null,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
    }
    _coordinator.dispose();
    super.dispose();
  }

  String get _pageTitle {
    switch (widget.type) {
      case SmartListType.today:
        return '今天';
      case SmartListType.favorites:
        return '收藏';
      case SmartListType.dueDates:
        return '截止日期';
    }
  }

  String get _emptyMessage {
    switch (widget.type) {
      case SmartListType.today:
        return '今天没有待处理的节点';
      case SmartListType.favorites:
        return '还没有收藏节点';
      case SmartListType.dueDates:
        return '还没有设置截止日期';
    }
  }

  void _showMutationError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not save that change: $error')),
    );
  }

  bool _wouldLeaveList({
    required Node node,
    bool? isDone,
    bool? isFavorite,
    DateTime? Function()? dueDate,
  }) {
    final nextIsDone = isDone ?? node.isDone;
    if (nextIsDone) return true;

    switch (widget.type) {
      case SmartListType.favorites:
        final nextIsFavorite = isFavorite ?? node.isFavorite;
        return !nextIsFavorite;

      case SmartListType.today:
        final nextDueDate = dueDate != null ? dueDate() : node.dueDate;
        if (nextDueDate == null) return true;
        final now = DateTime.now();
        final localToday = DateTime(now.year, now.month, now.day);
        final normalized = Node.normalizeDate(nextDueDate);
        if (normalized == null) return true;
        return normalized.isAfter(localToday);

      case SmartListType.dueDates:
        final nextDueDate = dueDate != null ? dueDate() : node.dueDate;
        return nextDueDate == null;
    }
  }

  void _restoreFocus(NodeId nodeId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingNodeId == nodeId) {
        _editorSession.focus(nodeId);
      }
    });
  }

  Future<void> _handleToggleDone(Node node) async {
    final leaves = _wouldLeaveList(node: node, isDone: !node.isDone);
    if (leaves && _editingNodeId == node.id) {
      await _coordinator.finishActiveEditing(discardIfEmpty: false);
    }
    try {
      await _coordinator.runMutation(
        () => ref.read(treeCommandServiceProvider).toggleDone(node.id),
      );
    } catch (e) {
      _showMutationError(e);
    }
  }

  Future<void> _handleToggleFavorite(Node node) async {
    final leaves = _wouldLeaveList(node: node, isFavorite: !node.isFavorite);
    if (leaves && _editingNodeId == node.id) {
      await _coordinator.finishActiveEditing(discardIfEmpty: false);
    }
    try {
      await _coordinator.runMutation(
        () => ref.read(treeCommandServiceProvider).toggleFavorite(node.id),
      );
      if (!leaves && _editingNodeId == node.id) {
        _restoreFocus(node.id);
      }
    } catch (e) {
      _showMutationError(e);
    }
  }

  Future<void> _handleDueDateChanged(Node node, DateTime? newDate) async {
    final leaves = _wouldLeaveList(node: node, dueDate: () => newDate);
    if (leaves && _editingNodeId == node.id) {
      await _coordinator.finishActiveEditing(discardIfEmpty: false);
    }
    try {
      await _coordinator.runMutation(
        () => ref
            .read(treeCommandServiceProvider)
            .updateDueDate(node.id, newDate),
      );
      if (!leaves && _editingNodeId == node.id) {
        _restoreFocus(node.id);
      }
    } catch (e) {
      _showMutationError(e);
    }
  }

  Future<void> _handleColorSelected(Node node, NodeColor color) async {
    try {
      await _coordinator.runMutation(
        () => ref.read(treeCommandServiceProvider).updateColor(node.id, color),
      );
    } catch (e) {
      _showMutationError(e);
    }
  }

  Future<void> _openNode(Node node) async {
    await _coordinator.finishActiveEditing(discardIfEmpty: true);
    if (!mounted) return;
    context.push('/node/${node.id}');
  }

  Future<void> _copyNode(Node node) async {
    if (_editingNodeId == node.id) {
      await _coordinator.flushPendingEdit(commitCurrent: true, unfocus: false);
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
      onPaste: null,
      onArchive: () async {
        if (_editingNodeId == node.id) {
          await _coordinator.finishActiveEditing(discardIfEmpty: false);
        }
        try {
          await _coordinator.runMutation(
            () => ref.read(treeCommandServiceProvider).archiveNode(node.id),
          );
        } catch (e) {
          _showMutationError(e);
        }
      },
      onRestore: () async {
        try {
          await _coordinator.runMutation(
            () => ref.read(treeCommandServiceProvider).restoreNode(node.id),
          );
        } catch (e) {
          _showMutationError(e);
        }
      },
      onDelete: () async {
        if (_editingNodeId == node.id) {
          await _coordinator.finishActiveEditing(discardIfEmpty: false);
        }
        try {
          await _coordinator.runMutation(
            () => ref.read(treeCommandServiceProvider).deleteSubtree(node.id),
          );
        } catch (e) {
          _showMutationError(e);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(smartNodesProvider(widget.type));

    return PopScope<void>(
      canPop: _editingNodeId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_coordinator.finishActiveEditing(discardIfEmpty: true));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_editingNodeId != null) {
                unawaited(
                  _coordinator.finishActiveEditing(discardIfEmpty: true),
                );
              }
              if (context.canPop()) {
                context.pop();
              }
            },
          ),
          title: Text(
            _pageTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
        ),
        body: groupsAsync.when(
          data: (groups) {
            final allItems = [for (final g in groups) ...g.items];
            final activeItem = _editingNodeId != null
                ? allItems.findItem(_editingNodeId!)
                : null;

            if (allItems.isEmpty) {
              return Center(
                child: Text(
                  _emptyMessage,
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      for (final group in groups) ...[
                        if (group.title != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                              child: Text(
                                group.title!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: group.isOverdue
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = group.items[index];
                              return GestureDetector(
                                onLongPressStart: (details) {
                                  unawaited(
                                    _openActionMenu(
                                      item.node,
                                      details.globalPosition,
                                    ),
                                  );
                                },
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final pathText = ref
                                        .watch(nodePathProvider(item.node))
                                        .value;
                                    final displayItem = pathText != null
                                        ? item.copyWith(pathText: pathText)
                                        : item;
                                    return NodeRow(
                                      key: ValueKey('smart-${item.id}'),
                                      item: displayItem,
                                      isEditing: _editingNodeId == item.id,
                                      editorSession: _editorSession,
                                      enableSwipeGestures: false,
                                      onStartEditing: () =>
                                          _coordinator.startEditing(item.node),
                                      onNavigate: () => _openNode(item.node),
                                      onCommit: (text) =>
                                          _coordinator.commit(item.id, text),
                                      onChanged: (text) => _coordinator
                                          .scheduleAutosave(item.id, text),
                                      onBlur: (text) {
                                        if (text.trim().isEmpty) {
                                          unawaited(
                                            _coordinator.finishActiveEditing(
                                              discardIfEmpty: true,
                                            ),
                                          );
                                        }
                                      },
                                      onEnter: (cursor, text) async {
                                        await _coordinator.finishActiveEditing(
                                          discardIfEmpty: true,
                                        );
                                      },
                                      onBackspaceEmpty: () async {
                                        await _coordinator.finishActiveEditing(
                                          discardIfEmpty: true,
                                        );
                                      },
                                      onIndent: () {},
                                      onOutdent: () {},
                                    );
                                  },
                                ),
                              );
                            }, childCount: group.items.length),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
                if (_editingNodeId != null && activeItem != null)
                  KeyboardToolbar(
                    activeNodeId: activeItem.id,
                    currentColor: activeItem.node.color,
                    isDone: activeItem.isDone,
                    isFavorite: activeItem.node.isFavorite,
                    dueDate: activeItem.node.dueDate,
                    onColorSelected: (color) =>
                        _handleColorSelected(activeItem.node, color),
                    onToggleDone: () => _handleToggleDone(activeItem.node),
                    onToggleFavorite: () =>
                        _handleToggleFavorite(activeItem.node),
                    onDueDateInteractionChanged: (active) =>
                        _editorSession.isSelectingDueDate = active,
                    onDueDateChanged: (date) =>
                        _handleDueDateChanged(activeItem.node, date),
                    onRequestRestoreFocus: () => _restoreFocus(activeItem.id),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('加载失败: $error')),
        ),
      ),
    );
  }
}
