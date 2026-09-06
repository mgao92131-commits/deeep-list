import 'package:flutter/material.dart';

class SelectionToolbar extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback? onMore;

  const SelectionToolbar({super.key, required this.onDelete, this.onMore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.colorScheme.error,
              ),
              label: Text(
                '删除',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onPressed: onDelete,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 20),
              tooltip: '更多',
              visualDensity: VisualDensity.compact,
              onPressed: onMore,
            ),
          ],
        ),
      ),
    );
  }
}
