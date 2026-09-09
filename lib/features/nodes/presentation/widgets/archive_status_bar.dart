import 'package:flutter/material.dart';

class ArchiveStatusBar extends StatelessWidget {
  final int count;
  final VoidCallback onShowActive;

  const ArchiveStatusBar({
    super.key,
    required this.count,
    required this.onShowActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('archive-status-bar'),
      height: 48,
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.archive_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('已归档 · $count', style: theme.textTheme.titleSmall),
          ),
          TextButton(onPressed: onShowActive, child: const Text('未归档')),
        ],
      ),
    );
  }
}
