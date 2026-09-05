import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:deep_list/src/models/node_item.dart';
import 'package:deep_list/src/repositories/node_repository.dart';
import 'package:deep_list/src/services/database_service.dart';

// Mock DB Service
class TestDatabaseService implements DatabaseService {
  final Isar _isar;
  TestDatabaseService(this._isar);

  @override
  Future<Isar> get isar => Future.value(_isar);
}

void main() {
  late Isar isar;
  late NodeRepository repo;

  setUp(() async {
    await Isar.initializeIsarCore(download: true);

    final dir = Directory.systemTemp.createTempSync();
    isar = await Isar.open([NodeItemSchema], directory: dir.path);

    // Ensure Root
    await isar.writeTxn(() async {
      await isar.nodeItems.put(
        NodeItem()
          ..id = kRootNodeId
          ..content = 'DeepList',
      );
    });

    repo = NodeRepository(TestDatabaseService(isar));
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('Insert and Order', () async {
    final id1 = await repo.insertNode(
      NodeItem()..content = 'A',
      parentId: kRootNodeId,
    );
    final id2 = await repo.insertNode(
      NodeItem()..content = 'B',
      parentId: kRootNodeId,
    );

    final root = await isar.nodeItems.get(kRootNodeId);
    expect(root!.children, [id1, id2]);
  });

  test('Recursive Delete', () async {
    // Root -> A -> B
    final idA = await repo.insertNode(
      NodeItem()..content = 'A',
      parentId: kRootNodeId,
    );
    final idB = await repo.insertNode(NodeItem()..content = 'B', parentId: idA);

    await repo.removeNode(idA);

    expect(await isar.nodeItems.get(idA), isNull);
    expect(await isar.nodeItems.get(idB), isNull);

    final root = await isar.nodeItems.get(kRootNodeId);
    expect(root!.children, isNot(contains(idA)));
  });

  test('Move Node (Paste Logic)', () async {
    // Root -> A
    // Root -> B
    final idA = await repo.insertNode(
      NodeItem()..content = 'A',
      parentId: kRootNodeId,
    );
    final idB = await repo.insertNode(
      NodeItem()..content = 'B',
      parentId: kRootNodeId,
    );

    // Move B to A (so A -> B)
    await repo.moveNode(idB, idA);

    // Verify B's parent is A
    final nodeB = await isar.nodeItems.get(idB);
    expect(nodeB!.parentId, idA);

    // Verify A has B in children
    final nodeA = await isar.nodeItems.get(idA);
    expect(nodeA!.children, contains(idB));

    // Verify Root no longer has B in children
    final root = await isar.nodeItems.get(kRootNodeId);
    expect(root!.children, contains(idA));
    expect(root.children, isNot(contains(idB)));
  });
}
