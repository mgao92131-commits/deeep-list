import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/node_id.dart';

part 'node_page_controller.g.dart';

enum PageMode { normal, selected, editing, dragging }

class NodePageState {
  final PageMode mode;
  final NodeId? activeNodeId;

  const NodePageState({this.mode = PageMode.normal, this.activeNodeId});

  NodeId? get editingNodeId => mode == PageMode.editing ? activeNodeId : null;
  NodeId? get selectedNodeId => mode == PageMode.selected ? activeNodeId : null;
  NodeId? get draggingNodeId => mode == PageMode.dragging ? activeNodeId : null;

  bool get isNormal => mode == PageMode.normal;
  bool isSelected(NodeId id) => mode == PageMode.selected && activeNodeId == id;
  bool isEditing(NodeId id) => mode == PageMode.editing && activeNodeId == id;
  bool isDragging(NodeId id) => mode == PageMode.dragging && activeNodeId == id;

  Set<NodeId> get selectedNodeIds =>
      selectedNodeId != null ? {selectedNodeId!} : const <NodeId>{};

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

  void selectNode(NodeId nodeId) {
    state = NodePageState(mode: PageMode.selected, activeNodeId: nodeId);
  }

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

  void toggleSelection(NodeId nodeId) {
    if (state.isSelected(nodeId)) {
      toNormal();
    } else {
      selectNode(nodeId);
    }
  }
}
