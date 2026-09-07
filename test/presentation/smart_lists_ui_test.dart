import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/app/app.dart';
import 'package:deep_list/app/providers.dart';
import 'package:deep_list/features/nodes/application/node_page_controller.dart';
import 'package:deep_list/features/nodes/application/tree_command_service.dart';
import 'package:deep_list/features/nodes/presentation/smart_node_page.dart';
import 'package:deep_list/features/nodes/presentation/widgets/keyboard_toolbar.dart';
import 'package:deep_list/features/nodes/presentation/widgets/smart_entries_bar.dart';

import '../helpers/memory_node_repository.dart';

void main() {
  group('智能入口与智能列表 UI 测试 (Smart Entries & Pages UI)', () {
    late MemoryNodeRepository repository;
    late TreeCommandService commands;

    setUp(() {
      repository = MemoryNodeRepository();
      commands = TreeCommandService(repository);
    });

    Future<void> pumpApp(WidgetTester tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await repository.close();
        await tester.pump();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nodeRepositoryProvider.overrideWithValue(repository),
            treeCommandServiceProvider.overrideWithValue(commands),
          ],
          child: const DeepListApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('三个智能入口只在最顶层主页出现，普通子节点页面不出现', (tester) async {
      final parent = await commands.createNode(
        parentId: null,
        content: 'Parent Node',
      );
      await commands.createNode(
        parentId: parent.id,
        content: 'Child Node',
      );

      await pumpApp(tester);

      // 最顶层主页：SmartEntriesBar 存在，包含三个入口
      expect(find.byType(SmartEntriesBar), findsOneWidget);
      expect(find.byKey(const ValueKey('smart-entry-today')), findsOneWidget);
      expect(find.byKey(const ValueKey('smart-entry-favorites')), findsOneWidget);
      expect(find.byKey(const ValueKey('smart-entry-due-dates')), findsOneWidget);

      // 点击右侧下钻进入子节点页面
      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      // 子节点页面标题为 Parent Node
      expect(find.text('Parent Node'), findsOneWidget);

      // 子节点页面中绝不显示 SmartEntriesBar
      expect(find.byType(SmartEntriesBar), findsNothing);
      expect(find.byKey(const ValueKey('smart-entry-today')), findsNothing);
      expect(find.byKey(const ValueKey('smart-entry-favorites')), findsNothing);
      expect(find.byKey(const ValueKey('smart-entry-due-dates')), findsNothing);
    });

    testWidgets('点击三个入口分别导航到独立页面 (今天、收藏、截止日期)', (tester) async {
      await pumpApp(tester);

      // 1. 点击“今天”
      await tester.tap(find.byKey(const ValueKey('smart-entry-today')));
      await tester.pumpAndSettle();
      expect(find.byType(SmartNodePage), findsOneWidget);
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('今天没有待处理的节点'), findsOneWidget);

      // 返回主页
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('DeepList'), findsOneWidget);

      // 2. 点击“收藏”
      await tester.tap(find.byKey(const ValueKey('smart-entry-favorites')));
      await tester.pumpAndSettle();
      expect(find.byType(SmartNodePage), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('还没有收藏节点'), findsOneWidget);

      // 返回主页
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('DeepList'), findsOneWidget);

      // 3. 点击“截止日期”
      await tester.tap(find.byKey(const ValueKey('smart-entry-due-dates')));
      await tester.pumpAndSettle();
      expect(find.byType(SmartNodePage), findsOneWidget);
      expect(find.text('截止日期'), findsOneWidget);
      expect(find.text('还没有设置截止日期'), findsOneWidget);

      // 返回主页
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('DeepList'), findsOneWidget);
    });

    testWidgets('NodeRow 收藏节点显示实心星星，未收藏不显示空星，子节点数量仍在最右侧', (tester) async {
      final p1 = await commands.createNode(parentId: null, content: 'Fav Item');
      await commands.toggleFavorite(p1.id);
      await commands.createNode(parentId: p1.id, content: 'Child 1');
      await commands.createNode(parentId: p1.id, content: 'Child 2');

      await commands.createNode(parentId: null, content: 'Unfav Item');

      await pumpApp(tester);

      // Fav Item 显示实心金星
      expect(find.byIcon(Icons.star), findsOneWidget);
      // 未收藏节点不显示空星
      expect(find.text('☆'), findsNothing);

      // 子节点数量显示在最右侧 (2)
      expect(find.text('2'), findsOneWidget);

      // 取消收藏后，实心星消失，但文本依然稳定
      await commands.toggleFavorite(p1.id);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('键盘工具栏收藏 Toggle 不会结束编辑，焦点保持在 TextField', (tester) async {
      final node = await commands.createNode(parentId: null, content: 'Task to Favorite');
      await pumpApp(tester);

      // 点击进入编辑
      await tester.tap(find.text('Task to Favorite'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyboardToolbar), findsOneWidget);
      final toolbarFavBtn = find.descendant(
        of: find.byType(KeyboardToolbar),
        matching: find.byTooltip('收藏'),
      );
      expect(toolbarFavBtn, findsOneWidget);

      // 点击收藏
      await tester.tap(toolbarFavBtn);
      await tester.pumpAndSettle();

      // 验证数据已收藏
      final updated = await repository.getNode(node.id);
      expect(updated!.isFavorite, isTrue);

      // 验证仍在编辑状态，焦点仍在 TextField
      final container = ProviderScope.containerOf(tester.element(find.byType(DeepListApp)));
      final controller = container.read(nodePageControllerProvider(null));
      expect(controller.mode, PageMode.editing);
      expect(controller.editingNodeId, node.id);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);

      // 图标变为取消收藏
      expect(find.byTooltip('取消收藏'), findsOneWidget);
    });

    testWidgets('智能列表中完成节点立即从智能列表消失', (tester) async {
      final favNode = await commands.createNode(parentId: null, content: 'Favorite Task');
      await commands.toggleFavorite(favNode.id);

      await pumpApp(tester);

      // 进入收藏页面
      await tester.tap(find.byKey(const ValueKey('smart-entry-favorites')));
      await tester.pumpAndSettle();

      expect(find.text('Favorite Task'), findsOneWidget);

      // 点击节点进入编辑
      await tester.tap(find.text('Favorite Task'));
      await tester.pumpAndSettle();

      // 点击完成
      await tester.tap(find.byTooltip('完成'));
      await tester.pumpAndSettle();

      // 该节点从收藏列表立即消失，显示空状态
      expect(find.text('Favorite Task'), findsNothing);
      expect(find.text('还没有收藏节点'), findsOneWidget);

      // 数据库中该节点的 isFavorite 仍然完好保留
      final nodeInDb = await repository.getNode(favNode.id);
      expect(nodeInDb!.isDone, isTrue);
      expect(nodeInDb.isFavorite, isTrue);
    });
  });
}
