import 'package:flutter/material.dart';

enum NodeColor {
  none,
  gray,
  red,
  orange,
  yellow,
  green,
  blue,
  purple;

  String get label {
    switch (this) {
      case NodeColor.none:
        return '默认';
      case NodeColor.gray:
        return '灰';
      case NodeColor.red:
        return '红';
      case NodeColor.orange:
        return '橙';
      case NodeColor.yellow:
        return '黄';
      case NodeColor.green:
        return '绿';
      case NodeColor.blue:
        return '蓝';
      case NodeColor.purple:
        return '紫';
    }
  }

  Color resolve(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (this) {
      case NodeColor.none:
        return isDark ? const Color(0xFF242629) : const Color(0xFFF6F6F7);
      case NodeColor.gray:
        return isDark ? const Color(0xFF2A2D31) : const Color(0xFFF2F3F5);
      case NodeColor.red:
        return isDark ? const Color(0xFF3A2024) : const Color(0xFFFDEBEC);
      case NodeColor.orange:
        return isDark ? const Color(0xFF3C2A1D) : const Color(0xFFFFF0E1);
      case NodeColor.yellow:
        return isDark ? const Color(0xFF3A331A) : const Color(0xFFFFF7D6);
      case NodeColor.green:
        return isDark ? const Color(0xFF1E3527) : const Color(0xFFEAF6EC);
      case NodeColor.blue:
        return isDark ? const Color(0xFF1F2E45) : const Color(0xFFEAF2FF);
      case NodeColor.purple:
        return isDark ? const Color(0xFF302642) : const Color(0xFFF2ECFB);
    }
  }
}
