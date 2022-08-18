import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../stack_board.dart';

class MaskedImageCase extends StatefulWidget {
  const MaskedImageCase({
    Key? key,
    required this.maskedImage,
    this.onDelete,
    this.onPointerDown,
    this.operationState,
  }) : super(key: key);

  final MaskedImage maskedImage;

  final void Function()? onDelete;

  final void Function()? onPointerDown;

  final OperationState? operationState;

  @override
  State<MaskedImageCase> createState() => _MaskedImageCaseState();
}

class _MaskedImageCaseState extends State<MaskedImageCase> {
  static const Size defaultSize = Size(355, 236.5);
  static const double sizeChangeTreshold = 1.5;

  final ItemCaseController _itemCaseController = ItemCaseController();

  late String? _maskSvgString = widget.maskedImage.mask;
  String? get maskSvgString => _maskSvgString;
  set maskSvgString(String? newSvgString) {
    _maskSvgString = newSvgString;
    if (newSvgString != null) {
      _parseSvg();
    }
  }

  late DrawableRoot _maskSvg;
  late ui.Image _maskSvgImage;
  late Size _maskSvgOldSize;
  late Size _maskSvgCurrentSize;

  Stream<ui.ImageShader?> get _shaderImage => _shaderImageController.stream;
  final StreamController<ui.ImageShader?> _shaderImageController =
      StreamController<ui.ImageShader?>();

  Future<void> _parseSvg() async {
    _maskSvg = await svg.fromSvgString(maskSvgString!, '');
    _calculateSvgSize();
    _maskSvgOldSize = _maskSvgCurrentSize;
    _renderSvg();
  }

  bool? _onSizeChanged(Size newSize) {
    if (_maskSvgString != null) {
      _calculateSvgSize();

      final double oldSize =
          (_maskSvgOldSize.width + _maskSvgOldSize.height) / 2;
      final double newSize =
          (_maskSvgCurrentSize.width + _maskSvgCurrentSize.height) / 2;

      if (max(newSize, oldSize) / min(newSize, oldSize) > sizeChangeTreshold) {
        _maskSvgOldSize = _maskSvgCurrentSize;
        _renderSvg();
      } else {
        _renderShader();
      }
    }
    return true;
  }

  bool? _onResizeDone(ui.Size size) {
    if (_maskSvgString != null) {
      _calculateSvgSize();
      _maskSvgOldSize = _maskSvgCurrentSize;
      _renderSvg();
    }
    return true;
  }

  Future<void> _renderSvg() async {
    _maskSvgImage = await _maskSvg
        .toPicture(
          size: _maskSvgCurrentSize,
        )
        .toImage(
          _maskSvgCurrentSize.width.toInt(),
          _maskSvgCurrentSize.height.toInt(),
        );

    _renderShader();
  }

  void _calculateSvgSize() {
    final Size caseSize = Size(
      (_itemCaseController.config?.value.size?.width ?? defaultSize.width) -
          (widget.maskedImage.caseStyle?.iconSize ?? 24),
      (_itemCaseController.config?.value.size?.height ?? defaultSize.height) -
          (widget.maskedImage.caseStyle?.iconSize ?? 24),
    );

    _maskSvgCurrentSize = applyBoxFit(
      BoxFit.contain,
      Size(
        _maskSvg.viewport.viewBox.width,
        _maskSvg.viewport.viewBox.height,
      ),
      caseSize,
    ).destination;
  }

  void _renderShader() {
    final Size caseSize = Size(
      (_itemCaseController.config?.value.size?.width ?? defaultSize.width) -
          (widget.maskedImage.caseStyle?.iconSize ?? 24),
      (_itemCaseController.config?.value.size?.height ?? defaultSize.height) -
          (widget.maskedImage.caseStyle?.iconSize ?? 24),
    );

    final Size maskSize = ui.Size(
      _maskSvgImage.width.toDouble(),
      _maskSvgImage.height.toDouble(),
    );

    final ui.Offset center =
        caseSize.center(Offset.zero) - _maskSvgCurrentSize.center(Offset.zero);

    final Matrix4 matrix = Matrix4.identity()
      ..scale(
        _maskSvgCurrentSize.width / maskSize.width,
        _maskSvgCurrentSize.height / maskSize.height,
      )
      ..leftTranslate(center.dx, center.dy);

    final ImageShader shader = ImageShader(
      _maskSvgImage,
      TileMode.clamp,
      TileMode.clamp,
      matrix.storage,
    );

    _shaderImageController.add(shader);
  }

  void _onEdit() {
    FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['svg'],
    ).then((FilePickerResult? result) async {
      if (result != null) {
        final File file = File(result.files.single.path!);
        maskSvgString = await file.readAsString();
      } else {
        maskSvgString = null;
        _shaderImageController.add(null);
      }
    });
  }

  Widget get _buildImage {
    return Image(
      image: widget.maskedImage.image,
      width: defaultSize.width,
      height: defaultSize.height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (
        BuildContext context,
        Widget child,
        ImageChunkEvent? loadingProgress,
      ) {
        return loadingProgress != null
            ? Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!,
                ),
              )
            : child;
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (maskSvgString != null) {
      _parseSvg();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ui.ImageShader?>(
      stream: _shaderImage,
      builder: (BuildContext context, AsyncSnapshot<ui.ImageShader?> snapshot) {
        return ItemCase(
          controller: _itemCaseController,
          isEditable: true,
          onPointerDown: widget.onPointerDown,
          tapToEdit: widget.maskedImage.tapToEdit,
          onDelete: widget.onDelete,
          onSizeChanged: _onSizeChanged,
          onResizeDone: _onResizeDone,
          onOperationStateChanged: (OperationState operationState) {
            if (operationState == OperationState.editing) {
              _onEdit();
            }
            return true;
          },
          operationState: widget.operationState,
          caseStyle: widget.maskedImage.caseStyle,
          child: snapshot.hasData
              ? ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (_) => snapshot.data!,
                  child: _buildImage,
                )
              : _buildImage,
        );
      },
    );
  }
}
