import 'package:flutter/widgets.dart';
import 'package:stack_board/src/helper/case_style.dart';

/// 自定义对象
@immutable
class StackBoardItem {
  const StackBoardItem({
    required this.child,
    this.id,
    this.onDelete,
    this.caseStyle,
    this.tapToEdit = false,
  });

  /// item id
  final int? id;

  /// 子控件
  final Widget child;

  /// 移除回调
  final Future<bool> Function()? onDelete;

  /// 外框样式
  final CaseStyle? caseStyle;

  /// 点击进行编辑
  final bool tapToEdit;

  /// 对象拷贝
  StackBoardItem copyWith({
    int? id,
    Widget? child,
    Future<bool> Function()? onDelete,
    CaseStyle? caseStyle,
    bool? tapToEdit,
  }) =>
      StackBoardItem(
        id: id ?? this.id,
        child: child ?? this.child,
        onDelete: onDelete ?? this.onDelete,
        caseStyle: caseStyle ?? this.caseStyle,
        tapToEdit: tapToEdit ?? this.tapToEdit,
      );

  /// 对象比较
  bool sameWith(StackBoardItem item) => item.id == id;

  @override
  bool operator ==(Object other) => other is StackBoardItem && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
