import 'package:flutter/material.dart';
import 'package:stack_board/src/helper/case_style.dart';

import 'stack_board_item.dart';

/// 自适应文本
class MaskedImage extends StackBoardItem {
  const MaskedImage(
    this.image, {
    this.maskImage,
    final int? id,
    final Future<bool> Function()? onDelete,
    CaseStyle? caseStyle,
    bool? tapToEdit,
  }) : super(
          id: id,
          onDelete: onDelete,
          child: const SizedBox.shrink(),
          caseStyle: caseStyle,
          tapToEdit: tapToEdit ?? false,
        );

  final ImageProvider image;
  final ImageProvider? maskImage;

  @override
  MaskedImage copyWith({
    ImageProvider? image,
    ImageProvider? maskImage,
    int? id,
    Widget? child,
    Function(bool)? onEdit,
    Future<bool> Function()? onDelete,
    CaseStyle? caseStyle,
    bool? tapToEdit,
  }) {
    return MaskedImage(
      image ?? this.image,
      maskImage: maskImage ?? this.maskImage,
      id: id ?? this.id,
      onDelete: onDelete ?? this.onDelete,
      caseStyle: caseStyle ?? this.caseStyle,
      tapToEdit: tapToEdit ?? this.tapToEdit,
    );
  }
}
