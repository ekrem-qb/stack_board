import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:stack_board/src/helper/operat_state.dart';
import 'package:stack_board/src/item_group/adaptive_text.dart';

import 'item_case.dart';

/// 默认文本样式
const TextStyle _defaultStyle = TextStyle(fontSize: 20);

/// 自适应文本外壳
class AdaptiveTextCase extends StatefulWidget {
  const AdaptiveTextCase({
    Key? key,
    required this.adaptiveText,
    this.onDelete,
    this.operationState,
    this.onPointerDown,
  }) : super(key: key);

  @override
  _AdaptiveTextCaseState createState() => _AdaptiveTextCaseState();

  /// 自适应文本对象
  final AdaptiveText adaptiveText;

  /// 移除拦截
  final void Function()? onDelete;

  /// 点击回调
  final void Function()? onPointerDown;

  /// 操作状态
  final OperationState? operationState;
}

class _AdaptiveTextCaseState extends State<AdaptiveTextCase>
    with SafeState<AdaptiveTextCase> {
  /// 是否正在编辑
  bool _isEditing = false;

  /// 文本内容
  late String _text = widget.adaptiveText.data;

  final FocusNode _focusNode = FocusNode();

  Size? oldSize;

  final ItemCaseController _itemCaseController = ItemCaseController();

  /// 文本样式
  TextStyle get _style => widget.adaptiveText.style ?? _defaultStyle;

  /// 计算文本大小
  Size _calculateTextSize() {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: _text, style: _style),
      textAlign: widget.adaptiveText.textAlign ?? TextAlign.center,
      textDirection: widget.adaptiveText.textDirection ?? TextDirection.ltr,
      maxLines: widget.adaptiveText.maxLines,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  Offset _calculateTextOffset() {
    final Size newSize = _calculateTextSize();

    final Offset scaleOffset = Offset(
        newSize.width - (oldSize?.width ?? newSize.width),
        newSize.height - (oldSize?.height ?? newSize.height));

    oldSize = newSize;

    _itemCaseController.resizeCase(scaleOffset);

    return scaleOffset;
  }

  @override
  void initState() {
    super.initState();
    _calculateTextOffset();
  }

  @override
  Widget build(BuildContext context) {
    return ItemCase(
      controller: _itemCaseController,
      isCentered: false,
      isEditable: true,
      onPointerDown: widget.onPointerDown,
      tapToEdit: widget.adaptiveText.tapToEdit,
      child: _buildEditingBox,
      onDelete: widget.onDelete,
      operationState: widget.operationState,
      caseStyle: widget.adaptiveText.caseStyle,
      onOperationStateChanged: (OperationState s) {
        if (s != OperationState.editing && _isEditing) {
          safeSetState(() => _isEditing = false);
        } else if (s == OperationState.editing && !_isEditing) {
          safeSetState(() {
            _isEditing = true;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _focusNode.requestFocus());
          });
        }

        return;
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();

    super.dispose();
  }

  /// 正在编辑
  Widget get _buildEditingBox {
    return FittedBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: _calculateTextSize().width + 32,
          child: TextFormField(
            enabled: _isEditing,
            focusNode: _focusNode,
            decoration: const InputDecoration(border: InputBorder.none),
            initialValue: _text,
            onChanged: (String newText) {
              _text = newText;
              _calculateTextOffset();
              safeSetState(() {});
            },
            style: _style,
            textAlign: widget.adaptiveText.textAlign ?? TextAlign.center,
            textDirection: widget.adaptiveText.textDirection,
            maxLines: widget.adaptiveText.maxLines,
          ),
        ),
      ),
    );
  }
}
