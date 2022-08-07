library stack_board;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:stack_board/src/helper/operat_state.dart';

import 'case_group/adaptive_text_case.dart';
import 'case_group/drawing_board_case.dart';
import 'case_group/item_case.dart';
import 'helper/case_style.dart';
import 'item_group/adaptive_text.dart';
import 'item_group/stack_board_item.dart';
import 'item_group/stack_drawing.dart';

/// 层叠板
class StackBoard extends StatefulWidget {
  const StackBoard({
    Key? key,
    this.controller,
    this.background,
    this.caseStyle = const CaseStyle(),
    this.customBuilder,
    this.tapItemToMoveToTop = true,
  }) : super(key: key);

  @override
  _StackBoardState createState() => _StackBoardState();

  /// 层叠版控制器
  final StackBoardController? controller;

  /// 背景
  final Widget? background;

  /// 操作框样式
  final CaseStyle? caseStyle;

  /// 自定义类型控件构建器
  final Widget? Function(StackBoardItem item)? customBuilder;

  /// 点击item移至顶层
  final bool tapItemToMoveToTop;
}

class _StackBoardState extends State<StackBoard> with SafeState<StackBoard> {
  /// 子控件列表
  late List<StackBoardItem> _children;

  int? _focusedItemId;

  /// 当前item所用id
  int _lastId = 0;

  /// 所有item的操作状态
  OperationState? _operationState;

  /// 生成唯一Key
  Key _getKey(int? id) => Key('StackBoardItem$id');

  @override
  void initState() {
    super.initState();
    _children = <StackBoardItem>[];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller?._stackBoardState = this;
  }

  /// 添加一个
  void _add<T extends StackBoardItem>(StackBoardItem item) {
    if (_children.contains(item)) throw 'duplicate id';

    _children.add(item.copyWith(
      id: item.id ?? _lastId,
      caseStyle: item.caseStyle ?? widget.caseStyle,
    ));

    _lastId++;

    _unFocus(_children.last.id);
  }

  /// 移除指定id item
  void _remove(int? id) {
    _children.removeWhere((StackBoardItem b) => b.id == id);
    safeSetState(() {});
  }

  /// 将item移至顶层
  void _moveItemToTop(int? id) {
    if (id == null) return;

    final StackBoardItem item =
        _children.firstWhere((StackBoardItem i) => i.id == id);
    _children.removeWhere((StackBoardItem i) => i.id == id);
    _children.add(item);

    _unFocus(id);

    safeSetState(() {});
  }

  /// 清理
  void _clear() {
    _children.clear();
    _lastId = 0;
    safeSetState(() {});
  }

  /// 取消全部选中
  void _unFocus(int? id) {
    if (_focusedItemId == null) {
      _focusedItemId = id;
      _operationState = OperationState.complete;
      safeSetState(() {});
    }
  }

  /// 删除动作
  Future<void> _onDelete(StackBoardItem box) async {
    final bool delete = (await box.onDelete?.call()) ?? true;
    if (delete) _remove(box.id);
  }

  @override
  Widget build(BuildContext context) {
    final Stack child = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (widget.background != null) widget.background!,
        ..._children.map((StackBoardItem box) => _buildItem(box)).toList(),
      ],
    );

    _focusedItemId = null;

    return child;
  }

  /// 构建项
  Widget _buildItem(StackBoardItem item) {
    Widget child = ItemCase(
      key: _getKey(item.id),
      child: Container(
        width: 150,
        height: 150,
        alignment: Alignment.center,
        child: const Text(
            'Unknown item type, please use customBuilder to build it'),
      ),
      onDelete: () => _onDelete(item),
      onPointerDown: () => _moveItemToTop(item.id),
      caseStyle: item.caseStyle,
      operationState:
          _focusedItemId == item.id ? OperationState.idle : _operationState,
    );

    if (item is AdaptiveText) {
      child = AdaptiveTextCase(
        key: _getKey(item.id),
        adaptiveText: item,
        onDelete: () => _onDelete(item),
        onPointerDown: () => _moveItemToTop(item.id),
        operationState:
            _focusedItemId == item.id ? OperationState.idle : _operationState,
      );
    } else if (item is StackDrawing) {
      child = DrawingBoardCase(
        key: _getKey(item.id),
        stackDrawing: item,
        onDelete: () => _onDelete(item),
        onPointerDown: () => _moveItemToTop(item.id),
        operationState:
            _focusedItemId == item.id ? OperationState.idle : _operationState,
      );
    } else {
      child = ItemCase(
        key: _getKey(item.id),
        child: item.child,
        onDelete: () => _onDelete(item),
        onPointerDown: () => _moveItemToTop(item.id),
        caseStyle: item.caseStyle,
        operationState:
            _focusedItemId == item.id ? OperationState.idle : _operationState,
      );

      if (widget.customBuilder != null) {
        final Widget? customWidget = widget.customBuilder!.call(item);
        if (customWidget != null) return child = customWidget;
      }
    }

    return child;
  }
}

/// 控制器
class StackBoardController {
  _StackBoardState? _stackBoardState;

  /// 检查是否加载
  void _done() {
    if (_stackBoardState == null) throw '_stackBoardState is empty';
  }

  /// 添加一个
  void add<T extends StackBoardItem>(T item) {
    _done();
    _stackBoardState?._add<T>(item);
  }

  /// 移除
  void remove(int? id) {
    _done();
    _stackBoardState?._remove(id);
  }

  void moveItemToTop(int? id) {
    _done();
    _stackBoardState?._moveItemToTop(id);
  }

  /// 清理全部
  void clear() {
    _done();
    _stackBoardState?._clear();
  }

  /// 刷新
  void refresh() {
    _done();
    _stackBoardState?.safeSetState(() {});
  }

  /// 销毁
  void dispose() {
    _stackBoardState = null;
  }

  void unFocus([int? id]) {
    _stackBoardState?._unFocus(id);
  }
}
