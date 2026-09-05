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
  NodeId? _pendingFocusNodeId;
  int? _pendingCursor;
  bool _disposed = false;

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

  void unregister(NodeId nodeId) {
    _registrations.remove(nodeId);
    if (activeNodeId == nodeId) {
      activeNodeId = null;
    }
  }

  void markActive(NodeId nodeId) {
    if (_registrations.containsKey(nodeId)) {
      activeNodeId = nodeId;
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
    _pendingFocusNodeId = nodeId;
    _pendingCursor = cursor;
    _schedulePendingFocus();
  }

  void unfocus() {
    // Clear the active editor before unfocusing its FocusNode. This lets the
    // card distinguish an explicit session shutdown from an ordinary blur and
    // avoids committing the same text a second time during navigation.
    activeNodeId = null;
    _pendingFocusNodeId = null;
    _pendingCursor = null;
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

  void _schedulePendingFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final nodeId = _pendingFocusNodeId;
      if (nodeId == null) return;

      final registration = _registrations[nodeId];
      if (registration == null) return;

      final cursor = _pendingCursor;
      _pendingFocusNodeId = null;
      _pendingCursor = null;
      activeNodeId = nodeId;
      registration.focusNode.requestFocus();
      final length = registration.controller.text.length;
      final offset = (cursor ?? length).clamp(0, length).toInt();
      registration.controller.selection = TextSelection.collapsed(
        offset: offset,
      );
    });
  }
}
