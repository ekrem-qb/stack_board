import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';

class CenterGuides extends StatefulWidget {
  const CenterGuides({
    Key? key,
    this.controller,
    this.child,
  }) : super(key: key);

  final CenterGuidesController? controller;
  final Widget? child;

  @override
  State<CenterGuides> createState() => _CenterGuidesState();
}

class _CenterGuidesState extends State<CenterGuides>
    with SafeState<CenterGuides> {
  bool _isVerticalGuidesEnabled = false;
  bool _isHorizontalGuidesEnabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller?._centerGuidesState = this;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        child: widget.child,
        foregroundPainter: _CenterGuidesPainter(
          drawVerticalGuides: _isVerticalGuidesEnabled,
          drawHorizontalGuides: _isHorizontalGuidesEnabled,
        ),
      ),
    );
  }
}

class _CenterGuidesPainter extends CustomPainter {
  _CenterGuidesPainter({
    required this.drawVerticalGuides,
    required this.drawHorizontalGuides,
  });

  static const int dashLength = 8;
  static const int dashSpace = 8;
  final bool drawVerticalGuides;
  final bool drawHorizontalGuides;
  late Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    if (drawVerticalGuides || drawHorizontalGuides) {
      final Paint paint = Paint()
        ..color = Colors.grey
        ..strokeCap = StrokeCap.square
        ..strokeWidth = 2;

      center = size.center(Offset.zero);

      if (drawVerticalGuides)
        _drawDashedLine(canvas, size, paint, vertical: true);
      if (drawHorizontalGuides)
        _drawDashedLine(canvas, size, paint, vertical: false);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }

  void _drawDashedLine(
    Canvas canvas,
    Size size,
    Paint paint, {
    required bool vertical,
  }) {
    final double length = vertical ? size.height : size.width;
    final double lineCenter = vertical ? center.dx : center.dy;

    // Repeat drawing until we reach the right edge.
    for (double currentPosition = 0;
        currentPosition < length;
        currentPosition += dashLength + dashSpace) {
      // Draw a small line.
      canvas.drawLine(
        vertical
            ? Offset(lineCenter, currentPosition)
            : Offset(currentPosition, lineCenter),
        vertical
            ? Offset(lineCenter, currentPosition + dashLength)
            : Offset(currentPosition + dashLength, lineCenter),
        paint,
      );
    }
  }
}

class CenterGuidesController {
  _CenterGuidesState? _centerGuidesState;

  void toggleGuides({bool? newVerticalState, bool? newHorizontalState}) {
    if (newVerticalState != null)
      _centerGuidesState?._isVerticalGuidesEnabled = newVerticalState;
    if (newHorizontalState != null)
      _centerGuidesState?._isHorizontalGuidesEnabled = newHorizontalState;

    _centerGuidesState?.safeSetState(() {});
  }

  void dispose() {
    _centerGuidesState = null;
  }
}
