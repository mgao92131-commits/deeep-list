import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/node_id.dart';
import 'editing_controller.dart';
export 'editing_controller.dart' show PageMode;

part 'node_page_controller.g.dart';

typedef NodePageState = EditingState;

@riverpod
class NodePageController extends _$NodePageController {
  late EditingController editing;
  late final void Function() _syncEditing;

  @override
  NodePageState build(NodeId? parentId) {
    editing = EditingController();
    _syncEditing = () => state = editing.value;
    editing.addListener(_syncEditing);
    ref.onDispose(() {
      editing.removeListener(_syncEditing);
      editing.dispose();
    });
    return editing.value;
  }

  void detachEditingSync() {
    editing.removeListener(_syncEditing);
  }

  void startEditing(NodeId nodeId) {
    editing.startEditing(nodeId);
  }

  void startDragging(NodeId nodeId) {
    editing.startDragging(nodeId);
  }

  void endEditing() {
    editing.endEditing();
  }

  void toNormal() {
    editing.endEditing();
  }
}
