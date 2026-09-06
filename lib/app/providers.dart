import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/database/app_database.dart' hide Node;
import '../features/nodes/application/tree_command_service.dart';
import '../features/nodes/data/drift_node_repository.dart';
import '../features/nodes/domain/node.dart';
import '../features/nodes/domain/node_id.dart';
import '../features/nodes/domain/node_repository.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
}

@Riverpod(keepAlive: true)
NodeRepository nodeRepository(Ref ref) {
  return DriftNodeRepository(ref.watch(databaseProvider));
}

@Riverpod(keepAlive: true)
TreeCommandService treeCommandService(Ref ref) {
  final repository = ref.watch(nodeRepositoryProvider);
  if (repository is! TreeMutationRepository) {
    throw StateError('TreeCommandService requires a mutation repository.');
  }
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
