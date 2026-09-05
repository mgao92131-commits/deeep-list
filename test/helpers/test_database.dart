import 'package:drift/native.dart';

import 'package:deep_list/core/database/app_database.dart';
import 'package:deep_list/features/nodes/application/tree_command_service.dart';
import 'package:deep_list/features/nodes/data/drift_node_repository.dart';

class TestDatabase {
  late final AppDatabase database = AppDatabase(
    executor: NativeDatabase.memory(),
  );
  late final DriftNodeRepository repository = DriftNodeRepository(database);
  late final TreeCommandService commands = TreeCommandService(repository);

  Future<void> close() => database.close();
}
