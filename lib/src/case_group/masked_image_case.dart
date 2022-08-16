import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../stack_board.dart';

extension ImageTool on ImageProvider {
  Future<Uint8List?> getBytes(BuildContext context,
      {ui.ImageByteFormat format = ui.ImageByteFormat.png}) async {
    final ImageStream imageStream =
        resolve(createLocalImageConfiguration(context));
    final Completer<Uint8List?> completer = Completer<Uint8List?>();
    final ImageStreamListener listener = ImageStreamListener(
      (ImageInfo imageInfo, bool synchronousCall) async {
        final ByteData? bytes =
            await imageInfo.image.toByteData(format: format);
        if (!completer.isCompleted) {
          completer.complete(bytes?.buffer.asUint8List());
        }
      },
    );
    imageStream.addListener(listener);
    final Uint8List? imageBytes = await completer.future;
    imageStream.removeListener(listener);
    return imageBytes;
  }
}

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

  ui.Image? mask;

  late ImageProvider? maskImage = widget.maskedImage.maskImage;

  final ItemCaseController _itemCaseController = ItemCaseController();

  @override
  Widget build(BuildContext context) {
    return ItemCase(
      controller: _itemCaseController,
      isEditable: true,
      onPointerDown: widget.onPointerDown,
      tapToEdit: widget.maskedImage.tapToEdit,
      onDelete: widget.onDelete,
      onSizeChanged: (_) {
        setState(() {});
        return true;
      },
      onOperationStateChanged: (OperationState operationState) {
        if (operationState == OperationState.editing) {
          FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: <String>['png'],
          ).then((FilePickerResult? result) {
            if (result != null) {
              final File file = File(result.files.single.path!);
              maskImage = FileImage(file);
              mask = null;
              setState(() {});
            }
          });
        }
        return true;
      },
      operationState: widget.operationState,
      caseStyle: widget.maskedImage.caseStyle,
      child: _buildMaskedImage(context),
    );
  }

  Widget _buildMaskedImage(BuildContext context) {
    return maskImage == null
        ? _buildImage
        : FutureBuilder<ui.ImageShader>(
            future: _createShaderImage(context, maskImage!),
            builder:
                (BuildContext context, AsyncSnapshot<ui.ImageShader> snapshot) {
              return snapshot.hasData
                  ? ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (_) => snapshot.data!,
                      child: _buildImage,
                    )
                  : _buildImage;
            },
          );
  }

  Widget get _buildImage {
    return Image(
      image: widget.maskedImage.image,
      width: defaultSize.width,
      height: defaultSize.height,
      fit: BoxFit.contain,
    );
  }

  Future<ui.ImageShader> _createShaderImage(
    BuildContext context,
    ImageProvider maskImage,
  ) async {
    if (mask == null) {
      final TypedData imageData =
          await maskImage.getBytes(context) ?? ByteData(0);

      final ui.Codec codec =
          await ui.instantiateImageCodec(imageData.buffer.asUint8List());
      final ui.FrameInfo frameInfo = await codec.getNextFrame();

      mask = frameInfo.image;
    }

    final Size caseSize = Size(
      (_itemCaseController.config?.value.size?.width ?? defaultSize.width) -
          (widget.maskedImage.caseStyle?.iconSize ?? 24),
      (_itemCaseController.config?.value.size?.height ?? defaultSize.height) -
          (widget.maskedImage.caseStyle?.iconSize ?? 24),
    );

    final Size size = applyBoxFit(
      BoxFit.contain,
      Size(
        mask!.width.toDouble(),
        mask!.height.toDouble(),
      ),
      caseSize,
    ).destination;

    final Matrix4 matrix = Matrix4.identity().scaled(
      size.width / mask!.width,
      size.height / mask!.height,
    );
    final ui.Offset center =
        caseSize.center(Offset.zero) - size.center(Offset.zero);
    matrix.leftTranslate(center.dx, center.dy);

    final ImageShader shader = ImageShader(
      mask!,
      TileMode.decal,
      TileMode.decal,
      matrix.storage,
    );

    return shader;
  }
}
