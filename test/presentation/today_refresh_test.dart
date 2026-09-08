import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deep_list/app/app.dart';
import 'package:deep_list/app/providers.dart';
import 'package:deep_list/core/time/today_provider.dart';
import '../helpers/test_database.dart';

void main() {
  for (final resume in [false, true]) {
    testWidgets('日期变化自动更新数量和日期标签，恢复前台=$resume', (tester) async {
      final harness = TestDatabase();
      var now = DateTime(2026, 9, 8, 23, 59, 59);
      final node = await harness.commands.createNode(
        parentId: null,
        content: 'Tomorrow Task',
      );
      await harness.commands.updateDueDate(node.id, DateTime(2026, 9, 9));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localClockProvider.overrideWithValue(() => now),
            databaseProvider.overrideWithValue(harness.database),
            nodeRepositoryProvider.overrideWithValue(harness.repository),
            treeCommandServiceProvider.overrideWithValue(harness.commands),
          ],
          child: const DeepListApp(),
        ),
      );
      await tester.pumpAndSettle();
      final count = find.byKey(const ValueKey('smart-entry-today-count'));
      expect(tester.widget<Text>(count).data, '0');
      expect(find.text('明天'), findsOneWidget);
      if (resume) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }
      now = DateTime(2026, 9, 9, 0, 0, 1);
      if (resume) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      } else {
        await tester.pump(const Duration(seconds: 2));
      }
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(count).data, '1');
      expect(find.text('今天'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('smart-entry-today')));
      await tester.pumpAndSettle();
      expect(find.text('Tomorrow Task'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await harness.close();
    });
  }

  testWidgets('前台系统日期回拨会校准，销毁后取消时钟', (tester) async {
    var now = DateTime(2026, 9, 9, 12);
    final container = ProviderContainer(
      overrides: [localClockProvider.overrideWithValue(() => now)],
    );
    final subscription = container.listen(todayProvider, (_, _) {});
    expect(container.read(todayProvider), DateTime(2026, 9, 9));
    now = DateTime(2026, 9, 8, 12);
    await tester.pump(const Duration(minutes: 1));
    expect(container.read(todayProvider), DateTime(2026, 9, 8));
    subscription.close();
    container.dispose();
  });
}
