import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/clipboard_controller.dart';
import '../domain/node.dart';
import '../domain/node_id.dart';
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
  static const _autosaveDelay = Duration(milliseconds: 400);

  late final EditorSession _editorSession;
  NodeId? _editingNodeId;
  Timer? _autosaveTimer;
  NodeId? _pendingAutosaveNodeId;
  String? _pendingAutosaveText;

  @override
  void initState() {
    super.initState();
    _editorSession = EditorSession();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _editorSession.dispose();
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

  Future<void> _saveContent(NodeId nodeId, String text) async {
    try {
      await ref.read(treeCommandServiceProvider).updateContent(nodeId, text);
    } catch (_) {}
  }

  void _scheduleAutosave(NodeId nodeId, String text) {
    _pendingAutosaveNodeId = nodeId;
    _pendingAutosaveText = text;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, () {
      final id = _pendingAutosaveNodeId;
      final t = _pendingAutosaveText;
      _pendingAutosaveNodeId = null;
      _pendingAutosaveText = null;
      if (id != null && t != null) {
        _saveContent(id, t);
      }
    });
  }

  Future<void> _commit(NodeId nodeId, String text) async {
    _autosaveTimer?.cancel();
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;
    await _saveContent(nodeId, text);
  }

  Future<void> _finishEditing() async {
    _autosaveTimer?.cancel();
    final activeId = _editorSession.activeNodeId ?? _editingNodeId;
    final activeText = _editorSession.activeText;
    if (activeId != null && activeText != null) {
      await _saveContent(activeId, activeText);
    }
    _editorSession.unfocus();
    if (mounted) {
      setState(() {
        _editingNodeId = null;
      });
    }
  }

  void _startEditing(Node node) {
    if (_editingNodeId == node.id) return;
    setState(() {
      _editingNodeId = node.id;
    });
    _editorSession.focus(node.id, cursor: node.content.length);
  }

  Future<void> _openNode(Node node) async {
    await _finishEditing();
    if (!mounted) return;
    context.push('/node/${node.id}');
  }

  Future<void> _copyNode(Node node) async {
    final activeId = _editingNodeId;
    if (activeId == node.id) {
      final activeText = _editorSession.activeText;
      if (activeText != null) {
        await _saveContent(node.id, activeText);
      }
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
        await _finishEditing();
        await ref.read(treeCommandServiceProvider).archiveNode(node.id);
      },
      onRestore: () async {
        await _finishEditing();
        await ref.read(treeCommandServiceProvider).restoreNode(node.id);
      },
      onDelete: () async {
        await _finishEditing();
        await ref.read(treeCommandServiceProvider).deleteSubtree(node.id);
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
          unawaited(_finishEditing());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_editingNodeId != null) {
                unawaited(_finishEditing());
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
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
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
                                  child: NodeRow(
                                    key: ValueKey('smart-${item.id}'),
                                    item: item,
                                    isEditing: _editingNodeId == item.id,
                                    editorSession: _editorSession,
                                    onStartEditing: () =>
                                        _startEditing(item.node),
                                    onNavigate: () => _openNode(item.node),
                                    onCommit: (text) => _commit(item.id, text),
                                    onChanged: (text) =>
                                        _scheduleAutosave(item.id, text),
                                    onBlur: (text) {
                                      if (text.trim().isEmpty) {
                                        unawaited(_finishEditing());
                                      }
                                    },
                                    onEnter: (cursor, text) async {
                                      await _finishEditing();
                                    },
                                    onBackspaceEmpty: () async {
                                      await _finishEditing();
                                    },
                                    onIndent: () {},
                                    onOutdent: () {},
                                  ),
                                );
                              },
                              childCount: group.items.length,
                            ),
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
                    onColorSelected: (color) {
                      unawaited(
                        ref
                            .read(treeCommandServiceProvider)
                            .updateColor(activeItem.id, color),
                      );
                    },
                    onToggleDone: () {
                      unawaited(
                        ref
                            .read(treeCommandServiceProvider)
                            .toggleDone(activeItem.id),
                      );
                    },
                    onToggleFavorite: () {
                      unawaited(
                        ref
                            .read(treeCommandServiceProvider)
                            .toggleFavorite(activeItem.id),
                      );
                    },
                    onDueDateChanged: (date) {
                      unawaited(
                        ref
                            .read(treeCommandServiceProvider)
                            .updateDueDate(activeItem.id, date),
                      );
                    },
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
