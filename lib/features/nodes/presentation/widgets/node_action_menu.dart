import 'package:flutter/material.dart';

import '../../domain/node.dart';
import '../../domain/node_color.dart';

class NodeActionMenu extends StatefulWidget {
  final Node node;
  final bool canPaste;
  final VoidCallback onCopy;
  final VoidCallback? onPaste;
  final ValueChanged<NodeColor>? onColorSelected;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const NodeActionMenu({
    super.key,
    required this.node,
    required this.canPaste,
    required this.onCopy,
    this.onPaste,
    this.onColorSelected,
    required this.onArchive,
    required this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required Node node,
    required bool canPaste,
    required VoidCallback onCopy,
    VoidCallback? onPaste,
    ValueChanged<NodeColor>? onColorSelected,
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
        onColorSelected: onColorSelected != null
            ? (color) {
                Navigator.pop(sheetContext);
                onColorSelected(color);
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
  State<NodeActionMenu> createState() => _NodeActionMenuState();
}

class _NodeActionMenuState extends State<NodeActionMenu> {
  bool _pickingColor = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _pickingColor
              ? _buildColorPickerView(context, theme, isDark)
              : _buildMainMenuView(context, theme, isDark),
        ),
      ),
    );
  }

  Widget _buildMainMenuView(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    final currentColor = widget.node.color;
    final resolvedColor = currentColor.resolve(theme.brightness);

    return Column(
      key: const ValueKey('main-menu'),
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.copy_outlined),
          title: const Text('复制'),
          onTap: widget.onCopy,
        ),
        ListTile(
          leading: const Icon(Icons.paste_outlined),
          title: const Text('粘贴'),
          enabled: widget.canPaste && widget.onPaste != null,
          onTap: widget.canPaste ? widget.onPaste : null,
        ),
        if (widget.onColorSelected != null)
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('背景色'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: resolvedColor ?? Colors.transparent,
                    border: Border.all(
                      color: currentColor == NodeColor.none
                          ? (isDark ? Colors.white60 : Colors.black45)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.15)),
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () {
              setState(() => _pickingColor = true);
            },
          ),
        ListTile(
          leading: const Icon(Icons.archive_outlined),
          title: const Text('归档'),
          onTap: widget.onArchive,
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          title: Text(
            '删除',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: widget.onDelete,
        ),
      ],
    );
  }

  Widget _buildColorPickerView(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      key: const ValueKey('color-picker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() => _pickingColor = false);
            },
          ),
          title: const Text(
            '选择背景色',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: NodeColor.values.map((color) {
              final isSelected = color == widget.node.color;
              final resolvedColor = color.resolve(theme.brightness);
              final checkColor = isDark
                  ? Colors.white
                  : const Color(0xFF262626);

              Border border;
              if (isSelected) {
                border = Border.all(
                  color: theme.colorScheme.primary,
                  width: 2.0,
                );
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

              return Tooltip(
                message: color.label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onColorSelected?.call(color),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: resolvedColor ?? Colors.transparent,
                          border: border,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: color == NodeColor.none
                                    ? theme.colorScheme.primary
                                    : checkColor,
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        color.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
