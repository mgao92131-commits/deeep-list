import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NodeReorderRegion extends StatefulWidget {
  final int index;
  final bool enabled;
  final VoidCallback onLongPressRelease;
  final Widget child;

  const NodeReorderRegion({
    super.key,
    required this.index,
    required this.enabled,
    required this.onLongPressRelease,
    required this.child,
  });

  @override
  State<NodeReorderRegion> createState() => _NodeReorderRegionState();
}

class _NodeReorderRegionState extends State<NodeReorderRegion> {
  Offset? _downPosition;
  bool _longPressArmed = false;
  bool _movedAfterLongPress = false;
  Timer? _longPressTimer;

  void _cancelTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _reset() {
    _cancelTimer();
    _downPosition = null;
    _longPressArmed = false;
    _movedAfterLongPress = false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    _reset();
    _downPosition = event.position;
    _longPressTimer = Timer(kLongPressTimeout, () {
      if (!mounted) return;
      _longPressArmed = true;
      HapticFeedback.lightImpact();
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.enabled || _downPosition == null) return;
    final distance = (event.position - _downPosition!).distance;

    if (!_longPressArmed) {
      if (distance > kTouchSlop) {
        _cancelTimer();
        _downPosition = null;
      }
    } else {
      if (distance > 12.0) {
        _movedAfterLongPress = true;
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _cancelTimer();
    if (widget.enabled && _longPressArmed && !_movedAfterLongPress) {
      final onRelease = widget.onLongPressRelease;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onRelease();
      });
    }
    _downPosition = null;
    _longPressArmed = false;
    _movedAfterLongPress = false;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _reset();
  }

  @override
  void didUpdateWidget(covariant NodeReorderRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _reset();
    }
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: ReorderableDelayedDragStartListener(
        index: widget.index,
        enabled: widget.enabled,
        child: widget.child,
      ),
    );
  }
}
