import 'package:flutter/widgets.dart';

import '../domain/node_id.dart';

typedef EditorCommit = Future<void> Function(String text);

class _EditorRegistration {
  final FocusNode focusNode;
  final TextEditingController controller;
  final EditorCommit commit;

  const _EditorRegistration({
    required this.focusNode,
    required this.controller,
    required this.commit,
  });
}

class EditorSession {
  final Map<NodeId, _EditorRegistration> _registrations = {};
  final Set<NodeId> _blurCommitSuppressed = {};
  NodeId? activeNodeId;
  bool isSelectingDueDate = false;
  NodeId? _pendingFocusNodeId;
  int? _pendingCursor;
  int _focusGeneration = 0;
  bool _disposed = false;

  NodeId? _handoverFrom;
  NodeId? _handoverTo;

  bool get hasPendingFocus => _pendingFocusNodeId != null;
  NodeId? get pendingFocusNodeId => _pendingFocusNodeId;
  int get focusGeneration => _focusGeneration;

  bool get isHandingOver => _handoverTo != null;
  NodeId? get handoverTarget => _handoverTo;
  NodeId? get handoverSource => _handoverFrom;

  bool isFocused(NodeId nodeId) {
    return _registrations[nodeId]?.focusNode.hasFocus ?? false;
  }

  String? get activeText {
    final nodeId = activeNodeId;
    if (nodeId == null) return null;
    return _registrations[nodeId]?.controller.text;
  }

  void register({
    required NodeId nodeId,
    required FocusNode focusNode,
    required TextEditingController controller,
    required EditorCommit commit,
  }) {
    if (_disposed) return;
    _registrations[nodeId] = _EditorRegistration(
      focusNode: focusNode,
      controller: controller,
      commit: commit,
    );
    if (_pendingFocusNodeId == nodeId) {
      _schedulePendingFocus();
    }
  }

  void _clearHandover() {
    _handoverFrom = null;
    _handoverTo = null;
  }

  void unregister(NodeId nodeId) {
    _registrations.remove(nodeId);
    if (activeNodeId == nodeId) {
      activeNodeId = null;
    }
    if (_pendingFocusNodeId == nodeId) {
      _pendingFocusNodeId = null;
      _pendingCursor = null;
    }
    if (_handoverTo == nodeId || _handoverFrom == nodeId) {
      _clearHandover();
    }
  }

  void markActive(NodeId nodeId) {
    if (_registrations.containsKey(nodeId)) {
      activeNodeId = nodeId;
      if (_handoverTo == nodeId && isFocused(nodeId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_disposed) return;
          if (_handoverTo == nodeId && isFocused(nodeId)) {
            _clearHandover();
          }
        });
      }
    }
  }

  void suppressBlurCommit(NodeId nodeId) {
    _blurCommitSuppressed.add(nodeId);
  }

  void allowBlurCommit(NodeId nodeId) {
    _blurCommitSuppressed.remove(nodeId);
  }

  bool shouldCommitOnBlur(NodeId nodeId) {
    return activeNodeId == nodeId && !_blurCommitSuppressed.contains(nodeId);
  }

  Future<void> commitActive() async {
    final nodeId = activeNodeId;
    if (nodeId == null) return;
    final registration = _registrations[nodeId];
    if (registration == null) return;
    await registration.commit(registration.controller.text);
  }

  void focus(NodeId nodeId, {int? cursor}) {
    if (_disposed) return;
    _focusGeneration++;
    _pendingFocusNodeId = nodeId;
    _pendingCursor = cursor;
    _schedulePendingFocus();
  }

  void handoverFocus(NodeId from, NodeId to, {int? cursor}) {
    if (_disposed) return;
    _focusGeneration++;
    final generation = _focusGeneration;
    _handoverFrom = from;
    _handoverTo = to;
    suppressBlurCommit(from);
    _pendingFocusNodeId = to;
    _pendingCursor = cursor;
    final toRegistration = _registrations[to];
    if (toRegistration != null) {
      _pendingFocusNodeId = null;
      _pendingCursor = null;
      activeNodeId = to;
      _requestFocusAndVerify(to, toRegistration, cursor, generation);
    } else {
      _schedulePendingFocus();
    }
    allowBlurCommit(from);
  }

  void unfocus() {
    // Clear the active editor before unfocusing its FocusNode. This lets the
    // card distinguish an explicit session shutdown from an ordinary blur and
    // avoids committing the same text a second time during navigation.
    _focusGeneration++;
    activeNodeId = null;
    _pendingFocusNodeId = null;
    _pendingCursor = null;
    _clearHandover();
    _blurCommitSuppressed.clear();
    for (final registration in _registrations.values) {
      registration.focusNode.unfocus();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> endEditing() async {
    await commitActive();
    unfocus();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unfocus();
    _registrations.clear();
  }

  void _applyCursor(NodeId nodeId, int? cursor) {
    final registration = _registrations[nodeId];
    if (registration == null) return;
    final length = registration.controller.text.length;
    final offset = (cursor ?? length).clamp(0, length).toInt();
    registration.controller.selection = TextSelection.collapsed(offset: offset);
  }

  void _requestFocusAndVerify(
    NodeId nodeId,
    _EditorRegistration registration,
    int? cursor,
    int generation,
  ) {
    registration.focusNode.requestFocus();
    _applyCursor(nodeId, cursor);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (_focusGeneration != generation) return;
      if (activeNodeId != nodeId && _pendingFocusNodeId != nodeId) return;

      if (!registration.focusNode.hasFocus) {
        registration.focusNode.requestFocus();
        _applyCursor(nodeId, cursor);
      }
      if (registration.focusNode.hasFocus && _handoverTo == nodeId) {
        _clearHandover();
      }
    });
  }

  void _schedulePendingFocus() {
    final generation = _focusGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (_focusGeneration != generation) return;
      final nodeId = _pendingFocusNodeId;
      if (nodeId == null) return;

      final registration = _registrations[nodeId];
      if (registration == null) return;

      final cursor = _pendingCursor;
      _pendingFocusNodeId = null;
      _pendingCursor = null;
      activeNodeId = nodeId;
      _requestFocusAndVerify(nodeId, registration, cursor, generation);
    });
  }
}
