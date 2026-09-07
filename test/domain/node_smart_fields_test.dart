import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/core/database/app_database.dart' as db;
import 'package:deep_list/features/nodes/application/tree_command_service.dart';
import 'package:deep_list/features/nodes/data/drift_node_repository.dart';
import 'package:deep_list/features/nodes/domain/node.dart';

void main() {
  group('数据逻辑 (Data Logic & Persistence)', () {
    late db.AppDatabase database;
    late DriftNodeRepository repository;
    late TreeCommandService commands;

    setUp(() {
      database = db.AppDatabase(executor: NativeDatabase.memory());
      repository = DriftNodeRepository(database);
      commands = TreeCommandService(repository);
    });

    tearDown(() => database.close());

    test('新节点默认 favorite == false, dueDate == null', () async {
      final node = await commands.createNode(
        parentId: null,
        content: 'New Item',
      );

      expect(node.isFavorite, isFalse);
      expect(node.dueDate, isNull);

      final loaded = await repository.getNode(node.id);
      expect(loaded!.isFavorite, isFalse);
      expect(loaded.dueDate, isNull);
    });

    test('收藏状态可以持久化并切换', () async {
      final node = await commands.createNode(
        parentId: null,
        content: 'Fav Item',
      );

      await commands.toggleFavorite(node.id);
      final favorited = await repository.getNode(node.id);
      expect(favorited!.isFavorite, isTrue);

      await commands.toggleFavorite(node.id);
      final unfavorited = await repository.getNode(node.id);
      expect(unfavorited!.isFavorite, isFalse);
    });

    test('截止日期可以设置、修改、删除', () async {
      final node = await commands.createNode(
        parentId: null,
        content: 'Due Item',
      );

      final date1 = DateTime(2026, 9, 15);
      await commands.updateDueDate(node.id, date1);
      final loaded1 = await repository.getNode(node.id);
      expect(loaded1!.dueDate, date1);

      final date2 = DateTime(2026, 9, 20);
      await commands.updateDueDate(node.id, date2);
      final loaded2 = await repository.getNode(node.id);
      expect(loaded2!.dueDate, date2);

      await commands.updateDueDate(node.id, null);
      final loaded3 = await repository.getNode(node.id);
      expect(loaded3!.dueDate, isNull);
    });

    test('父节点属性不会影响子节点 (无继承)', () async {
      final parent = await commands.createNode(
        parentId: null,
        content: 'Parent',
      );
      final child = await commands.createNode(
        parentId: parent.id,
        content: 'Child',
      );

      // 给父节点收藏并设置日期
      await commands.toggleFavorite(parent.id);
      await commands.updateDueDate(parent.id, DateTime(2026, 9, 30));

      final loadedParent = await repository.getNode(parent.id);
      final loadedChild = await repository.getNode(child.id);

      expect(loadedParent!.isFavorite, isTrue);
      expect(loadedParent.dueDate, DateTime(2026, 9, 30));

      // 子节点必须保持未收藏且 dueDate 为 null
      expect(loadedChild!.isFavorite, isFalse);
      expect(loadedChild.dueDate, isNull);
    });

    test('normalizeDate 只保留年月日语义', () {
      final withTime = DateTime(2026, 9, 15, 18, 30, 45);
      final normalized = Node.normalizeDate(withTime);

      expect(normalized!.year, 2026);
      expect(normalized.month, 9);
      expect(normalized.day, 15);
      expect(normalized.hour, 0);
      expect(normalized.minute, 0);
      expect(normalized.second, 0);
    });
  });
}
