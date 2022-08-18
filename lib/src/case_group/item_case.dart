import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:stack_board/src/board.dart';
import 'package:stack_board/src/helper/case_style.dart';
import 'package:stack_board/src/helper/operat_state.dart';

/// 配置项
class _Config {
  _Config({
    this.size,
    this.offset = Offset.zero,
    this.angle = 0,
    this.flipMatrix,
  });

  /// 尺寸
  Size? size;

  /// 位置
  Offset offset;

  /// 角度
  double angle;

  Matrix4? flipMatrix;

  /// 拷贝
  _Config copy({
    Size? size,
    Offset? offset,
    double? angle,
    Matrix4? flipMatrix,
  }) =>
      _Config(
        size: size ?? this.size,
        offset: offset ?? this.offset,
        angle: angle ?? this.angle,
        flipMatrix: flipMatrix ?? this.flipMatrix,
      );
}

/// 操作外壳
class ItemCase extends StatefulWidget {
  const ItemCase({
    Key? key,
    this.controller,
    required this.child,
    this.isCentered = false,
    this.tools,
    this.caseStyle = const CaseStyle(),
    this.tapToEdit = false,
    this.operationState = OperationState.idle,
    this.isEditable = false,
    this.onDelete,
    this.onSizeChanged,
    this.onResizeDone,
    this.onOperationStateChanged,
    this.onOffsetChanged,
    this.onAngleChanged,
    this.onPointerDown,
    this.onFlipped,
  }) : super(key: key);

  @override
  _ItemCaseState createState() => _ItemCaseState();

  final ItemCaseController? controller;

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

  final bool? Function(Size size)? onResizeDone;

  ///位置变化回调
  final bool? Function(Offset offset)? onOffsetChanged;

  /// 角度变化回调
  final bool? Function(double offset)? onAngleChanged;

  final bool? Function(Matrix4 flipMatrix)? onFlipped;

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

  static const int moveSnappingTreshold = 15;
  late final Size originalSize;
  late final double minWidthAndHeight;
  late double maxWidthAndHeight;
  late Offset center;
  late Offset movingStartPosition;
  late Offset movingStartOffset;
  late Offset rotatingPointerOffset;
  late double rotatingStartAngle;
  late Size currentUnfittedSize;

  late StackBoardController? _boardController;

  @override
  void initState() {
    super.initState();
    _operationState = widget.operationState ?? OperationState.idle;
    _config = SafeValueNotifier<_Config>(_Config());
    minWidthAndHeight = _caseStyle.iconSize * 3;

    _config.value.offset = const Offset(double.maxFinite, double.maxFinite);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculateCenter();
      _config.value.offset = center;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maxWidthAndHeight = MediaQuery.of(context).size.longestSide;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculateCenter();
    });
    _boardController =
        context.findAncestorWidgetOfExactType<StackBoard>()?.controller;
    widget.controller?._itemCaseState = this;
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

  Offset _recalculateCenter() {
    final Offset ownerCenter = context
            .findAncestorRenderObjectOfType<RenderObject>()
            ?.paintBounds
            .center ??
        Offset.zero;
    final Offset selfCenter = context.size?.center(Offset.zero) ?? Offset.zero;
    center = ownerCenter - selfCenter;
    return center;
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

  void _movingStart(DragStartDetails dragStartDetails) {
    movingStartPosition = dragStartDetails.globalPosition;
    movingStartOffset = _config.value.offset;
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

    Offset newOffset = movingStartOffset +
        (dragUpdateDetails.globalPosition - movingStartPosition);

    if ((newOffset.dx - center.dx).abs() < moveSnappingTreshold) {
      newOffset = Offset(center.dx, newOffset.dy);
      _boardController?.toggleCenterGuides(newVerticalState: true);
    } else {
      _boardController?.toggleCenterGuides(newVerticalState: false);
    }
    if ((newOffset.dy - center.dy).abs() < moveSnappingTreshold) {
      newOffset = Offset(newOffset.dx, center.dy);
      _boardController?.toggleCenterGuides(newHorizontalState: true);
    } else {
      _boardController?.toggleCenterGuides(newHorizontalState: false);
    }

    //移动拦截
    if (!(widget.onOffsetChanged?.call(newOffset) ?? true)) return;

    _config.value = _config.value.copy(offset: newOffset);
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

    if (_config.value.size == null) return;

    currentUnfittedSize = Size(
      currentUnfittedSize.width + (scaleOffset.dx * 2),
      currentUnfittedSize.height + (scaleOffset.dy * 2),
    );

    Size fittedSize;

    if (keepAspectRatio) {
      fittedSize = applyBoxFit(
        BoxFit.contain,
        originalSize,
        currentUnfittedSize,
      ).destination;
    } else {
      fittedSize = currentUnfittedSize;
    }

    fittedSize = Size(
      fittedSize.width.clamp(minWidthAndHeight, maxWidthAndHeight),
      fittedSize.height.clamp(minWidthAndHeight, maxWidthAndHeight),
    );

    if (fittedSize.width > minWidthAndHeight &&
        fittedSize.height > minWidthAndHeight &&
        fittedSize.width < maxWidthAndHeight &&
        fittedSize.height < maxWidthAndHeight) {
      _config.value.offset = Offset(
        _config.value.offset.dx -
            ((fittedSize.width - _config.value.size!.width) / 2),
        _config.value.offset.dy -
            ((fittedSize.height - _config.value.size!.height) / 2),
      );

      // //移动拦截
      if (!(widget.onOffsetChanged?.call(_config.value.offset) ?? true)) return;

      _config.value.size = fittedSize;

      //缩放拦截
      if (!(widget.onSizeChanged?.call(_config.value.size!) ?? true)) return;

      _config.value = _config.value.copy();

      _recalculateCenter();
    }
  }

  void _scalingEnd(DragEndDetails dragEndDetails) {
    if (_config.value.size != null) {
      currentUnfittedSize = _config.value.size!;
    }
    _changeToIdle();
    if (!(widget.onResizeDone?.call(_config.value.size!) ?? true)) return;
  }

  void _rotationStart(DragStartDetails dragStartDetails) {
    rotatingPointerOffset = _config.value.offset;
    rotatingStartAngle = _config.value.angle;
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

    rotatingPointerOffset += dragUpdateDetails.delta;
    final Offset start = _config.value.offset;
    final Size size = _config.value.size!;
    final Offset center = size.center(start);
    final Offset directionToPointer = rotatingPointerOffset - center;
    final Offset directionToHandle = start - center;

    final double angle = rotatingStartAngle +
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

  void _flip({required bool vertical}) {
    final Matrix4 newFlipMatrix =
        _config.value.flipMatrix ?? Matrix4.identity();

    if (vertical) {
      newFlipMatrix.rotateX(math.pi);
    } else {
      newFlipMatrix.rotateY(math.pi);
    }

    _config.value = _config.value.copy(flipMatrix: newFlipMatrix);

    if (!(widget.onFlipped?.call(newFlipMatrix) ?? true)) return;

    safeSetState(() {});
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
          previousConfig?.size != newConfig?.size ||
          previousConfig?.offset != newConfig?.offset ||
          previousConfig?.angle != newConfig?.angle ||
          previousConfig?.flipMatrix != newConfig?.flipMatrix,
      valueListenable: _config,
      builder: (_, _Config? config, Widget? child) {
        return Positioned(
          top: config?.offset.dy,
          left: config?.offset.dx,
          width: config?.size?.width,
          height: config?.size?.height,
          child: Transform.rotate(
            angle: config?.angle ?? 0,
            child: MouseRegion(
              cursor: _cursor,
              child: Listener(
                onPointerDown: (_) => _onPointerDown(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _movingStart,
                  onPanUpdate: _moveHandle,
                  onPanEnd: (_) {
                    _changeToIdle();
                    _boardController?.toggleCenterGuides(
                      newVerticalState: false,
                      newHorizontalState: false,
                    );
                  },
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: <Widget>[
                      if (_operationState != OperationState.complete) _border,
                      Transform(
                        transform: config?.flipMatrix ?? Matrix4.identity(),
                        alignment: Alignment.center,
                        child: _child,
                      ),
                      if (widget.tools != null) _tools,
                      if (_operationState != OperationState.complete) _flipY,
                      if (_operationState != OperationState.complete) _rotate,
                      if (_operationState != OperationState.complete) _flipX,
                      if (widget.onDelete != null &&
                          _operationState != OperationState.complete)
                        _delete,
                      if (widget.isEditable &&
                          _operationState != OperationState.complete)
                        _edit,
                      if (_operationState != OperationState.complete) _scale,
                    ],
                  ),
                ),
              ),
            ),
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
            _config.value.size = Size(size.width + _caseStyle.iconSize,
                size.height + _caseStyle.iconSize);
            originalSize = _config.value.size!;
            currentUnfittedSize = originalSize;
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: _caseStyle.borderColor,
            width: _caseStyle.borderWidth,
          ),
        ),
      ),
    );
  }

  /// 编辑手柄
  Widget get _edit {
    return Align(
      alignment: Alignment.bottomLeft,
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
    return Align(
      alignment: Alignment.topRight,
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
    return Align(
      alignment: Alignment.bottomRight,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        child: GestureDetector(
          onPanUpdate: (DragUpdateDetails dragUpdateDetails) =>
              _scaleHandle(dragUpdateDetails.delta),
          onPanEnd: _scalingEnd,
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
    return Align(
      alignment: Alignment.topLeft,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onPanStart: _rotationStart,
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

  /// 旋转手柄
  Widget get _flipX {
    return Align(
      alignment: Alignment.topCenter,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _flip(vertical: true),
          child: _toolCase(
            const RotatedBox(
              quarterTurns: 1,
              child: Icon(Icons.flip),
            ),
          ),
        ),
      ),
    );
  }

  /// 旋转手柄
  Widget get _flipY {
    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _flip(vertical: false),
          child: _toolCase(
            const Icon(Icons.flip),
          ),
        ),
      ),
    );
  }

  /// 操作手柄壳
  Widget _toolCase(Widget child) {
    return SizedBox(
      width: _caseStyle.iconSize,
      height: _caseStyle.iconSize,
      child: DecoratedBox(
        child: IconTheme(
          data: Theme.of(context).iconTheme.copyWith(
                color: _caseStyle.iconColor,
                size: _caseStyle.iconSize * 0.5,
              ),
          child: child,
        ),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _caseStyle.borderColor,
        ),
      ),
    );
  }

  /// 工具栏
  Widget get _tools {
    return Padding(
      padding: EdgeInsets.all(_caseStyle.iconSize / 2),
      child: widget.tools!,
    );
  }
}

class ItemCaseController {
  _ItemCaseState? _itemCaseState;

  void resizeCase(Offset scaleOffset) {
    _itemCaseState?._scaleHandle(
      scaleOffset / 2,
      cancelEditMode: false,
      keepAspectRatio: false,
    );
  }

  void dispose() {
    _itemCaseState = null;
  }

  SafeValueNotifier<_Config>? get config => _itemCaseState?._config;
}
