import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/node.dart';
import '../domain/node_id.dart';
import 'editor_session.dart';
import 'models/visible_node_item.dart';
import 'widgets/node_row.dart';

class NodeList extends StatelessWidget {
  final List<VisibleNodeItem> items;
  final NodeId? selectedNodeId;
  final NodeId? editingNodeId;
  final EditorSession editorSession;
  final void Function(NodeId id) onSelect;
  final Future<void> Function(Node node) onStartEditing;
  final Future<void> Function(NodeId id, String text) onCommit;
  final void Function(Node node, String text) onChanged;
  final Future<void> Function(Node node, int cursor, String text) onEnter;
  final Future<void> Function(Node node) onBackspaceEmpty;
  final Future<void> Function(Node node, int cursor, String text)?
  onBackspaceMerge;
  final Future<void> Function(Node node) onNavigate;
  final Future<void> Function(NodeId id) onIndent;
  final Future<void> Function(NodeId id) onOutdent;
  final Future<void> Function(NodeId? parentId, List<NodeId> orderedIds)
  onReorderSiblings;
  final VoidCallback onBlankAreaTap;
  final VoidCallback onDeselect;

  const NodeList({
    super.key,
    required this.items,
    required this.selectedNodeId,
    required this.editingNodeId,
    required this.editorSession,
    required this.onSelect,
    required this.onStartEditing,
    required this.onCommit,
    required this.onChanged,
    required this.onEnter,
    required this.onBackspaceEmpty,
    this.onBackspaceMerge,
    required this.onNavigate,
    required this.onIndent,
    required this.onOutdent,
    required this.onReorderSiblings,
    required this.onBlankAreaTap,
    required this.onDeselect,
  });

  void _handleReorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= items.length) return;
    final targetIndex = newIndex;

    final draggedItem = items[oldIndex];
    final parentId = draggedItem.parentId;

    // Spec 31-32: Drag ONLY reorders within the same parent
    final siblingIndices = <int>[];
    final siblingIds = <NodeId>[];
    for (var i = 0; i < items.length; i++) {
      if (items[i].parentId == parentId) {
        siblingIndices.add(i);
        siblingIds.add(items[i].id);
      }
    }

    if (siblingIndices.isEmpty) return;

    final minIndex = siblingIndices.first;
    final maxIndex = siblingIndices.last;
    final clampedTargetIndex = targetIndex.clamp(minIndex, maxIndex);

    // Find new position inside siblingIds
    final oldSiblingPos = siblingIds.indexOf(draggedItem.id);
    if (oldSiblingPos < 0) return;

    // Determine target sibling index
    int newSiblingPos;
    if (clampedTargetIndex <= minIndex) {
      newSiblingPos = 0;
    } else if (clampedTargetIndex >= maxIndex) {
      newSiblingPos = siblingIds.length - 1;
    } else {
      final targetItem = items[clampedTargetIndex];
      newSiblingPos = siblingIds.indexOf(targetItem.id);
      if (newSiblingPos < 0) newSiblingPos = oldSiblingPos;
    }

    if (oldSiblingPos == newSiblingPos) return;

    final reordered = [...siblingIds];
    final moved = reordered.removeAt(oldSiblingPos);
    reordered.insert(newSiblingPos, moved);

    unawaited(onReorderSiblings(parentId, reordered));
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
                  onEnter: (cursor, text) => onEnter(item.node, cursor, text),
                  onBackspaceEmpty: () => onBackspaceEmpty(item.node),
                  onBackspaceMerge: onBackspaceMerge != null
                      ? (cursor, text) =>
                            onBackspaceMerge!(item.node, cursor, text)
                      : null,
                  onIndent: () => onIndent(item.id),
                  onOutdent: () => onOutdent(item.id),
                ),
              );
            },
          ),
        ),
        // Trailing blank area: Spec 18-19: Click below the last node creates new transient empty node
        SliverFillRemaining(
          hasScrollBody: false,
          child: GestureDetector(
            key: const ValueKey('blank-area'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (selectedNodeId != null) {
                onDeselect();
              } else {
                onBlankAreaTap();
              }
            },
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
