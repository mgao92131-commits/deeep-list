import 'package:flutter/foundation.dart';

import '../../domain/node_id.dart';

enum PageMode { normal, editing, dragging }

class EditingState {
  final PageMode mode;
  final NodeId? activeNodeId;
  final bool isSaving;
  final bool isSelectingDueDate;

  const EditingState({
    this.mode = PageMode.normal,
    this.activeNodeId,
    this.isSaving = false,
    this.isSelectingDueDate = false,
  });

  NodeId? get editingNodeId => mode == PageMode.editing ? activeNodeId : null;
  NodeId? get draggingNodeId => mode == PageMode.dragging ? activeNodeId : null;
  bool get isNormal => mode == PageMode.normal;
  bool get isEditing => mode == PageMode.editing;
  bool get isDragging => mode == PageMode.dragging;
  bool isNodeEditing(NodeId id) => editingNodeId == id;
  bool isNodeDragging(NodeId id) => draggingNodeId == id;

  EditingState copyWith({
    PageMode? mode,
    Object? activeNodeId = _unset,
    bool? isSaving,
    bool? isSelectingDueDate,
  }) => EditingState(
    mode: mode ?? this.mode,
    activeNodeId: identical(activeNodeId, _unset)
        ? this.activeNodeId
        : activeNodeId as NodeId?,
    isSaving: isSaving ?? this.isSaving,
    isSelectingDueDate: isSelectingDueDate ?? this.isSelectingDueDate,
  );
}

const _unset = Object();

/// Sole owner of the editing intent. Focus observations never select a node.
class EditingController extends ValueNotifier<EditingState> {
  EditingController() : super(const EditingState());
  int _saves = 0;
  bool _disposed = false;

  void startEditing(NodeId id) {
    if (_disposed || value.editingNodeId == id) return;
    value = EditingState(
      mode: PageMode.editing,
      activeNodeId: id,
      isSaving: _saves > 0,
    );
  }

  void startDragging(NodeId id) {
    if (_disposed) return;
    value = EditingState(
      mode: PageMode.dragging,
      activeNodeId: id,
      isSaving: _saves > 0,
    );
  }

  void endEditing() {
    if (_disposed || value.isNormal) return;
    value = EditingState(isSaving: _saves > 0);
  }

  void selectDueDate(bool active) {
    if (_disposed || value.isSelectingDueDate == active) return;
    value = value.copyWith(isSelectingDueDate: active);
  }

  Future<T> saving<T>(Future<T> Function() operation) async {
    _saves++;
    if (!_disposed) value = value.copyWith(isSaving: true);
    try {
      return await operation();
    } finally {
      _saves--;
      if (!_disposed) value = value.copyWith(isSaving: _saves > 0);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
