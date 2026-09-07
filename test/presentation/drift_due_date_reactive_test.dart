import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/app/app.dart';
import 'package:deep_list/app/providers.dart';
import 'package:deep_list/features/nodes/presentation/widgets/keyboard_toolbar.dart';
import 'package:deep_list/features/nodes/presentation/widgets/node_row.dart';

import '../helpers/test_database.dart';

void main() {
  group('真实 Drift 截止日期响应式与实时更新测试', () {
    late TestDatabase harness;

    setUp(() {
      harness = TestDatabase();
    });

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(harness.database),
            nodeRepositoryProvider.overrideWithValue(harness.repository),
            treeCommandServiceProvider.overrideWithValue(harness.commands),
          ],
          child: const DeepListApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tearDownApp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await harness.close();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('普通列表 NodeRow 在真实 Drift 下截止日期的显示、修改和移除', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final node = await harness.commands.createNode(
        parentId: null,
        content: 'Task With Due Date',
      );

      await pumpApp(tester);

      // 验证初始没有截止日期 UI
      expect(find.text('Task With Due Date'), findsOneWidget);
      expect(find.text('今天'), findsNothing);
      expect(find.text('明天'), findsNothing);

      // 1. 设置 dueDate = today
      await harness.commands.updateDueDate(node.id, today);
      await tester.pumpAndSettle();

      // NodeRow 必须自动出现“今天”
      expect(find.text('今天'), findsOneWidget);

      // 2. 设置 dueDate = tomorrow
      await harness.commands.updateDueDate(node.id, tomorrow);
      await tester.pumpAndSettle();

      // 自动显示“明天”
      expect(find.text('今天'), findsNothing);
      expect(find.text('明天'), findsOneWidget);

      // 3. 移除截止日期
      await harness.commands.updateDueDate(node.id, null);
      await tester.pumpAndSettle();

      // 日期 UI 自动消失
      expect(find.text('今天'), findsNothing);
      expect(find.text('明天'), findsNothing);

      // 4. 通过 KeyboardToolbar 选择“今天”
      await tester.tap(find.text('Task With Due Date'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyboardToolbar), findsOneWidget);
      final toolbarDueDateBtn = find.descendant(
        of: find.byType(KeyboardToolbar),
        matching: find.byTooltip('截止日期'),
      );
      await tester.tap(toolbarDueDateBtn);
      await tester.pumpAndSettle();

      final todayItemFinder = find.byWidgetPredicate(
        (w) => w is PopupMenuItem<String> && w.value == 'today',
      );
      await tester.tap(todayItemFinder);
      await tester.pumpAndSettle();

      // 验证 NodeRow 出现“今天”
      expect(find.text('今天'), findsWidgets);

      await tearDownApp(tester);
    });

    for (final action in ['today', 'custom-save', 'custom-cancel', 'cancel']) {
      testWidgets('日期交互遇到键盘隐藏仍保留编辑会话: $action', (tester) async {
        addTearDown(tester.view.resetViewInsets);
        final node = await harness.commands.createNode(
          parentId: null,
          content: 'Keyboard Date Task',
        );
        await pumpApp(tester);
        await tester.tap(find.text('Keyboard Date Task'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(KeyboardToolbar),
            matching: find.byTooltip('截止日期'),
          ),
        );
        await tester.pumpAndSettle();
        // Quick menu must not take focus from the editor.
        final menuBounds = tester.getRect(
          find.byKey(const ValueKey('keyboard-date-menu-surface')),
        );
        final toolbarBounds = tester.getRect(find.byType(KeyboardToolbar));
        expect(menuBounds.bottom, lessThanOrEqualTo(toolbarBounds.top));
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue,
        );
        if (action.startsWith('custom')) {
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is PopupMenuItem<String> && w.value == 'custom',
            ),
          );
          await tester.pumpAndSettle();
        }
        // A real IME reports zero insets when the date picker takes focus.
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(
          find.byType(KeyboardToolbar, skipOffstage: false),
          findsOneWidget,
        );
        if (action.startsWith('custom')) {
          await tester.tap(
            find.text(action == 'custom-save' ? 'OK' : 'Cancel'),
          );
        } else if (action == 'cancel') {
          await tester.tapAt(const Offset(5, 5));
        } else {
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is PopupMenuItem<String> && w.value == 'today',
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue,
        );
        final saved = action == 'today' || action == 'custom-save';
        final updated = await harness.repository.getNode(node.id);
        expect(updated!.dueDate, saved ? isNotNull : isNull);
        expect(find.text('今天'), saved ? findsOneWidget : findsNothing);
        if (saved) {
          await tester.tap(find.byKey(const ValueKey('smart-entry-due-dates')));
          await tester.pumpAndSettle();
          expect(find.text('Keyboard Date Task'), findsOneWidget);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('smart-entry-today')));
          await tester.pumpAndSettle();
          expect(find.text('Keyboard Date Task'), findsOneWidget);
        }
        await tearDownApp(tester);
      });
    }

    testWidgets('Due Dates 智能列表在页面打开状态下的实时进入、跨组移动与自动消失', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final nextWeek = today.add(const Duration(days: 7));

      final node = await harness.commands.createNode(
        parentId: null,
        content: 'Reactive Smart Node',
      );

      await pumpApp(tester);

      // 进入 Due Dates 智能列表
      await tester.tap(find.byKey(const ValueKey('smart-entry-due-dates')));
      await tester.pumpAndSettle();

      // 初始为空
      expect(find.text('Reactive Smart Node'), findsNothing);
      expect(find.text('还没有设置截止日期'), findsOneWidget);

      // 1. 在不离开页面的情况下，设置 dueDate = today
      await harness.commands.updateDueDate(node.id, today);
      await tester.pumpAndSettle();

      // 页面自动出现该 Node，并位于“今天”分组下
      expect(find.text('Reactive Smart Node'), findsOneWidget);
      expect(find.text('今天'), findsWidgets);

      // 2. 修改为 tomorrow
      await harness.commands.updateDueDate(node.id, tomorrow);
      await tester.pumpAndSettle();

      // 自动从“今天”移动到“明天”分组
      expect(find.text('Reactive Smart Node'), findsOneWidget);
      expect(find.text('明天'), findsWidgets);

      // 3. 修改为 nextWeek
      await harness.commands.updateDueDate(node.id, nextWeek);
      await tester.pumpAndSettle();

      // 自动移动到“以后”分组
      expect(find.text('Reactive Smart Node'), findsOneWidget);
      expect(find.text('以后'), findsOneWidget);

      // 4. 修改为 null
      await harness.commands.updateDueDate(node.id, null);
      await tester.pumpAndSettle();

      // 从 Due Dates 页面自动消失，回到空状态
      expect(find.text('Reactive Smart Node'), findsNothing);
      expect(find.text('还没有设置截止日期'), findsOneWidget);

      await tearDownApp(tester);
    });

    testWidgets('Today 智能列表在页面打开状态下的实时进入与离开', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final yesterday = today.subtract(const Duration(days: 1));

      final node = await harness.commands.createNode(
        parentId: null,
        content: 'Today Dynamic Task',
      );

      await pumpApp(tester);

      // 进入 Today 页面
      await tester.tap(find.byKey(const ValueKey('smart-entry-today')));
      await tester.pumpAndSettle();

      expect(find.text('Today Dynamic Task'), findsNothing);
      expect(find.text('今天没有待处理的节点'), findsOneWidget);

      // 1. 设置 dueDate = today
      await harness.commands.updateDueDate(node.id, today);
      await tester.pumpAndSettle();

      // Node 自动进入 Today
      expect(find.text('Today Dynamic Task'), findsOneWidget);

      // 2. 修改 dueDate = tomorrow
      await harness.commands.updateDueDate(node.id, tomorrow);
      await tester.pumpAndSettle();

      // Node 从 Today 自动消失
      expect(find.text('Today Dynamic Task'), findsNothing);
      expect(find.text('今天没有待处理的节点'), findsOneWidget);

      // 返回主页并进入 Due Dates 页面，验证该节点仍然存在并位于“明天”分组
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('smart-entry-due-dates')));
      await tester.pumpAndSettle();

      expect(find.text('Today Dynamic Task'), findsOneWidget);
      expect(find.text('明天'), findsWidgets);

      // 返回主页再进入 Today 页面继续后续测试
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('smart-entry-today')));
      await tester.pumpAndSettle();

      // 3. 创建昨天截止节点并动态更新为今天
      final overdueNode = await harness.commands.createNode(
        parentId: null,
        content: 'Overdue Task',
      );
      await harness.commands.updateDueDate(overdueNode.id, yesterday);
      await tester.pumpAndSettle();

      // 出现在已逾期分组
      expect(find.text('Overdue Task'), findsOneWidget);
      expect(find.text('已逾期'), findsOneWidget);

      // 将其改为今天
      await harness.commands.updateDueDate(overdueNode.id, today);
      await tester.pumpAndSettle();

      // 仍在 Today 页面，但从“已逾期”移动到“今天”
      expect(find.text('Overdue Task'), findsOneWidget);
      expect(find.text('已逾期'), findsNothing);

      await tearDownApp(tester);
    });

    testWidgets('普通列表与智能列表显示同一个 dueDate (一致性测试)', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final node = await harness.commands.createNode(
        parentId: null,
        content: 'Consistent Task',
      );
      await harness.commands.updateDueDate(node.id, today);

      await pumpApp(tester);

      // 1. 普通树页面: NodeRow 显示“今天”
      expect(find.text('Consistent Task'), findsOneWidget);
      final normalRowDueDate = find.descendant(
        of: find.byType(NodeRow),
        matching: find.text('今天'),
      );
      expect(normalRowDueDate, findsOneWidget);

      // 2. 进入 Today 页面: NodeRow 显示“今天”
      await tester.tap(find.byKey(const ValueKey('smart-entry-today')));
      await tester.pumpAndSettle();

      expect(find.text('Consistent Task'), findsOneWidget);
      final todayRowDueDate = find.descendant(
        of: find.byType(NodeRow),
        matching: find.text('今天'),
      );
      expect(todayRowDueDate, findsOneWidget);

      // 返回主页
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // 3. 进入 Due Dates 页面: NodeRow 显示“今天”
      await tester.tap(find.byKey(const ValueKey('smart-entry-due-dates')));
      await tester.pumpAndSettle();

      expect(find.text('Consistent Task'), findsOneWidget);
      final dueDatesRowDueDate = find.descendant(
        of: find.byType(NodeRow),
        matching: find.text('今天'),
      );
      expect(dueDatesRowDueDate, findsOneWidget);

      await tearDownApp(tester);
    });
  });
}
