import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/app/providers.dart';
import 'package:deep_list/features/nodes/application/tree_command_service.dart';
import 'package:deep_list/features/nodes/presentation/providers/smart_nodes_provider.dart';

import '../helpers/memory_node_repository.dart';

void main() {
  group('智能列表查询规则 (Smart List Queries)', () {
    late MemoryNodeRepository repository;
    late TreeCommandService commands;
    late ProviderContainer container;

    setUp(() {
      repository = MemoryNodeRepository();
      commands = TreeCommandService(repository);
      container = ProviderContainer(
        overrides: [
          nodeRepositoryProvider.overrideWithValue(repository),
          treeCommandServiceProvider.overrideWithValue(commands),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      repository.close();
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    Future<List<SmartNodeGroup>> readGroups(SmartListType type) async {
      final sub = container.listen(smartNodesProvider(type), (_, _) {});
      try {
        return await container.read(smartNodesProvider(type).future);
      } finally {
        sub.close();
      }
    }

    group('Favorites 查询', () {
      test('验证 favorite+active 出现，未收藏/已完成/已归档不出现', () async {
        final favActive = await commands.createNode(
          parentId: null,
          content: 'Fav Active',
        );
        await commands.toggleFavorite(favActive.id);

        await commands.createNode(
          parentId: null,
          content: 'Normal Active',
        );

        final favDone = await commands.createNode(
          parentId: null,
          content: 'Fav Done',
        );
        await commands.toggleFavorite(favDone.id);
        await commands.toggleDone(favDone.id);

        final favArchived = await commands.createNode(
          parentId: null,
          content: 'Fav Archived',
        );
        await commands.toggleFavorite(favArchived.id);
        await commands.archiveNode(favArchived.id);

        final groups = await readGroups(SmartListType.favorites);
        final items = [for (final g in groups) ...g.items];

        expect(items.map((it) => it.content), contains('Fav Active'));
        expect(items.map((it) => it.content), isNot(contains('Normal Active')));
        expect(items.map((it) => it.content), isNot(contains('Fav Done')));
        expect(items.map((it) => it.content), isNot(contains('Fav Archived')));
      });
    });

    group('Today 查询', () {
      test('验证昨天+未完成、今天+未完成出现，明天不出现，已完成/已归档不出现', () async {
        // 1. 昨天截止 + 未完成 -> 出现 (已逾期)
        final overdueNode = await commands.createNode(
          parentId: null,
          content: 'Overdue Node',
        );
        await commands.updateDueDate(overdueNode.id, yesterday);

        // 2. 今天截止 + 未完成 -> 出现 (今天)
        final todayNode = await commands.createNode(
          parentId: null,
          content: 'Today Node',
        );
        await commands.updateDueDate(todayNode.id, today);

        // 3. 明天截止 -> 不出现
        final tomorrowNode = await commands.createNode(
          parentId: null,
          content: 'Tomorrow Node',
        );
        await commands.updateDueDate(tomorrowNode.id, tomorrow);

        // 4. 今天截止 + 已完成 -> 不出现
        final todayDone = await commands.createNode(
          parentId: null,
          content: 'Today Done',
        );
        await commands.updateDueDate(todayDone.id, today);
        await commands.toggleDone(todayDone.id);

        // 5. 今天截止 + 已归档 -> 不出现
        final todayArchived = await commands.createNode(
          parentId: null,
          content: 'Today Archived',
        );
        await commands.updateDueDate(todayArchived.id, today);
        await commands.archiveNode(todayArchived.id);

        final groups = await readGroups(SmartListType.today);
        final allItems = [for (final g in groups) ...g.items];

        expect(allItems.map((it) => it.content), contains('Overdue Node'));
        expect(allItems.map((it) => it.content), contains('Today Node'));
        expect(allItems.map((it) => it.content), isNot(contains('Tomorrow Node')));
        expect(allItems.map((it) => it.content), isNot(contains('Today Done')));
        expect(allItems.map((it) => it.content), isNot(contains('Today Archived')));

        // 验证分组：已逾期与今天
        final overdueGroup = groups.firstWhere((g) => g.title == '已逾期');
        final todayGroup = groups.firstWhere((g) => g.title == '今天');

        expect(overdueGroup.items.single.content, 'Overdue Node');
        expect(todayGroup.items.single.content, 'Today Node');
      });
    });

    group('Due Dates 查询', () {
      test('验证有 dueDate 出现，null 不出现，completed/archived 不出现，排序按日期升序', () async {
        final n1 = await commands.createNode(parentId: null, content: 'Later');
        await commands.updateDueDate(n1.id, nextWeek);

        final n2 = await commands.createNode(parentId: null, content: 'Today');
        await commands.updateDueDate(n2.id, today);

        final n3 = await commands.createNode(parentId: null, content: 'Overdue');
        await commands.updateDueDate(n3.id, yesterday);

        final n4 = await commands.createNode(parentId: null, content: 'Tomorrow');
        await commands.updateDueDate(n4.id, tomorrow);

        await commands.createNode(parentId: null, content: 'No Due');

        final dueDone = await commands.createNode(parentId: null, content: 'Due Done');
        await commands.updateDueDate(dueDone.id, today);
        await commands.toggleDone(dueDone.id);

        final dueArchived = await commands.createNode(parentId: null, content: 'Due Archived');
        await commands.updateDueDate(dueArchived.id, today);
        await commands.archiveNode(dueArchived.id);

        final groups = await readGroups(SmartListType.dueDates);
        final allItems = [for (final g in groups) ...g.items];

        expect(allItems.map((it) => it.content), containsAll(['Overdue', 'Today', 'Tomorrow', 'Later']));
        expect(allItems.map((it) => it.content), isNot(contains('No Due')));
        expect(allItems.map((it) => it.content), isNot(contains('Due Done')));
        expect(allItems.map((it) => it.content), isNot(contains('Due Archived')));

        // 验证日期排序：Overdue -> Today -> Tomorrow -> Later
        final contentsInOrder = allItems.map((it) => it.content).toList();
        expect(contentsInOrder, ['Overdue', 'Today', 'Tomorrow', 'Later']);

        // 验证 4 个分组
        expect(groups.map((g) => g.title), ['已逾期', '今天', '明天', '以后']);
      });
    });
  });
}
