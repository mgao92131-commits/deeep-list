import 'package:flutter/material.dart';

import '../../domain/node.dart';

enum _MenuAction {
  copy,
  paste,
  archive,
  delete,
}

class NodeActionMenu {
  const NodeActionMenu._();

  static Future<void> show(
    BuildContext context, {
    required Offset position,
    required Node node,
    required bool canPaste,
    required VoidCallback onCopy,
    VoidCallback? onPaste,
    required VoidCallback onArchive,
    required VoidCallback onRestore,
    required VoidCallback onDelete,
  }) async {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final relativePosition = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      screenSize.width - position.dx,
      screenSize.height - position.dy,
    );

    final selected = await showMenu<_MenuAction>(
      context: context,
      position: relativePosition,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      items: [
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.copy,
          child: const Row(
            children: [
              Icon(Icons.copy_outlined, size: 20),
              SizedBox(width: 12),
              Text('复制'),
            ],
          ),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.paste,
          enabled: canPaste && onPaste != null,
          child: Row(
            children: [
              Icon(
                Icons.paste_outlined,
                size: 20,
                color: (canPaste && onPaste != null)
                    ? null
                    : theme.disabledColor,
              ),
              const SizedBox(width: 12),
              const Text('粘贴'),
            ],
          ),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.archive,
          child: Row(
            children: [
              Icon(
                node.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(node.isArchived ? '恢复' : '归档'),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.delete,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 12),
              Text(
                '删除',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    switch (selected) {
      case _MenuAction.copy:
        onCopy();
        break;
      case _MenuAction.paste:
        if (canPaste && onPaste != null) {
          onPaste();
        }
        break;
      case _MenuAction.archive:
        if (node.isArchived) {
          onRestore();
        } else {
          onArchive();
        }
        break;
      case _MenuAction.delete:
        onDelete();
        break;
      case null:
        break;
    }
  }
}
