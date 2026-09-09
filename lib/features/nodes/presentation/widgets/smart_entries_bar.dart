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

    return SizedBox(
      width: 216,
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _entryButton(
            context,
            label: '今天',
            icon: Icons.wb_sunny_outlined,
            entry: 'today',
            color: const Color(0xFFF59E0B),
            count: count(SmartListType.today),
            onTap: onTodayTap,
          ),
          _divider(theme, 'today-favorites'),
          _entryButton(
            context,
            label: '收藏',
            icon: Icons.star,
            entry: 'favorites',
            color: const Color(0xFFF59E0B),
            count: count(SmartListType.favorites),
            onTap: onFavoritesTap,
          ),
          _divider(theme, 'favorites-due-dates'),
          _entryButton(
            context,
            label: '截止日期',
            icon: Icons.event_outlined,
            entry: 'due-dates',
            color: theme.colorScheme.primary,
            count: count(SmartListType.dueDates),
            onTap: onDueDatesTap,
          ),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme, String key) => VerticalDivider(
    key: ValueKey('smart-entry-divider-$key'),
    width: 1,
    thickness: 1,
    indent: 14,
    endIndent: 14,
    color: theme.dividerColor.withValues(alpha: 0.25),
  );

  Widget _entryButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String entry,
    required Color color,
    required int count,
    required VoidCallback onTap,
  }) => Expanded(
    child: Semantics(
      key: ValueKey('smart-entry-$entry-button'),
      button: true,
      label: '$label，$count',
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: _entryContent(
              context,
              icon: icon,
              entry: entry,
              color: color,
              count: count,
            ),
          ),
        ),
      ),
    ),
  );

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
