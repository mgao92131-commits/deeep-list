import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/node.dart';
import '../editor_session.dart';

class NodeCard extends StatefulWidget {
  final Node node;
  final bool isEditing;
  final EditorSession editorSession;
  final VoidCallback onStartEditing;
  final Future<void> Function(String text) onCommit;
  final ValueChanged<String> onChanged;
  final Future<void> Function(int cursor, String text) onEnter;
  final Future<void> Function(int cursor, String text) onBackspace;
  final Future<void> Function() onNavigate;
  final bool canMergeWithPrevious;

  const NodeCard({
    super.key,
    required this.node,
    required this.isEditing,
    required this.editorSession,
    required this.onStartEditing,
    required this.onCommit,
    required this.onChanged,
    required this.onEnter,
    required this.onBackspace,
    required this.onNavigate,
    required this.canMergeWithPrevious,
  });

  @override
  State<NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<NodeCard> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _atTextStart = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.node.content);
    _controller.addListener(_handleControllerChanged);
    _focusNode = FocusNode(
      debugLabel: 'node-${widget.node.id}',
      onKeyEvent: _handleKeyEvent,
    );
    _focusNode.addListener(_handleFocusChanged);
    _register();
  }

  void _register() {
    widget.editorSession.register(
      nodeId: widget.node.id,
      focusNode: _focusNode,
      controller: _controller,
      commit: widget.onCommit,
    );
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      widget.editorSession.markActive(widget.node.id);
    } else if (widget.editorSession.shouldCommitOnBlur(widget.node.id) &&
        _controller.text != widget.node.content) {
      unawaited(widget.onCommit(_controller.text));
    }
  }

  void _handleControllerChanged() {
    final selection = _controller.selection;
    final atStart =
        selection.isValid && selection.isCollapsed && selection.baseOffset == 0;
    if (atStart != _atTextStart && mounted) {
      setState(() => _atTextStart = atStart);
    }
  }

  @override
  void didUpdateWidget(covariant NodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      oldWidget.editorSession.unregister(oldWidget.node.id);
      _register();
    }
    if (!_focusNode.hasFocus && _controller.text != widget.node.content) {
      _controller.value = TextEditingValue(
        text: widget.node.content,
        selection: TextSelection.collapsed(offset: widget.node.content.length),
      );
    }
  }

  @override
  void dispose() {
    widget.editorSession.unregister(widget.node.id);
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = widget.node.isDone
        ? theme.textTheme.bodyLarge?.copyWith(
            decoration: TextDecoration.lineThrough,
            color: theme.colorScheme.onSurfaceVariant,
          )
        : theme.textTheme.bodyLarge;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: widget.isEditing
            ? TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Write something…',
                  suffixIcon: widget.canMergeWithPrevious && _atTextStart
                      ? IconButton(
                          tooltip: 'Merge with previous',
                          icon: const Icon(Icons.keyboard_backspace),
                          onPressed: () => unawaited(
                            widget.onBackspace(0, _controller.text),
                          ),
                        )
                      : null,
                ),
                onChanged: widget.onChanged,
                onSubmitted: (value) {
                  final selection = _controller.selection;
                  final rawCursor = selection.isValid
                      ? selection.baseOffset
                      : value.length;
                  final cursor = rawCursor.clamp(0, value.length).toInt();
                  unawaited(widget.onEnter(cursor, value));
                },
              )
            : Text(widget.node.content, style: titleStyle),
        trailing: IconButton(
          tooltip: 'Open',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => unawaited(widget.onNavigate()),
        ),
        onTap: widget.isEditing ? null : widget.onStartEditing,
        onLongPress: widget.isEditing ? null : widget.onStartEditing,
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      final selection = _controller.selection;
      if (selection.isValid &&
          selection.isCollapsed &&
          selection.baseOffset == 0) {
        unawaited(widget.onBackspace(0, _controller.text));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
