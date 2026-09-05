import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/node_item.dart';

class DatabaseService {
  late Future<Isar> _isar;

  DatabaseService() {
    _isar = _init();
  }

  Future<Isar> get isar => _isar;

  Future<Isar> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open([NodeItemSchema], directory: dir.path);

    // Ensure Root Node Exists
    final rootCount = await isar.nodeItems
        .filter()
        .idEqualTo(kRootNodeId)
        .count();
    if (rootCount == 0) {
      final root = NodeItem()
        ..id = kRootNodeId
        ..content = 'DeepList'
        ..parentId = null;

      await isar.writeTxn(() async {
        await isar.nodeItems.put(root);
      });
    }

    return isar;
  }
}
