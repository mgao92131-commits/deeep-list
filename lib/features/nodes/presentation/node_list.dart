import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/node.dart';
import '../domain/node_id.dart';
import 'editor_session.dart';
import 'models/visible_node_item.dart';
import 'widgets/node_row.dart';

class NodeList extends StatelessWidget {
  final List<VisibleNodeItem> items;
  final NodeId? parentId;
  final NodeId? selectedNodeId;
  final NodeId? editingNodeId;
  final EditorSession editorSession;
  final void Function(NodeId id) onSelect;
  final Future<void> Function(Node node) onStartEditing;
  final Future<void> Function(NodeId id, String text) onCommit;
  final void Function(Node node, String text) onChanged;
  final void Function(String text)? onBlur;
  final Future<void> Function(Node node, int cursor, String text) onEnter;
  final Future<void> Function(Node node) onBackspaceEmpty;
  final Future<void> Function(Node node) onNavigate;
  final Future<void> Function(NodeId id) onIndent;
  final Future<void> Function(NodeId id) onOutdent;
  final void Function(NodeId id) onReorderStart;
  final VoidCallback onReorderEnd;
  final Future<void> Function(NodeId? parentId, List<NodeId> orderedIds)
  onReorderSiblings;
  final VoidCallback onBlankAreaTap;

  const NodeList({
    super.key,
    required this.items,
    required this.parentId,
    required this.selectedNodeId,
    required this.editingNodeId,
    required this.editorSession,
    required this.onSelect,
    required this.onStartEditing,
    required this.onCommit,
    required this.onChanged,
    this.onBlur,
    required this.onEnter,
    required this.onBackspaceEmpty,
    required this.onNavigate,
    required this.onIndent,
    required this.onOutdent,
    required this.onReorderStart,
    required this.onReorderEnd,
    required this.onReorderSiblings,
    required this.onBlankAreaTap,
  });

  void _handleReorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= items.length) return;
    if (newIndex < 0 || newIndex >= items.length) return;
    if (oldIndex == newIndex) return;

    final orderedIds = items.map((it) => it.id).toList();
    final moved = orderedIds.removeAt(oldIndex);
    orderedIds.insert(newIndex, moved);

    unawaited(onReorderSiblings(parentId, orderedIds));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          sliver: SliverReorderableList(
            itemCount: items.length,
            onReorderStart: (index) {
              if (index >= 0 && index < items.length) {
                onReorderStart(items[index].id);
              }
            },
            onReorderEnd: (index) {
              onReorderEnd();
            },
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  return Transform.scale(
                    scale: 1.02,
                    child: Material(
                      elevation: 3,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      child: child,
                    ),
                  );
                },
              );
            },
            onReorderItem: _handleReorder,
            itemBuilder: (context, index) {
              final item = items[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(item.id),
                index: index,
                enabled: editingNodeId == null,
                child: NodeRow(
                  item: item,
                  isSelected: selectedNodeId == item.id,
                  isEditing: editingNodeId == item.id,
                  editorSession: editorSession,
                  onSelect: () => onSelect(item.id),
                  onStartEditing: () => onStartEditing(item.node),
                  onNavigate: () => onNavigate(item.node),
                  onCommit: (text) => onCommit(item.id, text),
                  onChanged: (text) => onChanged(item.node, text),
                  onBlur: onBlur,
                  onEnter: (cursor, text) => onEnter(item.node, cursor, text),
                  onBackspaceEmpty: () => onBackspaceEmpty(item.node),
                  onIndent: () => onIndent(item.id),
                  onOutdent: () => onOutdent(item.id),
                ),
              );
            },
          ),
        ),
        // Trailing blank area: Click below the last node creates new transient empty node in 1 tap
        SliverFillRemaining(
          hasScrollBody: false,
          child: GestureDetector(
            key: const ValueKey('blank-area'),
            behavior: HitTestBehavior.opaque,
            onTap: onBlankAreaTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 120),
              color: Colors.transparent,
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        '点击空白处开始记录',
                        style: TextStyle(
                          fontSize: 15,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}
