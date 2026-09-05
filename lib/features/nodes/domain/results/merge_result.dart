import '../node_id.dart';

class MergeResult {
  final NodeId targetNodeId;
  final int cursorPosition;

  const MergeResult({required this.targetNodeId, required this.cursorPosition});
}
