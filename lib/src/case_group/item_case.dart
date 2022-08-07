import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:stack_board/src/helper/case_style.dart';
import 'package:stack_board/src/helper/operat_state.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

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
  ItemCase({
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

  _ItemCaseState? state;

  void resizeCase(Offset scaleOffset) => state?._scaleHandle(
        scaleOffset / 2,
        cancelEditMode: false,
        keepAspectRatio: false,
      );
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
    widget.state = this;
  }

  @override
  void didUpdateWidget(covariant ItemCase oldWidget) {
    if (widget.operationState != null &&
        widget.operationState != oldWidget.operationState) {
      _operationState = widget.operationState!;
      safeSetState(() {});
      widget.onOperationStateChanged?.call(_operationState);
    }
    widget.state = this;

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
  void _moveHandle(DragUpdateDetails dragUpdateDetails) {
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
    Offset delta = dragUpdateDetails.delta;
    final Offset changeTo =
        _config.value.offset?.translate(delta.dx, delta.dy) ?? Offset.zero;

    //向量旋转
    delta = Offset(
        sina * delta.dy + cosa * delta.dx, cosa * delta.dy - sina * delta.dx);

    final Offset? realOffset =
        _config.value.offset?.translate(delta.dx, delta.dy);
    if (realOffset == null) return;

    //移动拦截
    if (!(widget.onOffsetChanged?.call(realOffset) ?? true)) return;

    _config.value = _config.value.copy(offset: realOffset);

    widget.onOffsetChanged?.call(changeTo);
  }

  /// 缩放操作
  void _scaleHandle(
    Offset scaleOffset, {
    bool cancelEditMode = true,
    bool keepAspectRatio = true,
  }) {
    if (cancelEditMode) {
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
    }

    if (_config.value.offset == null) return;
    if (_config.value.size == null) return;

    if (keepAspectRatio) {
      final double middle = (scaleOffset.dx + scaleOffset.dy) / 2;
      scaleOffset = Offset(middle, middle);
    }

    double newWidth = _config.value.size!.width + (scaleOffset.dx * 2);
    double newHeight = _config.value.size!.height + (scaleOffset.dy * 2);

    double newOffsetX = _config.value.offset!.dx;
    double newOffsetY = _config.value.offset!.dy;

    final double min = _caseStyle.iconSize * 2;
    final double max = MediaQuery.of(context).size.longestSide;

    if (newWidth <= min ||
        newHeight <= min ||
        newWidth >= max ||
        newHeight >= max) {
      newWidth = _config.value.size!.width;
      newHeight = _config.value.size!.height;
    } else {
      newOffsetX -= scaleOffset.dx;
      newOffsetY -= scaleOffset.dy;
    }

    _config.value.size = Size(newWidth, newHeight);

    //缩放拦截
    if (!(widget.onSizeChanged?.call(_config.value.size!) ?? true)) return;

    _config.value.offset = Offset(newOffsetX, newOffsetY);

    // //移动拦截
    if (!(widget.onOffsetChanged?.call(_config.value.offset!) ?? true)) return;

    _config.value = _config.value.copy();
  }

  /// 旋转操作
  void _rotateHandle(DragUpdateDetails dragUpdateDetails) {
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
    final Offset pointer = dragUpdateDetails.globalPosition
        .translate(0, -_caseStyle.iconSize * 2.5);
    final Size size = _config.value.size!;
    final Offset center =
        Offset(start.dx + size.width / 2, start.dy + size.height / 2);
    final Offset directionToPointer = pointer - center;
    final Offset directionToHandle = start - center;

    final double angle =
        math.atan2(directionToPointer.dy, directionToPointer.dx) -
            math.atan2(directionToHandle.dy, directionToHandle.dx);

    //旋转拦截
    if (!(widget.onAngleChanged?.call(angle) ?? true)) return;

    final double roundedAngle = (angle / (math.pi / 4)).round() * (math.pi / 4);
    final bool isNearToSnap = (angle - roundedAngle).abs() < 0.1;

    _config.value =
        _config.value.copy(angle: isNearToSnap ? roundedAngle : angle);
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
      shouldRebuild: (_Config? previousConfig, _Config? newConfig) =>
          previousConfig?.offset != newConfig?.offset ||
          previousConfig?.angle != newConfig?.angle ||
          previousConfig?.size != newConfig?.size,
      valueListenable: _config,
      builder: (_, _Config? config, Widget? child) {
        return Positioned(
          top: config?.offset?.dy,
          left: config?.offset?.dx,
          width: config?.size?.width,
          height: config?.size?.height,
          child: Transform.rotate(
            angle: config?.angle ?? 0,
            child: child,
          ),
        );
      },
      child: MouseRegion(
        cursor: _cursor,
        child: Listener(
          onPointerDown: (_) => _onPointerDown(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _moveHandle,
            onPanEnd: (_) => _changeToIdle(),
            child: Stack(
              fit: StackFit.passthrough,
              children: <Widget>[
                _border,
                _child,
                if (widget.tools != null) _tools,
                if (widget.isEditable &&
                    _operationState != OperationState.complete)
                  _edit,
                if (_operationState != OperationState.complete) _rotate,
                if (widget.onDelete != null &&
                    _operationState != OperationState.complete)
                  _delete,
                if (_operationState != OperationState.complete) _scale,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 子控件
  Widget get _child {
    Widget content = widget.child;
    if (_config.value.size == null) {
      content = GetSize(
        onChange: (Size? size) {
          if (size != null && _config.value.size == null) {
            _config.value.size = Size(size.width + _caseStyle.iconSize,
                size.height + _caseStyle.iconSize);
            safeSetState(() {});
          }
        },
        child: content,
      );
    }

    if (widget.isCentered) content = Center(child: content);

    return Padding(
      padding: EdgeInsets.all(_caseStyle.iconSize / 2),
      child: content,
    );
  }

  /// 边框
  Widget get _border {
    return Padding(
      padding: EdgeInsets.all(_caseStyle.iconSize / 2),
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
    return Positioned(
      bottom: 0,
      left: 0,
      child: MouseRegion(
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
          onPanUpdate: (DragUpdateDetails dragUpdateDetails) =>
              _scaleHandle(dragUpdateDetails.delta),
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
      left: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onPanUpdate: _rotateHandle,
          onPanEnd: (_) => _changeToIdle(),
          onDoubleTap: _turnBack,
          child: _toolCase(
            const Icon(Icons.refresh),
          ),
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
