import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/node.dart';
import '../domain/node_id.dart';
import 'editor_session.dart';
import 'models/two_level_tree.dart';
import 'widgets/node_row.dart';

class NodeList extends StatelessWidget {
  final TwoLevelTree tree;
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
    required this.tree,
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

  void _handleLevel1Reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= tree.groups.length) return;
    if (newIndex < 0 || newIndex >= tree.groups.length) return;
    if (oldIndex == newIndex) return;

    final l1Ids = tree.groups.map((g) => g.parent.id).toList();
    final moved = l1Ids.removeAt(oldIndex);
    l1Ids.insert(newIndex, moved);

    final parentId = tree.groups.first.parent.parentId;
    unawaited(onReorderSiblings(parentId, l1Ids));
  }

  void _handleLevel2Reorder(
    NodeId parentId,
    List<NodeId> currentChildIds,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex < 0 || oldIndex >= currentChildIds.length) return;
    if (newIndex < 0 || newIndex >= currentChildIds.length) return;
    if (oldIndex == newIndex) return;

    final reordered = [...currentChildIds];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    unawaited(onReorderSiblings(parentId, reordered));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = tree.groups;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          sliver: SliverReorderableList(
            itemCount: groups.length,
            onReorderStart: (index) {
              if (index >= 0 && index < groups.length) {
                onReorderStart(groups[index].parent.id);
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
            onReorderItem: _handleLevel1Reorder,
            itemBuilder: (context, index) {
              final group = groups[index];
              final parentItem = group.parent;
              final children = group.children;

              return KeyedSubtree(
                key: ValueKey(parentItem.id),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Level 1 Row (Listener strictly scoped to Level 1 row only)
                    ReorderableDelayedDragStartListener(
                      index: index,
                      enabled: editingNodeId == null,
                      child: NodeRow(
                        item: parentItem,
                        isSelected: selectedNodeId == parentItem.id,
                        isEditing: editingNodeId == parentItem.id,
                        editorSession: editorSession,
                        onSelect: () => onSelect(parentItem.id),
                        onStartEditing: () => onStartEditing(parentItem.node),
                        onNavigate: () => onNavigate(parentItem.node),
                        onCommit: (text) => onCommit(parentItem.id, text),
                        onChanged: (text) => onChanged(parentItem.node, text),
                        onBlur: onBlur,
                        onEnter: (cursor, text) =>
                            onEnter(parentItem.node, cursor, text),
                        onBackspaceEmpty: () =>
                            onBackspaceEmpty(parentItem.node),
                        onIndent: () => onIndent(parentItem.id),
                        onOutdent: () => onOutdent(parentItem.id),
                      ),
                    ),
                    // Level 2 Sub-list (Scoped strictly to this parent - Sibling Drag Boundary)
                    if (children.isNotEmpty)
                      ReorderableListView.builder(
                        key: ValueKey('children-${parentItem.id}'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: children.length,
                        buildDefaultDragHandles: false,
                        onReorderStart: (childIndex) {
                          if (childIndex >= 0 && childIndex < children.length) {
                            onReorderStart(children[childIndex].id);
                          }
                        },
                        onReorderEnd: (childIndex) {
                          onReorderEnd();
                        },
                        onReorderItem: (oldIdx, newIdx) {
                          final childIds = children.map((c) => c.id).toList();
                          _handleLevel2Reorder(
                            parentItem.id,
                            childIds,
                            oldIdx,
                            newIdx,
                          );
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
                        itemBuilder: (context, childIndex) {
                          final childItem = children[childIndex];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey(childItem.id),
                            index: childIndex,
                            enabled: editingNodeId == null,
                            child: NodeRow(
                              item: childItem,
                              isSelected: selectedNodeId == childItem.id,
                              isEditing: editingNodeId == childItem.id,
                              editorSession: editorSession,
                              onSelect: () => onSelect(childItem.id),
                              onStartEditing: () =>
                                  onStartEditing(childItem.node),
                              onNavigate: () => onNavigate(childItem.node),
                              onCommit: (text) => onCommit(childItem.id, text),
                              onChanged: (text) =>
                                  onChanged(childItem.node, text),
                              onBlur: onBlur,
                              onEnter: (cursor, text) =>
                                  onEnter(childItem.node, cursor, text),
                              onBackspaceEmpty: () =>
                                  onBackspaceEmpty(childItem.node),
                              onIndent: () => onIndent(childItem.id),
                              onOutdent: () => onOutdent(childItem.id),
                            ),
                          );
                        },
                      ),
                  ],
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
              child: groups.isEmpty
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
