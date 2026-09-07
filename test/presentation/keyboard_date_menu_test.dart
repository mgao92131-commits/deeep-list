import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deep_list/features/nodes/presentation/widgets/keyboard_date_menu.dart';

void main() {
  for (final size in [const Size(400, 800), const Size(800, 400)]) {
    testWidgets('date menu avoids keyboard and scrolls on $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.reset);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: KeyboardDateMenu(
                tooltip: 'Dates',
                icon: const Icon(Icons.event),
                onOpened: () {},
                onCanceled: () {},
                onSelected: (value) => selected = value,
                itemBuilder: (_) => List.generate(
                  12,
                  (i) => PopupMenuItem<String>(
                    value: '$i',
                    child: Text('Date $i'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Dates'));
      await tester.pumpAndSettle();
      final menu = find.byKey(const ValueKey('keyboard-date-menu-surface'));
      var bounds = tester.getRect(menu);
      expect(bounds.top, greaterThanOrEqualTo(8));
      expect(bounds.bottom, lessThanOrEqualTo(size.height - 200));
      // Insets may change while a popup is already visible.
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      bounds = tester.getRect(menu);
      expect(bounds.bottom, lessThanOrEqualTo(size.height - 240));
      await tester.drag(
        find.descendant(of: menu, matching: find.byType(SingleChildScrollView)),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date 11'));
      await tester.pumpAndSettle();
      expect(selected, '11');
    });
  }
}
