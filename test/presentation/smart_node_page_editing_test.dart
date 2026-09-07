import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/app/app.dart';
import 'package:deep_list/app/providers.dart';
import 'package:deep_list/features/nodes/application/tree_command_service.dart';
import 'package:deep_list/features/nodes/presentation/widgets/keyboard_toolbar.dart';
import 'package:deep_list/features/nodes/presentation/widgets/node_row.dart';

import '../helpers/memory_node_repository.dart';

void main() {
  group('SmartNodePage 编辑生命周期与交互规则测试', () {
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

    testWidgets('焦点转移 Handover: 在智能列表中点击 A 编辑，再点击 B，无缝切换焦点并保存 A', (
      tester,
    ) async {
      final a = await commands.createNode(parentId: null, content: 'Item A');
      await commands.toggleFavorite(a.id);
      final b = await commands.createNode(parentId: null, content: 'Item B');
      await commands.toggleFavorite(b.id);

      await pumpApp(tester);

      // 进入收藏页
      await tester.tap(find.byKey(const ValueKey('smart-entry-favorites')));
      await tester.pumpAndSettle();

      // 点击 Item A 进入编辑
      await tester.tap(find.text('Item A'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      var field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Item A');
      expect(field.focusNode!.hasFocus, isTrue);

      // 修改 A 的内容为 A Edited
      field.controller!.text = 'Item A Edited';

      // 直接点击 Item B
      await tester.tap(find.text('Item B'));
      await tester.pumpAndSettle();

      // 验证现在聚焦在 Item B
      expect(find.byType(TextField), findsOneWidget);
      field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Item B');
      expect(field.focusNode!.hasFocus, isTrue);

      // 验证 Item A 的修改已保存到数据库
      final savedA = await repository.getNode(a.id);
      expect(savedA!.content, 'Item A Edited');
    });

    testWidgets('Enter 键规则: 保存并退出编辑，不创建 sibling 同级节点', (tester) async {
      final a = await commands.createNode(
        parentId: null,
        content: 'Single Item',
      );
      await commands.toggleFavorite(a.id);

      await pumpApp(tester);

      // 进入收藏页
      await tester.tap(find.byKey(const ValueKey('smart-entry-favorites')));
      await tester.pumpAndSettle();

      // 点击进入编辑
      await tester.tap(find.text('Single Item'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.text = 'Single Item Modified';

      // 模拟按 Enter (TextInputAction.done)
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // 验证退出编辑状态，TextField 消失
      expect(find.byType(TextField), findsNothing);

      // 验证内容已保存
      final updated = await repository.getNode(a.id);
      expect(updated!.content, 'Single Item Modified');

      // 验证没有创建新的同级节点（总数仍为 1）
      final allNodes = await repository.getChildren(null);
      expect(allNodes.length, 1);
    });

    testWidgets('空内容退出编辑时删除节点', (tester) async {
      final a = await commands.createNode(
        parentId: null,
        content: 'To Be Emptied',
      );
      await commands.toggleFavorite(a.id);

      await pumpApp(tester);

      // 进入收藏页
      await tester.tap(find.byKey(const ValueKey('smart-entry-favorites')));
      await tester.pumpAndSettle();

      // 点击进入编辑
      await tester.tap(find.text('To Be Emptied'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.text = '';

      // 按 Enter 提交空内容
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // 验证该节点已被删除，收藏页显示空状态
      expect(find.text('To Be Emptied'), findsNothing);
      expect(find.text('还没有收藏节点'), findsOneWidget);

      final nodeInDb = await repository.getNode(a.id);
      expect(nodeInDb, isNull);
    });

    testWidgets('主动清理离开列表: 在今天页把日期改为未来，主动结束编辑并清理 _editingNodeId 与键盘', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final node = await commands.createNode(
        parentId: null,
        content: 'Today Task',
      );
      await commands.updateDueDate(node.id, today);

      await pumpApp(tester);

      // 进入今天页
      await tester.tap(find.byKey(const ValueKey('smart-entry-today')));
      await tester.pumpAndSettle();

      expect(find.text('Today Task'), findsOneWidget);

      // 点击进入编辑
      await tester.tap(find.text('Today Task'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyboardToolbar), findsOneWidget);

      // 打开截止日期快捷菜单，选择“明天”
      await tester.tap(find.byTooltip('截止日期'));
      await tester.pumpAndSettle();

      final tomorrowItemFinder = find.byWidgetPredicate(
        (w) => w is PopupMenuItem<String> && w.value == 'tomorrow',
      );
      await tester.tap(tomorrowItemFinder);
      await tester.pumpAndSettle();

      // 节点由于日期变成未来而离开“今天”列表
      expect(find.text('Today Task'), findsNothing);
      expect(find.text('今天没有待处理的节点'), findsOneWidget);

      // 键盘工具栏和 TextField 均已主动清理，没有悬空的 editingNodeId
      expect(find.byType(KeyboardToolbar), findsNothing);
      expect(find.byType(TextField), findsNothing);

      // 数据库中日期已更新为明天
      final updated = await repository.getNode(node.id);
      expect(updated!.dueDate!.day, today.add(const Duration(days: 1)).day);
    });

    testWidgets('主动清理离开列表: 在收藏页取消收藏，主动结束编辑并清理 _editingNodeId 与键盘', (
      tester,
    ) async {
      final node = await commands.createNode(
        parentId: null,
        content: 'Fav Task',
      );
      await commands.toggleFavorite(node.id);

      await pumpApp(tester);

      // 进入收藏页
      await tester.tap(find.byKey(const ValueKey('smart-entry-favorites')));
      await tester.pumpAndSettle();

      // 点击进入编辑
      await tester.tap(find.text('Fav Task'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyboardToolbar), findsOneWidget);

      // 点击工具栏“取消收藏”
      await tester.tap(find.byTooltip('取消收藏'));
      await tester.pumpAndSettle();

      // 节点从收藏页离开
      expect(find.text('Fav Task'), findsNothing);
      expect(find.text('还没有收藏节点'), findsOneWidget);

      // 状态已清理
      expect(find.byType(KeyboardToolbar), findsNothing);
      expect(find.byType(TextField), findsNothing);

      final updated = await repository.getNode(node.id);
      expect(updated!.isFavorite, isFalse);
    });

    testWidgets('日期未离开列表时保持/恢复 TextField 焦点', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final node = await commands.createNode(
        parentId: null,
        content: 'Due Stay Task',
      );
      await commands.updateDueDate(node.id, today);

      await pumpApp(tester);

      // 进入今天页
      await tester.tap(find.byKey(const ValueKey('smart-entry-today')));
      await tester.pumpAndSettle();

      // 点击进入编辑
      await tester.tap(find.text('Due Stay Task'));
      await tester.pumpAndSettle();

      var field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);

      // 打开截止日期快捷菜单，选“今天” (仍然在今天列表中)
      await tester.tap(find.byTooltip('截止日期'));
      await tester.pumpAndSettle();

      final todayItemFinder = find.byWidgetPredicate(
        (w) => w is PopupMenuItem<String> && w.value == 'today',
      );
      await tester.tap(todayItemFinder);
      await tester.pumpAndSettle();

      // 焦点自动恢复到 TextField
      field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);

      // 打开菜单后点击外部关闭 (取消菜单)
      await tester.tap(find.byTooltip('截止日期'));
      await tester.pumpAndSettle();

      // 点击背景区域以取消弹出菜单
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // 焦点依然保持/恢复在 TextField
      field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('禁止手势右滑/左滑缩进与拖动重排 (enableSwipeGestures = false)', (
      tester,
    ) async {
      final a = await commands.createNode(parentId: null, content: 'Node 1');
      await commands.toggleFavorite(a.id);
      final b = await commands.createNode(parentId: null, content: 'Node 2');
      await commands.toggleFavorite(b.id);

      await pumpApp(tester);

      // 进入收藏页
      await tester.tap(find.byKey(const ValueKey('smart-entry-favorites')));
      await tester.pumpAndSettle();

      // 获取 NodeRow
      final rowFinder = find.byKey(ValueKey('smart-${b.id}'));
      expect(rowFinder, findsOneWidget);
      final rowWidget = tester.widget<NodeRow>(rowFinder);
      expect(rowWidget.enableSwipeGestures, isFalse);

      // 尝试水平拖动手势 (向右滑动 100 像素)
      await tester.drag(rowFinder, const Offset(100, 0));
      await tester.pump();

      // 验证 Transform.translate 偏移量始终为 Offset.zero，绝不触发位移预览
      final transformFinder = find.descendant(
        of: rowFinder,
        matching: find.byType(Transform),
      );
      final transform = tester.widget<Transform>(transformFinder.first);
      expect(transform.transform.getTranslation().x, 0.0);
    });

    testWidgets('DatePicker 选择日期或取消后恢复 TextField 焦点', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final node = await commands.createNode(
        parentId: null,
        content: 'Custom Date Task',
      );
      await commands.updateDueDate(node.id, today);

      await pumpApp(tester);

      // 进入今天页
      await tester.tap(find.byKey(const ValueKey('smart-entry-today')));
      await tester.pumpAndSettle();

      // 点击进入编辑
      await tester.tap(find.text('Custom Date Task'));
      await tester.pumpAndSettle();

      // 打开菜单选择“选择日期…”
      await tester.tap(find.byTooltip('截止日期'));
      await tester.pumpAndSettle();

      final customItemFinder = find.byWidgetPredicate(
        (w) => w is PopupMenuItem<String> && w.value == 'custom',
      );
      await tester.tap(customItemFinder);
      await tester.pumpAndSettle();

      // DatePicker 弹出，点击 Cancel 取消
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 验证焦点恢复到 TextField
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('在智能列表中点击完成，节点立即离开列表并主动清理会话', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final node = await commands.createNode(
        parentId: null,
        content: 'Done Exit Task',
      );
      await commands.updateDueDate(node.id, today);

      await pumpApp(tester);

      // 进入今天页
      await tester.tap(find.byKey(const ValueKey('smart-entry-today')));
      await tester.pumpAndSettle();

      // 点击进入编辑
      await tester.tap(find.text('Done Exit Task'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyboardToolbar), findsOneWidget);

      // 点击工具栏“完成”按钮
      await tester.tap(find.byTooltip('完成'));
      await tester.pumpAndSettle();

      // 节点离开列表，页面为空
      expect(find.text('Done Exit Task'), findsNothing);
      expect(find.text('今天没有待处理的节点'), findsOneWidget);

      // 键盘与工具栏完全清理
      expect(find.byType(KeyboardToolbar), findsNothing);
      expect(find.byType(TextField), findsNothing);

      final updated = await repository.getNode(node.id);
      expect(updated!.isDone, isTrue);
    });

    testWidgets('SmartNodePage 错误提示: 当底层操作失败时通过 SnackBar 提示错误', (tester) async {
      final node = await commands.createNode(
        parentId: null,
        content: 'Error Task',
      );
      await commands.toggleFavorite(node.id);

      await pumpApp(tester);

      // 进入收藏页
      await tester.tap(find.byKey(const ValueKey('smart-entry-favorites')));
      await tester.pumpAndSettle();

      // 点击进入编辑
      await tester.tap(find.text('Error Task'));
      await tester.pumpAndSettle();

      // 模拟底层写入失败
      repository.throwOnWrite = true;

      // 尝试在工具栏切换收藏
      await tester.tap(find.byTooltip('取消收藏'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证出现 SnackBar 提示错误，消除静默 catch
      expect(find.byType(SnackBar), findsOneWidget);

      // 清理 SnackBar 避免残留定时器
      ScaffoldMessenger.of(
        tester.element(find.byType(SnackBar)),
      ).clearSnackBars();
      await tester.pump();
    });
  });
}
