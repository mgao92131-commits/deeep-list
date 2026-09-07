import 'package:flutter/material.dart';

import '../../domain/node_color.dart';
import '../../domain/node_id.dart';

class KeyboardToolbar extends StatefulWidget {
  final NodeId? activeNodeId;
  final NodeColor currentColor;
  final bool canOutdent;
  final bool canIndent;
  final VoidCallback onOutdent;
  final VoidCallback onIndent;
  final ValueChanged<NodeColor>? onColorSelected;
  final VoidCallback onDone;
  final VoidCallback? onMore;

  const KeyboardToolbar({
    super.key,
    this.activeNodeId,
    this.currentColor = NodeColor.none,
    required this.canOutdent,
    required this.canIndent,
    required this.onOutdent,
    required this.onIndent,
    this.onColorSelected,
    required this.onDone,
    this.onMore,
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
          // ⇤ Outdent button
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: IconButton(
              icon: const Icon(Icons.format_indent_decrease, size: 20),
              tooltip: 'Outdent',
              onPressed: widget.canOutdent ? widget.onOutdent : null,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          // ⇥ Indent button
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: IconButton(
              icon: const Icon(Icons.format_indent_increase, size: 20),
              tooltip: 'Indent',
              onPressed: widget.canIndent ? widget.onIndent : null,
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (widget.onColorSelected != null) ...[
            const SizedBox(width: 8),
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
          ],
          if (widget.onMore != null) ...[
            const SizedBox(width: 8),
            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              child: IconButton(
                icon: const Icon(Icons.more_horiz, size: 20),
                tooltip: '更多',
                onPressed: widget.onMore,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
          const Spacer(),
          // 完成 (Done) button
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: TextButton(
              onPressed: widget.onDone,
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
          ),
        ],
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
