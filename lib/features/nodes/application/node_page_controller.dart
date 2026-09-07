import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/node_id.dart';

part 'node_page_controller.g.dart';

enum PageMode { normal, editing, dragging }

class NodePageState {
  final PageMode mode;
  final NodeId? activeNodeId;

  const NodePageState({this.mode = PageMode.normal, this.activeNodeId});

  NodeId? get editingNodeId => mode == PageMode.editing ? activeNodeId : null;
  NodeId? get draggingNodeId => mode == PageMode.dragging ? activeNodeId : null;

  bool get isNormal => mode == PageMode.normal;
  bool get isEditing => mode == PageMode.editing;
  bool get isDragging => mode == PageMode.dragging;

  bool isNodeEditing(NodeId id) =>
      mode == PageMode.editing && activeNodeId == id;
  bool isNodeDragging(NodeId id) =>
      mode == PageMode.dragging && activeNodeId == id;

  NodePageState copyWith({PageMode? mode, Object? activeNodeId = _unset}) {
    return NodePageState(
      mode: mode ?? this.mode,
      activeNodeId: identical(activeNodeId, _unset)
          ? this.activeNodeId
          : activeNodeId as NodeId?,
    );
  }
}

const _unset = Object();

@riverpod
class NodePageController extends _$NodePageController {
  @override
  NodePageState build(NodeId? parentId) => const NodePageState();

  void startEditing(NodeId nodeId) {
    state = NodePageState(mode: PageMode.editing, activeNodeId: nodeId);
  }

  void startDragging(NodeId nodeId) {
    state = NodePageState(mode: PageMode.dragging, activeNodeId: nodeId);
  }

  void endEditing() {
    state = const NodePageState();
  }

  void toNormal() {
    state = const NodePageState();
  }
}
