import 'package:flutter/material.dart';

class SmartEntriesBar extends StatelessWidget {
  final VoidCallback onTodayTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onDueDatesTap;

  const SmartEntriesBar({
    super.key,
    required this.onTodayTap,
    required this.onFavoritesTap,
    required this.onDueDatesTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Tooltip(
              message: '今天',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                onTap: onTodayTap,
                child: Center(
                  child: Icon(
                    Icons.today_outlined,
                    key: const ValueKey('smart-entry-today'),
                    color: iconColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 1,
              height: 20,
              color: theme.dividerColor.withValues(alpha: 0.25),
            ),
          ),
          Expanded(
            child: Tooltip(
              message: '收藏',
              child: InkWell(
                onTap: onFavoritesTap,
                child: Center(
                  child: Icon(
                    Icons.star_outline,
                    key: const ValueKey('smart-entry-favorites'),
                    color: iconColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 1,
              height: 20,
              color: theme.dividerColor.withValues(alpha: 0.25),
            ),
          ),
          Expanded(
            child: Tooltip(
              message: '截止日期',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(12),
                ),
                onTap: onDueDatesTap,
                child: Center(
                  child: Icon(
                    Icons.event_outlined,
                    key: const ValueKey('smart-entry-due-dates'),
                    color: iconColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
