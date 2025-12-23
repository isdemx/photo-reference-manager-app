import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage_photo.dart';

Rect calcCropRect(
  Offset delta,
  bool isLeft,
  bool isTop,
  Rect cropRect,
  double w,
  double h,
) {
  final dxNorm = delta.dx / w;
  final dyNorm = delta.dy / h;

  double left = cropRect.left;
  double top = cropRect.top;
  double right = cropRect.right;
  double bottom = cropRect.bottom;

  if (isLeft) left += dxNorm;
  if (isTop) top += dyNorm;
  if (!isLeft) right += dxNorm;
  if (!isTop) bottom += dyNorm;

  left = left.clamp(0.0, 1.0);
  top = top.clamp(0.0, 1.0);
  right = right.clamp(0.0, 1.0);
  bottom = bottom.clamp(0.0, 1.0);

  if (right < left) {
    final tmp = right;
    right = left;
    left = tmp;
  }
  if (bottom < top) {
    final tmp = bottom;
    bottom = top;
    top = tmp;
  }

  return Rect.fromLTRB(left, top, right, bottom);
}

List<Widget> buildCropHandles(
  CollagePhotoState item,
  double w,
  double h,
  void Function(Rect) onUpdateCropRect,
) {
  final handles = <Widget>[];

  Widget cornerHandlePaint({
    required bool isLeft,
    required bool isTop,
  }) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _CornerHandlePainter(
          isLeft: isLeft,
          isTop: isTop,
        ),
      ),
    );
  }

  Widget cornerWidget({
    required Alignment alignment,
    required bool isLeft,
    required bool isTop,
  }) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (details) {
            final newRect = calcCropRect(
              details.delta,
              isLeft,
              isTop,
              item.cropRect,
              w,
              h,
            );
            onUpdateCropRect(newRect);
          },
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: cornerHandlePaint(isLeft: isLeft, isTop: isTop),
            ),
          ),
        ),
      ),
    );
  }

  // четыре угла
  handles.add(
      cornerWidget(alignment: Alignment.topLeft, isLeft: true, isTop: true));
  handles.add(
      cornerWidget(alignment: Alignment.topRight, isLeft: false, isTop: true));
  handles.add(cornerWidget(
      alignment: Alignment.bottomLeft, isLeft: true, isTop: false));
  handles.add(cornerWidget(
      alignment: Alignment.bottomRight, isLeft: false, isTop: false));

  return handles;
}

class _CornerHandlePainter extends CustomPainter {
  final bool isLeft;
  final bool isTop;

  const _CornerHandlePainter({
    required this.isLeft,
    required this.isTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final corner = Offset(isLeft ? 0.0 : size.width, isTop ? 0.0 : size.height);
    const double len = 10.0;
    const double stroke = 2.0;

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;

    final red = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;

    final horizontalEnd = Offset(
      corner.dx + (isLeft ? len : -len),
      corner.dy,
    );
    final verticalEnd = Offset(
      corner.dx,
      corner.dy + (isTop ? len : -len),
    );

    canvas.drawLine(corner, horizontalEnd, white);
    canvas.drawLine(corner, verticalEnd, white);

    final redLen = 6.0;
    final redHorizontalEnd = Offset(
      corner.dx + (isLeft ? redLen : -redLen),
      corner.dy,
    );
    final redVerticalEnd = Offset(
      corner.dx,
      corner.dy + (isTop ? redLen : -redLen),
    );

    canvas.drawLine(corner, redHorizontalEnd, red);
    canvas.drawLine(corner, redVerticalEnd, red);
  }

  @override
  bool shouldRepaint(covariant _CornerHandlePainter oldDelegate) {
    return oldDelegate.isLeft != isLeft || oldDelegate.isTop != isTop;
  }
}
