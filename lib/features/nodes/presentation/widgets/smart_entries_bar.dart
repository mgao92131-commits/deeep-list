import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/smart_nodes_provider.dart';

class SmartEntriesBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    int count(SmartListType type) =>
        ref
            .watch(smartNodesProvider(type))
            .value
            ?.fold<int>(0, (total, group) => total + group.items.length) ??
        0;

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
                  child: _entryContent(
                    context,
                    icon: Icons.wb_sunny_outlined,
                    entry: 'today',
                    color: const Color(0xFFF59E0B),
                    count: count(SmartListType.today),
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
                  child: _entryContent(
                    context,
                    icon: Icons.star,
                    entry: 'favorites',
                    color: const Color(0xFFF59E0B),
                    count: count(SmartListType.favorites),
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
                  child: _entryContent(
                    context,
                    icon: Icons.event_outlined,
                    entry: 'due-dates',
                    color: theme.colorScheme.primary,
                    count: count(SmartListType.dueDates),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryContent(
    BuildContext context, {
    required IconData icon,
    required String entry,
    required Color color,
    required int count,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, key: ValueKey('smart-entry-$entry'), color: color, size: 22),
      const SizedBox(width: 6),
      Text(
        count > 99 ? '99+' : '$count',
        key: ValueKey('smart-entry-$entry-count'),
        semanticsLabel: '$count',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
