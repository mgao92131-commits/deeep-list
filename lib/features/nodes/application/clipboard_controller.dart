import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/node_id.dart';

part 'clipboard_controller.g.dart';

@Riverpod(keepAlive: true)
class ClipboardController extends _$ClipboardController {
  @override
  NodeId? build() => null;

  void cut(NodeId nodeId) {
    state = nodeId;
  }

  void clear() {
    state = null;
  }
}
