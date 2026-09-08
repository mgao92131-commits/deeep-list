import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/node_id.dart';
import 'editing_controller.dart';
export 'editing_controller.dart' show PageMode;

part 'node_page_controller.g.dart';

typedef NodePageState = EditingState;

@riverpod
class NodePageController extends _$NodePageController {
  late EditingController editing;
  @override
  NodePageState build(NodeId? parentId) {
    editing = EditingController();
    void sync() => state = editing.value;
    editing.addListener(sync);
    ref.onDispose(() {
      editing.removeListener(sync);
      editing.dispose();
    });
    return editing.value;
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
