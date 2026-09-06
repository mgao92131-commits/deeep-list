import 'package:flutter/material.dart';

class KeyboardToolbar extends StatelessWidget {
  final bool canOutdent;
  final bool canIndent;
  final VoidCallback onOutdent;
  final VoidCallback onIndent;
  final VoidCallback onDone;

  const KeyboardToolbar({
    super.key,
    required this.canOutdent,
    required this.canIndent,
    required this.onOutdent,
    required this.onIndent,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainer;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ⇤ Outdent button
          IconButton(
            icon: const Icon(Icons.format_indent_decrease, size: 20),
            tooltip: 'Outdent',
            onPressed: canOutdent ? onOutdent : null,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          // ⇥ Indent button
          IconButton(
            icon: const Icon(Icons.format_indent_increase, size: 20),
            tooltip: 'Indent',
            onPressed: canIndent ? onIndent : null,
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          // 完成 (Done) button
          TextButton(
            onPressed: onDone,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              '完成',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
