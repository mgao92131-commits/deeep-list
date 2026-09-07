import 'package:flutter/material.dart';

import '../../domain/node.dart';

class NodeActionMenu extends StatelessWidget {
  final Node node;
  final bool canPaste;
  final VoidCallback onCopy;
  final VoidCallback? onPaste;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const NodeActionMenu({
    super.key,
    required this.node,
    required this.canPaste,
    required this.onCopy,
    this.onPaste,
    required this.onArchive,
    required this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required Node node,
    required bool canPaste,
    required VoidCallback onCopy,
    VoidCallback? onPaste,
    required VoidCallback onArchive,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => NodeActionMenu(
        node: node,
        canPaste: canPaste,
        onCopy: () {
          Navigator.pop(sheetContext);
          onCopy();
        },
        onPaste: onPaste != null
            ? () {
                Navigator.pop(sheetContext);
                onPaste();
              }
            : null,
        onArchive: () {
          Navigator.pop(sheetContext);
          onArchive();
        },
        onDelete: () {
          Navigator.pop(sheetContext);
          onDelete();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: onCopy,
            ),
            ListTile(
              leading: const Icon(Icons.paste_outlined),
              title: const Text('粘贴'),
              enabled: canPaste && onPaste != null,
              onTap: canPaste ? onPaste : null,
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('归档'),
              onTap: onArchive,
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                '删除',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
