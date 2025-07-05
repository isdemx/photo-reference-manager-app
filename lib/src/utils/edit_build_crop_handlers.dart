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

  Widget cornerWidget({
    required Alignment alignment,
    required bool isLeft,
    required bool isTop,
  }) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: GestureDetector(
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
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
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
