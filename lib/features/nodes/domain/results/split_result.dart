import '../node_id.dart';

class SplitResult {
  final NodeId newNodeId;
  final int cursorPosition;

  const SplitResult({required this.newNodeId, required this.cursorPosition});
}
