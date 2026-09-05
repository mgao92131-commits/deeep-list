import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/node_item.dart';
import '../viewmodels/node_viewmodel.dart';

class NodeTile extends StatefulWidget {
  final NodeItem item;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;
  final VoidCallback onNavigate;
  final Function(String) onContentChanged;
  final VoidCallback onToggleDone;
  final VoidCallback onToggleFavorite;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  final Stream<FocusRequest> focusRequests;
  final Function(NodeItem, int, String) onEnter;
  final Function(NodeItem, int, String) onBackspace;

  const NodeTile({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onTap,
    required this.onNavigate,
    required this.onContentChanged,
    required this.onToggleDone,
    required this.onToggleFavorite,
    required this.onArchive,
    required this.onDelete,
    required this.focusRequests,
    required this.onEnter,
    required this.onBackspace,
  });

  @override
  State<NodeTile> createState() => _NodeTileState();
}

class _NodeTileState extends State<NodeTile> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  StreamSubscription? _focusSub;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.content);

    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            final selection = _controller.selection;
            if (selection.isValid &&
                selection.isCollapsed &&
                selection.baseOffset == 0) {
              widget.onBackspace(widget.item, 0, _controller.text);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
    );

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        if (_controller.text != widget.item.content) {
          widget.onContentChanged(_controller.text);
        }
      }
    });

    _focusSub = widget.focusRequests.listen((req) {
      if (req.nodeId == widget.item.id) {
        _focusNode.requestFocus();
        if (req.cursor != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final textLen = _controller.text.length;
            final cursor = req.cursor!;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: cursor > textLen ? textLen : cursor),
            );
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(NodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.content != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.item.content;
    }
  }

  @override
  void dispose() {
    _focusSub?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Slidable(
      key: ValueKey(widget.item.id),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => widget.onDelete(),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            icon: Icons.delete,
          ),
          SlidableAction(
            onPressed: (_) => widget.onArchive(),
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: theme.colorScheme.onSecondary,
            icon: Icons.archive,
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => widget.onToggleDone(),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            icon: Icons.check,
          ),
          SlidableAction(
            onPressed: (_) => widget.onToggleFavorite(),
            backgroundColor: theme.colorScheme.tertiary,
            foregroundColor: theme.colorScheme.onTertiary,
            icon: widget.item.isFavorite ? Icons.star : Icons.star_border,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          visualDensity: VisualDensity.compact,
          title: widget.isSelected
              ? TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: theme.textTheme.bodyLarge,
                  autofocus: true,
                  onSubmitted: (val) {
                    final sel = _controller.selection;
                    final cursor = sel.isValid ? sel.baseOffset : val.length;
                    widget.onEnter(widget.item, cursor, val);
                  },
                )
              : Text(
                  widget.item.content,
                  style: widget.item.isDone
                      ? theme.textTheme.bodyLarge?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        )
                      : theme.textTheme.bodyLarge,
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.item.children.isNotEmpty)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: widget.onNavigate,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
