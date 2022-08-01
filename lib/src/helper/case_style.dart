import 'package:flutter/material.dart';

/// 操作壳样式
class CaseStyle {
  const CaseStyle({
    this.borderColor = Colors.white,
    this.borderWidth = 1,
    this.iconColor,
    this.iconSize = 24,
    this.initOffset = Offset.zero,
  });

  /// 边框(包括操作手柄)颜色
  final Color borderColor;

  /// 边框粗细
  final double borderWidth;

  /// 图标颜色
  final Color? iconColor;

  /// 图标大小
  final double iconSize;

  /// 外框初始位置
  final Offset initOffset;
}
