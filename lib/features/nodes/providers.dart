import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'application/tree_command_service.dart';
import 'domain/node.dart';
import 'domain/node_id.dart';
import 'domain/node_repository.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
TreeMutationRepository nodeRepository(Ref ref) {
  throw StateError('Nodes repository must be supplied by the app.');
}

@Riverpod(keepAlive: true)
TreeCommandService treeCommandService(Ref ref) {
  final repository = ref.watch(nodeRepositoryProvider);
  return TreeCommandService(repository);
}

@riverpod
Stream<Node?> node(Ref ref, NodeId nodeId) {
  return ref.watch(nodeRepositoryProvider).watchNode(nodeId);
}

@riverpod
Stream<List<Node>> children(Ref ref, NodeId? parentId) {
  return ref.watch(nodeRepositoryProvider).watchChildren(parentId);
}

@riverpod
Stream<Map<NodeId, int>> childCounts(Ref ref) {
  return ref.watch(nodeRepositoryProvider).watchAllChildCounts();
}
