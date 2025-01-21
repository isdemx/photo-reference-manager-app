import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/collage_save_helper.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class GridCollageWidget extends StatefulWidget {
  final List<Photo> photos;

  const GridCollageWidget({Key? key, required this.photos}) : super(key: key);

  @override
  State<GridCollageWidget> createState() => _GridCollageWidgetState();
}

class _GridCollageWidgetState extends State<GridCollageWidget> {
  bool isGridMode = true; // Режим отображения: true - Grid, false - Full Screen
  final GlobalKey _collageKey = GlobalKey();

  /// Генерация (склейка) коллажа
  Future<void> _onGenerateCollage() async {
    await CollageSaveHelper.saveCollage(_collageKey, context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collage Modes'),
      ),
      body: Stack(
        children: [
          RepaintBoundary(
            key: _collageKey,
            child: isGridMode ? _buildGridMode() : _buildFullScreenMode(),
          ),
          _buildBottomMenu(),
        ],
      ),
    );
  }

  /// Grid Mode - динамическая генерация макетов для 2-8 фотографий
  Widget _buildFullScreenMode() {
    final List<Photo?> displayPhotos = List.generate(8, (index) {
      return index < widget.photos.length ? widget.photos[index] : null;
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final double fullWidth = constraints.maxWidth;
        final double fullHeight = constraints.maxHeight;

        return Stack(
          children:
              _generateCollageLayout(displayPhotos, fullWidth, fullHeight),
        );
      },
    );
  }

  /// Генерация шаблонов на основе количества фотографий
  List<Widget> _generateCollageLayout(
      List<Photo?> photos, double fullWidth, double fullHeight) {
    List<Widget> widgets = [];
    double cellWidth;
    double cellHeight;

    switch (widget.photos.length) {
      case 2:
        cellWidth = fullWidth;
        cellHeight = fullHeight / 2;
        for (int i = 0; i < 2; i++) {
          widgets.add(
            Positioned(
              top: i * cellHeight,
              left: 0,
              width: cellWidth,
              height: cellHeight,
              child: _buildPhotoContainer(photos[i], cellWidth, cellHeight),
            ),
          );
        }
        break;

      case 3:
        cellWidth = fullWidth / 2;
        cellHeight = fullHeight / 2;
        widgets.addAll([
          for (int i = 0; i < 2; i++)
            Positioned(
              top: 0,
              left: i * cellWidth,
              width: cellWidth,
              height: cellHeight,
              child: _buildPhotoContainer(photos[i], cellWidth, cellHeight),
            ),
          Positioned(
            top: cellHeight,
            left: 0,
            width: fullWidth,
            height: cellHeight,
            child: _buildPhotoContainer(photos[2], fullWidth, cellHeight),
          ),
        ]);
        break;

      case 4:
        cellWidth = fullWidth / 2;
        cellHeight = fullHeight / 2;
        for (int i = 0; i < 4; i++) {
          widgets.add(
            Positioned(
              top: (i ~/ 2) * cellHeight,
              left: (i % 2) * cellWidth,
              width: cellWidth,
              height: cellHeight,
              child: _buildPhotoContainer(photos[i], cellWidth, cellHeight),
            ),
          );
        }
        break;

      case 5:
        cellWidth = fullWidth / 2;
        cellHeight = fullHeight / 3;
        widgets.addAll([
          for (int i = 0; i < 2; i++)
            Positioned(
              top: 0,
              left: i * cellWidth,
              width: cellWidth,
              height: cellHeight,
              child: _buildPhotoContainer(photos[i], cellWidth, cellHeight),
            ),
          Positioned(
            top: cellHeight,
            left: 0,
            width: fullWidth,
            height: cellHeight,
            child: _buildPhotoContainer(photos[2], fullWidth, cellHeight),
          ),
          for (int i = 3; i < 5; i++)
            Positioned(
              top: 2 * cellHeight,
              left: (i % 2) * cellWidth,
              width: cellWidth,
              height: cellHeight,
              child: _buildPhotoContainer(photos[i], cellWidth, cellHeight),
            ),
        ]);
        break;

      case 6:
        cellWidth = fullWidth / 2;
        cellHeight = fullHeight / 3;
        for (int i = 0; i < 6; i++) {
          widgets.add(
            Positioned(
              top: (i ~/ 2) * cellHeight,
              left: (i % 2) * cellWidth,
              width: cellWidth,
              height: cellHeight,
              child: _buildPhotoContainer(photos[i], cellWidth, cellHeight),
            ),
          );
        }
        break;

      case 7:
        cellWidth = fullWidth / 2;
        cellHeight = fullHeight / 3;
        for (int i = 0; i < 6; i++) {
          widgets.add(
            Positioned(
              top: (i ~/ 2) * cellHeight,
              left: (i % 2) * cellWidth,
              width: cellWidth,
              height: cellHeight,
              child: _buildPhotoContainer(photos[i], cellWidth, cellHeight),
            ),
          );
        }
        widgets.add(
          Positioned(
            top: 3 * cellHeight,
            left: 0,
            width: fullWidth,
            height: cellHeight,
            child: _buildPhotoContainer(photos[6], fullWidth, cellHeight),
          ),
        );
        break;

      case 8:
        cellWidth = fullWidth / 2;
        cellHeight = fullHeight / 4;
        for (int i = 0; i < 8; i++) {
          widgets.add(
            Positioned(
              top: (i ~/ 2) * cellHeight,
              left: (i % 2) * cellWidth,
              width: cellWidth,
              height: cellHeight,
              child: _buildPhotoContainer(photos[i], cellWidth, cellHeight),
            ),
          );
        }
        break;
    }
    return widgets;
  }

  /// Создание контейнера с фото
  Widget _buildPhotoContainer(Photo? photo, double width, double height) {
    return Container(
      color: Colors.black12,
      child: photo != null
          ? InteractivePhotoItem(
              photo: photo,
              maxWidth: width,
              maxHeight: height,
            )
          : const SizedBox.shrink(),
    );
  }

  /// Grid Mode - стандартная сетка 2xN
  Widget _buildGridMode() {
    final List<Photo?> displayPhotos = List.generate(8, (index) {
      return index < widget.photos.length ? widget.photos[index] : null;
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cellWidth =
            constraints.maxWidth / 2; // Делим экран на 2 колонки
        final double cellHeight =
            constraints.maxWidth / 2; // Высота равна ширине ячейки

        return Stack(
          children: [
            for (int i = 0; i < 8; i++)
              if (displayPhotos[i] != null)
                Positioned(
                  left: (i % 2) * cellWidth, // Вычисляем позицию по колонке
                  top: (i ~/ 2) * cellHeight, // Вычисляем позицию по строке
                  width: cellWidth,
                  height: cellHeight,
                  child: Container(
                    color: Colors.black12, // Фон для пустых ячеек
                    child: InteractivePhotoItem(
                      photo: displayPhotos[i]!,
                      maxWidth: cellWidth,
                      maxHeight: cellHeight,
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  /// Нижнее меню
  Widget _buildBottomMenu() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        color: Colors.black54,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(
                Icons.grid_on,
                color: isGridMode ? Colors.blue : Colors.white,
              ),
              onPressed: () {
                setState(() {
                  isGridMode = true;
                });
              },
            ),
            IconButton(
              icon: Icon(
                Icons.fullscreen,
                color: !isGridMode ? Colors.blue : Colors.white,
              ),
              onPressed: () {
                setState(() {
                  isGridMode = false;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: _onGenerateCollage,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                Navigator.pop(context); // Закрыть виджет
              },
            ),
          ],
        ),
      ),
    );
  }
}

class InteractivePhotoItem extends StatefulWidget {
  final Photo photo;
  final double? maxWidth;
  final double? maxHeight;

  const InteractivePhotoItem({
    Key? key,
    required this.photo,
    this.maxWidth,
    this.maxHeight,
  }) : super(key: key);

  @override
  State<InteractivePhotoItem> createState() => _InteractivePhotoItemState();
}

class _InteractivePhotoItemState extends State<InteractivePhotoItem> {
  double scale = 1.0;
  Offset offset = Offset.zero;
  double baseScale = 1.0;
  Offset? startFocalPoint;

  @override
  Widget build(BuildContext context) {
    final fullPath = PhotoPathHelper().getFullPath(widget.photo.fileName);

    final maxWidth = widget.maxWidth ?? double.infinity;
    final maxHeight = widget.maxHeight ?? double.infinity;

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onScaleStart: (details) {
              startFocalPoint = details.focalPoint;
              baseScale = scale;
            },
            onScaleUpdate: (details) {
              setState(() {
                scale = (baseScale * details.scale).clamp(1.0, 3.0);
                if (startFocalPoint != null) {
                  final Offset delta = details.focalPoint - startFocalPoint!;
                  offset += delta;
                  startFocalPoint = details.focalPoint;
                }

                // Ограничиваем перемещение фото в пределах ячейки
                offset = Offset(
                  offset.dx.clamp(-maxWidth * (scale - 1), 0),
                  offset.dy.clamp(-maxHeight * (scale - 1), 0),
                );
              });
            },
            child: Stack(
              children: [
                Positioned(
                  left: offset.dx,
                  top: offset.dy,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topLeft,
                    child: Image.file(
                      File(fullPath),
                      width: maxWidth,
                      height: maxHeight,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
