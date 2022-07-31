import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:stack_board/src/helper/case_style.dart';
import 'package:stack_board/src/helper/operat_state.dart';

/// 配置项
class _Config {
  _Config({this.size, this.offset, this.angle});

  /// 默认配置
  _Config.def({this.offset = Offset.zero, this.angle = 0});

  /// 尺寸
  Size? size;

  /// 位置
  Offset? offset;

  /// 角度
  double? angle;

  /// 拷贝
  _Config copy({
    Size? size,
    Offset? offset,
    double? angle,
  }) =>
      _Config(
        size: size ?? this.size,
        offset: offset ?? this.offset,
        angle: angle ?? this.angle,
      );
}

/// 操作外壳
class ItemCase extends StatefulWidget {
  const ItemCase({
    Key? key,
    required this.child,
    this.isCentered = true,
    this.tools,
    this.caseStyle = const CaseStyle(),
    this.tapToEdit = false,
    this.operationState = OperationState.idle,
    this.isEditable = false,
    this.onDelete,
    this.onSizeChanged,
    this.onOperationStateChanged,
    this.onOffsetChanged,
    this.onAngleChanged,
    this.onPointerDown,
  }) : super(key: key);

  @override
  _ItemCaseState createState() => _ItemCaseState();

  /// 子控件
  final Widget child;

  /// 工具层
  final Widget? tools;

  /// 是否进行居中对齐(自动包裹Center)
  final bool isCentered;

  /// 能否编辑
  final bool isEditable;

  /// 外框样式
  final CaseStyle? caseStyle;

  /// 点击进行编辑，默认false
  final bool tapToEdit;

  /// 操作状态
  final OperationState? operationState;

  /// 移除拦截
  final void Function()? onDelete;

  /// 点击回调
  final void Function()? onPointerDown;

  /// 尺寸变化回调
  /// 返回值可控制是否继续进行
  final bool? Function(Size size)? onSizeChanged;

  ///位置变化回调
  final bool? Function(Offset offset)? onOffsetChanged;

  /// 角度变化回调
  final bool? Function(double offset)? onAngleChanged;

  /// 操作状态回调
  final bool? Function(OperationState)? onOperationStateChanged;
}

class _ItemCaseState extends State<ItemCase> with SafeState<ItemCase> {
  /// 基础参数状态
  late SafeValueNotifier<_Config> _config;

  /// 操作状态
  late OperationState _operationState;

  /// 外框样式
  CaseStyle get _caseStyle => widget.caseStyle ?? const CaseStyle();

  @override
  void initState() {
    super.initState();
    _operationState = widget.operationState ?? OperationState.idle;
    _config = SafeValueNotifier<_Config>(_Config.def());
    _config.value.offset = widget.caseStyle?.initOffset;
  }

  @override
  void didUpdateWidget(covariant ItemCase oldWidget) {
    if (widget.operationState != null &&
        widget.operationState != oldWidget.operationState) {
      _operationState = widget.operationState!;
      safeSetState(() {});
      widget.onOperationStateChanged?.call(_operationState);
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _config.dispose();
    super.dispose();
  }

  /// 点击
  void _onPointerDown() {
    if (widget.tapToEdit) {
      if (_operationState != OperationState.editing) {
        _operationState = OperationState.editing;
        safeSetState(() {});
      }
    } else if (_operationState == OperationState.complete) {
      safeSetState(() => _operationState = OperationState.idle);
    }

    widget.onPointerDown?.call();
    widget.onOperationStateChanged?.call(_operationState);
  }

  /// 切回常规状态
  void _changeToIdle() {
    if (_operationState != OperationState.idle) {
      _operationState = OperationState.idle;
      widget.onOperationStateChanged?.call(_operationState);

      safeSetState(() {});
    }
  }

  /// 移动操作
  void _moveHandle(DragUpdateDetails dud) {
    if (_operationState != OperationState.moving) {
      if (_operationState == OperationState.scaling ||
          _operationState == OperationState.rotating) {
        _operationState = OperationState.moving;
      } else {
        _operationState = OperationState.moving;
        safeSetState(() {});
      }

      widget.onOperationStateChanged?.call(_operationState);
    }

    final double angle = _config.value.angle ?? 0;
    final double sina = math.sin(-angle);
    final double cosa = math.cos(-angle);
    Offset d = dud.delta;
    final Offset changeTo =
        _config.value.offset?.translate(d.dx, d.dy) ?? Offset.zero;

    //向量旋转
    d = Offset(sina * d.dy + cosa * d.dx, cosa * d.dy - sina * d.dx);

    final Offset? realOffset = _config.value.offset?.translate(d.dx, d.dy);
    if (realOffset == null) return;

    //移动拦截
    if (!(widget.onOffsetChanged?.call(realOffset) ?? true)) return;

    _config.value = _config.value.copy(offset: realOffset);

    widget.onOffsetChanged?.call(changeTo);
  }

  /// 缩放操作
  void _scaleHandle(DragUpdateDetails dud) {
    if (_operationState != OperationState.scaling) {
      if (_operationState == OperationState.moving ||
          _operationState == OperationState.rotating) {
        _operationState = OperationState.scaling;
      } else {
        _operationState = OperationState.scaling;
        safeSetState(() {});
      }

      widget.onOperationStateChanged?.call(_operationState);
    }

    if (_config.value.offset == null) return;
    if (_config.value.size == null) return;

    final double angle = _config.value.angle ?? 0;
    final double fsina = math.sin(-angle);
    final double fcosa = math.cos(-angle);
    // final double sina = math.sin(angle);
    // final double cosa = math.cos(angle);

    // final Offset d = dud.delta;
    final Offset d = dud.globalPosition;
    // d = Offset(fsina * d.dy + fcosa * d.dx, fcosa * d.dy - fsina * d.dx);

    // print('delta:$d');

    // final Size size = _config.value.size!;
    // double w = size.width + d.dx;
    // double h = size.height + d.dy;

    final double min = _caseStyle.iconSize * 3;

    Offset start = _config.value.offset! +
        Offset(-_caseStyle.iconSize / 2, _caseStyle.iconSize * 2);
    start = Offset(fsina * start.dy + fcosa * start.dx,
        fcosa * start.dy - fsina * start.dx);

    double w = d.dx - start.dx;
    double h = d.dy - start.dy;

    //达到极小值
    if (w < min) w = min;
    if (h < min) h = min;

    Size s = Size(w, h);

    if (d.dx < 0 && s.width < min) s = Size(min, h);
    if (d.dy < 0 && s.height < min) s = Size(w, min);

    //缩放拦截
    if (!(widget.onSizeChanged?.call(s) ?? true)) return;

    if (widget.caseStyle?.boxAspectRatio != null) {
      if (s.width < s.height) {
        _config.value.size =
            Size(s.width, s.width / widget.caseStyle!.boxAspectRatio!);
      } else {
        _config.value.size =
            Size(s.height * widget.caseStyle!.boxAspectRatio!, s.height);
      }
    } else {
      _config.value.size = s;
    }

    _config.value = _config.value.copy();
  }

  /// 旋转操作
  void _rotateHandle(DragUpdateDetails dud) {
    if (_operationState != OperationState.rotating) {
      if (_operationState == OperationState.moving ||
          _operationState == OperationState.scaling) {
        _operationState = OperationState.rotating;
      } else {
        _operationState = OperationState.rotating;
        safeSetState(() {});
      }

      widget.onOperationStateChanged?.call(_operationState);
    }

    if (_config.value.size == null) return;
    if (_config.value.offset == null) return;

    final Offset start = _config.value.offset!;
    final Offset global = dud.globalPosition.translate(
      _caseStyle.iconSize / 2,
      -_caseStyle.iconSize * 2.5,
    );
    final Size size = _config.value.size!;
    final Offset center =
        Offset(start.dx + size.width / 2, start.dy + size.height / 2);
    final double l = (global - center).distance;
    final double s = (global.dy - center.dy).abs();

    double angle = math.asin(s / l);

    if (global.dx < center.dx) {
      if (global.dy < center.dy) {
        angle = math.pi + angle;
        // print('第四象限');
      } else {
        angle = math.pi - angle;
        // print('第三象限');
      }
    } else {
      if (global.dy < center.dy) {
        angle = 2 * math.pi - angle;
        // print('第一象限');
      }
    }

    //旋转拦截
    if (!(widget.onAngleChanged?.call(angle) ?? true)) return;

    _config.value = _config.value.copy(angle: angle);
  }

  /// 旋转回0度
  void _turnBack() {
    if (_config.value.angle != 0) {
      _config.value = _config.value.copy(angle: 0);
    }
  }

  /// 主体鼠标指针样式
  MouseCursor get _cursor {
    if (_operationState == OperationState.moving) {
      return SystemMouseCursors.grabbing;
    } else if (_operationState == OperationState.editing) {
      return SystemMouseCursors.click;
    }

    return SystemMouseCursors.grab;
  }

  @override
  Widget build(BuildContext context) {
    return ExValueBuilder<_Config>(
      shouldRebuild: (_Config? p, _Config? n) =>
          p?.offset != n?.offset || p?.angle != n?.angle,
      valueListenable: _config,
      child: MouseRegion(
        cursor: _cursor,
        child: Listener(
          onPointerDown: (_) => _onPointerDown(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _moveHandle,
            onPanEnd: (_) => _changeToIdle(),
            child: Stack(children: <Widget>[
              _border,
              _child,
              if (widget.tools != null) _tools,
              if (widget.isEditable &&
                  _operationState != OperationState.complete)
                _edit,
              if (_operationState != OperationState.complete) _rotate,
              if (_operationState != OperationState.complete) _done,
              if (widget.onDelete != null &&
                  _operationState != OperationState.complete)
                _delete,
              if (_operationState != OperationState.complete) _scale,
            ]),
          ),
        ),
      ),
      builder: (_, _Config? c, Widget? child) {
        return Positioned(
          top: c?.offset?.dy ?? 0,
          left: c?.offset?.dx ?? 0,
          child: Transform.rotate(
            angle: c?.angle ?? 0,
            child: child,
          ),
        );
      },
    );
  }

  /// 子控件
  Widget get _child {
    Widget content = widget.child;
    if (_config.value.size == null) {
      content = GetSize(
        onChange: (Size? size) {
          if (size != null && _config.value.size == null) {
            _config.value.size = Size(size.width + _caseStyle.iconSize + 40,
                size.height + _caseStyle.iconSize + 40);
            safeSetState(() {});
          }
        },
        child: content,
      );
    }

    if (widget.isCentered) content = Center(child: content);

    return ExValueBuilder<_Config>(
      shouldRebuild: (_Config? p, _Config? n) => p?.size != n?.size,
      valueListenable: _config,
      child: Padding(
        padding: EdgeInsets.all(_caseStyle.iconSize / 2),
        child: content,
      ),
      builder: (_, _Config? c, Widget? child) {
        return SizedBox.fromSize(
          size: c?.size,
          child: child,
        );
      },
    );
  }

  /// 边框
  Widget get _border {
    return Positioned(
      top: _caseStyle.iconSize / 2,
      bottom: _caseStyle.iconSize / 2,
      left: _caseStyle.iconSize / 2,
      right: _caseStyle.iconSize / 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _operationState == OperationState.complete
                ? Colors.transparent
                : _caseStyle.borderColor,
            width: _caseStyle.borderWidth,
          ),
        ),
      ),
    );
  }

  /// 编辑手柄
  Widget get _edit {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (_operationState == OperationState.editing) {
            _operationState = OperationState.idle;
          } else {
            _operationState = OperationState.editing;
          }
          safeSetState(() {});
          widget.onOperationStateChanged?.call(_operationState);
        },
        child: _toolCase(
          Icon(_operationState == OperationState.editing
              ? Icons.border_color
              : Icons.edit),
        ),
      ),
    );
  }

  /// 删除手柄
  Widget get _delete {
    return Positioned(
      top: 0,
      right: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => widget.onDelete?.call(),
          child: _toolCase(const Icon(Icons.clear)),
        ),
      ),
    );
  }

  /// 缩放手柄
  Widget get _scale {
    return Positioned(
      bottom: 0,
      right: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        child: GestureDetector(
          onPanUpdate: _scaleHandle,
          onPanEnd: (_) => _changeToIdle(),
          child: _toolCase(
            const RotatedBox(
              quarterTurns: 1,
              child: Icon(Icons.open_in_full_outlined),
            ),
          ),
        ),
      ),
    );
  }

  /// 旋转手柄
  Widget get _rotate {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onPanUpdate: _rotateHandle,
          onPanEnd: (_) => _changeToIdle(),
          onDoubleTap: _turnBack,
          child: _toolCase(
            const RotatedBox(
              quarterTurns: 1,
              child: Icon(Icons.refresh),
            ),
          ),
        ),
      ),
    );
  }

  /// 完成操作
  Widget get _done {
    return Positioned(
      bottom: 0,
      left: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (_operationState != OperationState.complete) {
              _operationState = OperationState.complete;
              safeSetState(() {});
              widget.onOperationStateChanged?.call(_operationState);
            }
          },
          child: _toolCase(const Icon(Icons.check)),
        ),
      ),
    );
  }

  /// 操作手柄壳
  Widget _toolCase(Widget child) {
    return Container(
      width: _caseStyle.iconSize,
      height: _caseStyle.iconSize,
      child: IconTheme(
        data: Theme.of(context).iconTheme.copyWith(
              color: _caseStyle.iconColor,
              size: _caseStyle.iconSize * 0.6,
            ),
        child: child,
      ),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _caseStyle.borderColor,
      ),
    );
  }

  /// 工具栏
  Widget get _tools {
    return Positioned(
      left: _caseStyle.iconSize / 2,
      top: _caseStyle.iconSize / 2,
      right: _caseStyle.iconSize / 2,
      bottom: _caseStyle.iconSize / 2,
      child: widget.tools!,
    );
  }
}
