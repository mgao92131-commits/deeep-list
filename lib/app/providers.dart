import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/database/app_database.dart';
import '../features/nodes/providers.dart';
import '../features/nodes/data/drift_node_repository.dart';
export '../features/nodes/providers.dart';
part 'providers.g.dart';

final nodeRepositoryOverride = nodeRepositoryProvider.overrideWith(
  (ref) => DriftNodeRepository(ref.watch(databaseProvider)),
);

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
}
