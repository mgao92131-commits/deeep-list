import 'package:flutter/material.dart';

import '../../domain/node_color.dart';
import '../../domain/node_id.dart';

class KeyboardToolbar extends StatefulWidget {
  final NodeId? activeNodeId;
  final NodeColor currentColor;
  final bool isDone;
  final bool isFavorite;
  final DateTime? dueDate;
  final ValueChanged<NodeColor>? onColorSelected;
  final VoidCallback? onToggleDone;
  final VoidCallback? onToggleFavorite;
  final ValueChanged<DateTime?>? onDueDateChanged;
  final VoidCallback? onRequestRestoreFocus;

  const KeyboardToolbar({
    super.key,
    this.activeNodeId,
    this.currentColor = NodeColor.none,
    this.isDone = false,
    this.isFavorite = false,
    this.dueDate,
    this.onColorSelected,
    this.onToggleDone,
    this.onToggleFavorite,
    this.onDueDateChanged,
    this.onRequestRestoreFocus,
  });

  @override
  State<KeyboardToolbar> createState() => _KeyboardToolbarState();
}

class _KeyboardToolbarState extends State<KeyboardToolbar> {
  bool _isColorMode = false;

  @override
  void didUpdateWidget(covariant KeyboardToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeNodeId != widget.activeNodeId) {
      _isColorMode = false;
    }
  }

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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _isColorMode
            ? _buildColorToolbar(context, isDark)
            : _buildNormalToolbar(context),
      ),
    );
  }

  Widget _buildNormalToolbar(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      key: const ValueKey('normal-toolbar'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (widget.onColorSelected != null)
            // 🎨 Color mode entry button
            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              child: IconButton(
                icon: const Icon(Icons.palette_outlined, size: 20),
                tooltip: '颜色',
                onPressed: () {
                  setState(() => _isColorMode = true);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (widget.onToggleFavorite != null)
            // ★ Favorite toggle button
            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              child: IconButton(
                icon: Icon(
                  widget.isFavorite ? Icons.star : Icons.star_outline,
                  size: 22,
                  color: widget.isFavorite
                      ? const Color(0xFFF59E0B)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: widget.isFavorite ? '取消收藏' : '收藏',
                onPressed: widget.onToggleFavorite,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (widget.onDueDateChanged != null)
            // 📅 Due date quick menu button
            _buildDueDateButton(context, theme),
          const Spacer(),
          // 完成 (Done) toggle icon button
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: IconButton(
              icon: Icon(
                widget.isDone ? Icons.check_circle : Icons.check_circle_outline,
                size: 22,
                color: widget.isDone
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: widget.isDone ? '取消完成' : '完成',
              onPressed: widget.onToggleDone,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateButton(BuildContext context, ThemeData theme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final daysUntilNextMonday = today.weekday == DateTime.monday
        ? 7
        : (8 - today.weekday);
    final nextMonday = today.add(Duration(days: daysUntilNextMonday));

    final hasDueDate = widget.dueDate != null;
    final currentDueDate = widget.dueDate != null
        ? DateTime(
            widget.dueDate!.year,
            widget.dueDate!.month,
            widget.dueDate!.day,
          )
        : null;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: PopupMenuButton<String>(
        tooltip: '截止日期',
        icon: Icon(
          hasDueDate ? Icons.event : Icons.event_outlined,
          size: 20,
          color: hasDueDate
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        position: PopupMenuPosition.over,
        onCanceled: widget.onRequestRestoreFocus,
        onSelected: (action) async {
          if (action == 'today') {
            widget.onDueDateChanged?.call(today);
            widget.onRequestRestoreFocus?.call();
          } else if (action == 'tomorrow') {
            widget.onDueDateChanged?.call(tomorrow);
            widget.onRequestRestoreFocus?.call();
          } else if (action == 'next_monday') {
            widget.onDueDateChanged?.call(nextMonday);
            widget.onRequestRestoreFocus?.call();
          } else if (action == 'remove') {
            widget.onDueDateChanged?.call(null);
            widget.onRequestRestoreFocus?.call();
          } else if (action == 'custom') {
            final picked = await showDatePicker(
              context: context,
              initialDate: currentDueDate ?? today,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              widget.onDueDateChanged?.call(
                DateTime(picked.year, picked.month, picked.day),
              );
            }
            widget.onRequestRestoreFocus?.call();
          }
        },
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[];

          if (hasDueDate && currentDueDate != null) {
            final isToday = currentDueDate.isAtSameMomentAs(today);
            final isTomorrow = currentDueDate.isAtSameMomentAs(tomorrow);
            final isPast = currentDueDate.isBefore(today);
            String curDesc;
            if (isToday) {
              curDesc = '今天 (${currentDueDate.month}月${currentDueDate.day}日)';
            } else if (isTomorrow) {
              curDesc = '明天 (${currentDueDate.month}月${currentDueDate.day}日)';
            } else if (isPast) {
              curDesc = '${currentDueDate.month}月${currentDueDate.day}日 (已逾期)';
            } else {
              curDesc = '${currentDueDate.month}月${currentDueDate.day}日';
            }
            items.add(
              PopupMenuItem<String>(
                enabled: false,
                height: 36,
                child: Text(
                  '当前截止：$curDesc',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPast
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            );
            items.add(const PopupMenuDivider());
          }

          items.addAll([
            PopupMenuItem<String>(
              value: 'today',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('今天'),
                  Text(
                    '${today.month}月${today.day}日',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'tomorrow',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('明天'),
                  Text(
                    '${tomorrow.month}月${tomorrow.day}日',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'next_monday',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('下周一'),
                  Text(
                    '${nextMonday.month}月${nextMonday.day}日',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'custom',
              child: Row(
                children: [
                  Icon(Icons.edit_calendar_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('选择日期…'),
                ],
              ),
            ),
          ]);

          if (hasDueDate) {
            items.add(const PopupMenuDivider());
            items.add(
              PopupMenuItem<String>(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '移除截止日期',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ),
              ),
            );
          }

          return items;
        },
      ),
    );
  }

  Widget _buildColorToolbar(BuildContext context, bool isDark) {
    return Padding(
      key: const ValueKey('color-toolbar'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // ‹ Return to normal toolbar button
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: IconButton(
              icon: const Icon(Icons.chevron_left, size: 24),
              tooltip: '返回',
              onPressed: () {
                setState(() => _isColorMode = false);
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
          // 8 Color circles
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: NodeColor.values.map((color) {
                return _buildColorItem(context, color, isDark);
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildColorItem(BuildContext context, NodeColor color, bool isDark) {
    final theme = Theme.of(context);
    final isSelected = color == widget.currentColor;
    final resolvedColor = color.resolve(theme.brightness);
    final checkColor = isDark ? Colors.white : const Color(0xFF262626);

    Border border;
    if (isSelected) {
      border = Border.all(color: theme.colorScheme.primary, width: 2.0);
    } else if (color == NodeColor.none) {
      border = Border.all(
        color: isDark ? Colors.white60 : Colors.black45,
        width: 1.5,
      );
    } else {
      border = Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.black.withValues(alpha: 0.12),
        width: 1.0,
      );
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Tooltip(
        message: color.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onColorSelected?.call(color),
          child: SizedBox(
            width: 34,
            height: 44,
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: resolvedColor ?? Colors.transparent,
                  border: border,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 13,
                        color: color == NodeColor.none
                            ? theme.colorScheme.primary
                            : checkColor,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
