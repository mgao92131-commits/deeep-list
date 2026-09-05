import 'package:flutter/material.dart';

import '../domain/node.dart';
import '../domain/node_id.dart';
import 'editor_session.dart';
import 'widgets/node_card.dart';

class NodeList extends StatelessWidget {
  final List<Node> nodes;
  final NodeId? editingNodeId;
  final EditorSession editorSession;
  final Future<void> Function(Node node) onStartEditing;
  final Future<void> Function(NodeId nodeId, String text) onCommit;
  final Future<void> Function(Node node, int cursor, String text) onEnter;
  final Future<void> Function(Node node, int cursor, String text) onBackspace;
  final Future<void> Function(Node node) onNavigate;

  const NodeList({
    super.key,
    required this.nodes,
    required this.editingNodeId,
    required this.editorSession,
    required this.onStartEditing,
    required this.onCommit,
    required this.onEnter,
    required this.onBackspace,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Center(child: Text('No nodes yet. Add one to get started.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return NodeCard(
          key: ValueKey(node.id),
          node: node,
          isEditing: editingNodeId == node.id,
          editorSession: editorSession,
          onStartEditing: () => onStartEditing(node),
          onCommit: (text) => onCommit(node.id, text),
          onEnter: (cursor, text) => onEnter(node, cursor, text),
          onBackspace: (cursor, text) => onBackspace(node, cursor, text),
          onNavigate: () => onNavigate(node),
        );
      },
    );
  }
}
