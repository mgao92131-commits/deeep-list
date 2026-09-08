import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import 'controllers/editor_lifecycle.dart';
import '../../../core/time/today_provider.dart';
import '../presentation/controllers/clipboard_controller.dart';
import '../domain/node.dart';
import '../domain/node_id.dart';
import 'controllers/node_editing_coordinator.dart';
import 'controllers/node_actions_controller.dart';
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

class _SmartNodePageState extends ConsumerState<SmartNodePage> {
  late final NodeEditingCoordinator _coordinator;
  late final NodeActionsController _actions;
  NodeId? get _editingNodeId => _coordinator.editing.value.editingNodeId;
  late final EditorLifecycle _lifecycle;

  EditorSession get _editorSession => _coordinator.editorSession;

  @override
  void initState() {
    super.initState();
    _coordinator = NodeEditingCoordinator(
      treeCommandService: ref.read(treeCommandServiceProvider),
      onError: _showMutationError,
    );
    _coordinator.editing.addListener(_editingChanged);
    _actions = NodeActionsController(
      editor: _coordinator,
      commands: ref.read(treeCommandServiceProvider),
      smartList: widget.type,
      today: () => ref.read(todayProvider),
      onError: _showMutationError,
      clipboard: () => ref.read(clipboardControllerProvider),
      copyToClipboard: (id) =>
          ref.read(clipboardControllerProvider.notifier).copy(id),
      clearClipboard: () =>
          ref.read(clipboardControllerProvider.notifier).clear(),
    );
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
    _coordinator.editing.removeListener(_editingChanged);
    _coordinator.dispose();
    super.dispose();
  }

  void _editingChanged() {
    if (mounted) setState(() {});
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

  void _restoreFocus(NodeId nodeId) {
    if (_editingNodeId == nodeId) _editorSession.focus(nodeId);
  }

  Future<void> _handleToggleDone(Node node) async {
    final showUndo = await _actions.toggleDone(node);
    if (!mounted || !showUndo) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('已完成'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => unawaited(_actions.undoDone(node.id)),
        ),
      ),
    );
  }

  Future<void> _openNode(Node node) async {
    await _coordinator.finishActiveEditing(discardIfEmpty: true);
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
      onPaste: null,
      onArchive: () => _actions.archive(node),
      onRestore: () => _actions.restore(node),
      onDelete: () => _actions.delete(node),
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
                                        .watch(
                                          smartNodePathsProvider(widget.type),
                                        )
                                        .value?[item.id];
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
                    today: ref.watch(todayProvider),
                    activeNodeId: activeItem.id,
                    currentColor: activeItem.node.color,
                    isDone: activeItem.isDone,
                    isFavorite: activeItem.node.isFavorite,
                    dueDate: activeItem.node.dueDate,
                    onColorSelected: (color) =>
                        _actions.updateColor(activeItem.node, color),
                    onToggleDone: () => _handleToggleDone(activeItem.node),
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
          error: (error, _) => Center(child: Text('加载失败: $error')),
        ),
      ),
    );
  }
}
