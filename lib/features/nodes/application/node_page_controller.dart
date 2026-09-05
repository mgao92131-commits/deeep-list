import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/node_id.dart';

part 'node_page_controller.g.dart';

class NodePageState {
  final NodeId? editingNodeId;
  final Set<NodeId> selectedNodeIds;

  const NodePageState({
    this.editingNodeId,
    this.selectedNodeIds = const <NodeId>{},
  });

  NodePageState copyWith({
    Object? editingNodeId = _unset,
    Set<NodeId>? selectedNodeIds,
  }) {
    return NodePageState(
      editingNodeId: identical(editingNodeId, _unset)
          ? this.editingNodeId
          : editingNodeId as NodeId?,
      selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
    );
  }
}

const _unset = Object();

@riverpod
class NodePageController extends _$NodePageController {
  @override
  NodePageState build(NodeId? parentId) => const NodePageState();

  void startEditing(NodeId nodeId) {
    state = state.copyWith(editingNodeId: nodeId);
  }

  void endEditing() {
    state = state.copyWith(editingNodeId: null);
  }

  void toggleSelection(NodeId nodeId) {
    final selected = {...state.selectedNodeIds};
    if (!selected.add(nodeId)) {
      selected.remove(nodeId);
    }
    state = state.copyWith(selectedNodeIds: selected);
  }
}
