import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor_session.dart';
import '../models/visible_node_item.dart';

class NodeRow extends StatefulWidget {
  final VisibleNodeItem item;
  final bool isSelected;
  final bool isEditing;
  final bool isDragging;
  final EditorSession editorSession;
  final VoidCallback onSelect;
  final VoidCallback onStartEditing;
  final Future<void> Function() onNavigate;
  final Future<void> Function(String text) onCommit;
  final ValueChanged<String> onChanged;
  final Future<void> Function(int cursor, String text) onEnter;
  final Future<void> Function() onBackspaceEmpty;
  final Future<void> Function(int cursor, String text)? onBackspaceMerge;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;
  final VoidCallback? onLongPress;

  const NodeRow({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isEditing,
    this.isDragging = false,
    required this.editorSession,
    required this.onSelect,
    required this.onStartEditing,
    required this.onNavigate,
    required this.onCommit,
    required this.onChanged,
    required this.onEnter,
    required this.onBackspaceEmpty,
    this.onBackspaceMerge,
    required this.onIndent,
    required this.onOutdent,
    this.onLongPress,
  });

  @override
  State<NodeRow> createState() => _NodeRowState();
}

class _NodeRowState extends State<NodeRow> with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final AnimationController _springController;
  Animation<double>? _springAnimation;

  double _dragOffset = 0.0;
  double _rawGestureOffset = 0.0;
  bool _isArmed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.node.content);
    _focusNode = FocusNode(
      debugLabel: 'node-${widget.item.node.id}',
      onKeyEvent: _handleKeyEvent,
    );
    _focusNode.addListener(_handleFocusChanged);

    _springController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          if (_springAnimation != null) {
            setState(() {
              _dragOffset = _springAnimation!.value;
            });
          }
        });

    _register();
  }

  void _register() {
    widget.editorSession.register(
      nodeId: widget.item.node.id,
      focusNode: _focusNode,
      controller: _controller,
      commit: widget.onCommit,
    );
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      widget.editorSession.markActive(widget.item.node.id);
    } else if (widget.editorSession.shouldCommitOnBlur(widget.item.node.id) &&
        _controller.text != widget.item.node.content) {
      unawaited(widget.onCommit(_controller.text));
    }
  }

  @override
  void didUpdateWidget(covariant NodeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.node.id != widget.item.node.id) {
      oldWidget.editorSession.unregister(oldWidget.item.node.id);
      _register();
    }
    if (!_focusNode.hasFocus && _controller.text != widget.item.node.content) {
      _controller.value = TextEditingValue(
        text: widget.item.node.content,
        selection: TextSelection.collapsed(
          offset: widget.item.node.content.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    widget.editorSession.unregister(widget.item.node.id);
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    _springController.dispose();
    super.dispose();
  }

  void _submitEnter() {
    final selection = _controller.selection;
    final rawCursor = selection.isValid
        ? selection.baseOffset
        : _controller.text.length;
    final cursor = rawCursor.clamp(0, _controller.text.length).toInt();
    unawaited(widget.onEnter(cursor, _controller.text));
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controller.text.trim().isEmpty) {
          unawaited(widget.onBackspaceEmpty());
          return KeyEventResult.handled;
        }
        final selection = _controller.selection;
        if (selection.isValid &&
            selection.isCollapsed &&
            selection.baseOffset == 0 &&
            widget.onBackspaceMerge != null) {
          unawaited(widget.onBackspaceMerge!(0, _controller.text));
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _submitEnter();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (widget.isEditing) return;
    _rawGestureOffset = 0.0;
    _isArmed = false;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.isEditing) return;

    _rawGestureOffset += details.delta.dx;

    if (_rawGestureOffset > 0) {
      // Right swipe: Indent (Spec 20-22)
      if (widget.item.canIndent) {
        double visualPreview;
        if (_rawGestureOffset <= 20) {
          visualPreview = _rawGestureOffset;
        } else {
          visualPreview = 20 + (_rawGestureOffset - 20) * 0.35;
        }
        final armed = _rawGestureOffset > 55;
        if (armed && !_isArmed) {
          HapticFeedback.lightImpact();
        } else if (!armed && _isArmed && _rawGestureOffset < 38) {
          _isArmed = false;
        }
        setState(() {
          _dragOffset = visualPreview;
          if (armed) _isArmed = true;
        });
      } else {
        // Cannot indent: heavy resistance
        setState(() {
          _dragOffset = (_rawGestureOffset * 0.15).clamp(0.0, 16.0);
          _isArmed = false;
        });
      }
    } else if (_rawGestureOffset < 0) {
      // Left swipe: Outdent (Spec 23-24)
      if (widget.item.canOutdent) {
        double visualPreview;
        if (_rawGestureOffset >= -20) {
          visualPreview = _rawGestureOffset;
        } else {
          visualPreview = -20 + (_rawGestureOffset + 20) * 0.35;
        }
        final armed = _rawGestureOffset < -55;
        if (armed && !_isArmed) {
          HapticFeedback.lightImpact();
        } else if (!armed && _isArmed && _rawGestureOffset > -38) {
          _isArmed = false;
        }
        setState(() {
          _dragOffset = visualPreview;
          if (armed) _isArmed = true;
        });
      } else {
        // Cannot outdent: heavy resistance
        setState(() {
          _dragOffset = (_rawGestureOffset * 0.15).clamp(-16.0, 0.0);
          _isArmed = false;
        });
      }
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.isEditing) return;

    if (_isArmed) {
      if (_rawGestureOffset > 55 && widget.item.canIndent) {
        widget.onIndent();
      } else if (_rawGestureOffset < -55 && widget.item.canOutdent) {
        widget.onOutdent();
      }
    }

    _isArmed = false;
    _rawGestureOffset = 0.0;
    _springAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOut),
    );
    _springController.forward(from: 0.0);
  }

  void _onHorizontalDragCancel() {
    _isArmed = false;
    _rawGestureOffset = 0.0;
    _springAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOut),
    );
    _springController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isL1 = widget.item.level == 1;
    final minHeight = isL1 ? 54.0 : 52.0;
    const horizontalMargin = 8.0;
    final innerLeftPadding = isL1
        ? (20.0 - horizontalMargin)
        : (44.0 - horizontalMargin);

    final textStyle = (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
      fontSize: 17,
      height: 1.3,
      color: widget.item.isDone
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurface,
      decoration: widget.item.isDone ? TextDecoration.lineThrough : null,
    );

    final selectionColor = widget.isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : Colors.transparent;

    Widget content;
    if (widget.isEditing) {
      content = TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: false,
        maxLines: 1,
        textInputAction: TextInputAction.next,
        style: textStyle,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: '',
        ),
        onChanged: widget.onChanged,
        onSubmitted: (_) => _submitEnter(),
      );
    } else {
      content = Text(
        widget.item.content,
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: widget.isEditing ? null : _onHorizontalDragStart,
      onHorizontalDragUpdate: widget.isEditing ? null : _onHorizontalDragUpdate,
      onHorizontalDragEnd: widget.isEditing ? null : _onHorizontalDragEnd,
      onHorizontalDragCancel: widget.isEditing ? null : _onHorizontalDragCancel,
      onLongPress: widget.isEditing ? null : widget.onLongPress,
      onTap: () {
        if (widget.isEditing) return;
        if (widget.isSelected) {
          widget.onStartEditing();
        } else {
          widget.onSelect();
        }
      },
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: 2,
          ),
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            color: selectionColor,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              SizedBox(width: innerLeftPadding),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: content,
                ),
              ),
              SizedBox(
                width: 48,
                height: minHeight,
                child: (widget.isSelected && !widget.isEditing)
                    ? IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        tooltip: 'Open',
                        padding: const EdgeInsets.only(right: 6),
                        onPressed: () => unawaited(widget.onNavigate()),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
