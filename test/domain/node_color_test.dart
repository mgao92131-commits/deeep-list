import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/features/nodes/domain/node_color.dart';

void main() {
  group('NodeColor', () {
    test('contains exactly 1 none + 7 colors', () {
      expect(NodeColor.values, [
        NodeColor.none,
        NodeColor.gray,
        NodeColor.red,
        NodeColor.orange,
        NodeColor.yellow,
        NodeColor.green,
        NodeColor.blue,
        NodeColor.purple,
      ]);
    });

    test('has expected Chinese labels', () {
      expect(NodeColor.none.label, '默认');
      expect(NodeColor.gray.label, '灰');
      expect(NodeColor.red.label, '红');
      expect(NodeColor.orange.label, '橙');
      expect(NodeColor.yellow.label, '黄');
      expect(NodeColor.green.label, '绿');
      expect(NodeColor.blue.label, '蓝');
      expect(NodeColor.purple.label, '紫');
    });

    test('resolves to specified low-saturation light/dark colors', () {
      // Default: Light #F6F6F7, Dark #242629
      expect(NodeColor.none.resolve(Brightness.light), const Color(0xFFF6F6F7));
      expect(NodeColor.none.resolve(Brightness.dark), const Color(0xFF242629));

      // Gray: Light #F2F3F5, Dark #2A2D31
      expect(NodeColor.gray.resolve(Brightness.light), const Color(0xFFF2F3F5));
      expect(NodeColor.gray.resolve(Brightness.dark), const Color(0xFF2A2D31));

      // Red: Light #FDEBEC, Dark #3A2024
      expect(NodeColor.red.resolve(Brightness.light), const Color(0xFFFDEBEC));
      expect(NodeColor.red.resolve(Brightness.dark), const Color(0xFF3A2024));

      // Orange: Light #FFF0E1, Dark #3C2A1D
      expect(
        NodeColor.orange.resolve(Brightness.light),
        const Color(0xFFFFF0E1),
      );
      expect(
        NodeColor.orange.resolve(Brightness.dark),
        const Color(0xFF3C2A1D),
      );

      // Yellow: Light #FFF7D6, Dark #3A331A
      expect(
        NodeColor.yellow.resolve(Brightness.light),
        const Color(0xFFFFF7D6),
      );
      expect(
        NodeColor.yellow.resolve(Brightness.dark),
        const Color(0xFF3A331A),
      );

      // Green: Light #EAF6EC, Dark #1E3527
      expect(
        NodeColor.green.resolve(Brightness.light),
        const Color(0xFFEAF6EC),
      );
      expect(NodeColor.green.resolve(Brightness.dark), const Color(0xFF1E3527));

      // Blue: Light #EAF2FF, Dark #1F2E45
      expect(NodeColor.blue.resolve(Brightness.light), const Color(0xFFEAF2FF));
      expect(NodeColor.blue.resolve(Brightness.dark), const Color(0xFF1F2E45));

      // Purple: Light #F2ECFB, Dark #302642
      expect(
        NodeColor.purple.resolve(Brightness.light),
        const Color(0xFFF2ECFB),
      );
      expect(
        NodeColor.purple.resolve(Brightness.dark),
        const Color(0xFF302642),
      );
    });
  });
}
