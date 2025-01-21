import 'dart:io';
import 'dart:ui' as ui; // for toImage
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image/image.dart' as img;
import 'package:photographers_reference_app/src/presentation/helpers/collage_save_helper.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

/// Состояние одного фото на канвасе (drag+zoom+zIndex).
class CollagePhotoState {
  final Photo photo;

  // Позиция и масштаб
  Offset offset;
  double scale;

  // Слои для наложения (чем больше, тем выше)
  int zIndex;

  /// "Базовый" масштаб при onScaleStart — для плавного зума
  double? baseScaleOnGesture;

  /// Сохраняем уже вычисленные размеры (без учёта `scale`)
  double baseWidth;
  double baseHeight;

  CollagePhotoState({
    required this.photo,
    required this.offset,
    required this.scale,
    required this.zIndex,
    required this.baseWidth,
    required this.baseHeight,
  });
}

class PhotoCollageWidget extends StatefulWidget {
  final List<Photo> photos;
  const PhotoCollageWidget({Key? key, required this.photos}) : super(key: key);

  @override
  State<PhotoCollageWidget> createState() => _PhotoCollageWidgetState();
}

class _PhotoCollageWidgetState extends State<PhotoCollageWidget> {
  final GlobalKey _collageKey = GlobalKey(); // для RepaintBoundary

  late List<CollagePhotoState> _items;
  int _maxZIndex = 0;

  /// Какое фото тянем (drag)
  int? _draggingIndex;

  /// Подсветка удаляющей иконки
  bool _deleteHover = false;

  /// Область экрана, где нарисована "иконка удаления"
  Rect _deleteRect = Rect.zero;

  Color _backgroundColor = Colors.black; // Цвет фона по умолчанию

  @override
  void initState() {
    super.initState();
    _initCollageItems();
  }

  /// Инициализация расположения фотографий (2..8)
  void _initCollageItems() {
    final List<CollagePhotoState> tempList = [];

    for (final photo in widget.photos) {
      // 1) Считаем базовые размеры
      double baseW = 150; // для всех
      double baseH = 150; // по умолчанию 150x150

      // 2) Пытаемся вычислить реальное соотношение
      final fullPath = PhotoPathHelper().getFullPath(photo.fileName);
      final file = File(fullPath);
      if (file.existsSync()) {
        final decoded = img.decodeImage(file.readAsBytesSync());
        if (decoded != null) {
          // ratio = decoded.height / decoded.width
          // baseH = ratio * baseW
          baseH = decoded.height * (baseW / decoded.width);
        }
      }

      tempList.add(
        CollagePhotoState(
          photo: photo,
          offset: Offset.zero,
          scale: 1.0,
          zIndex: 0,
          baseWidth: baseW,
          baseHeight: baseH,
        ),
      );
    }

    _items = tempList;

    final n = _items.length;
    // Ваши раскладки (2..8)
    switch (n) {
      case 2:
        _items[0].offset = const Offset(30, 30);
        _items[1].offset = const Offset(30, 300);
        break;
      case 3:
        _items[0].offset = const Offset(30, 30);
        _items[1].offset = const Offset(230, 30);
        _items[2].offset = const Offset(130, 200);
        break;
      case 4:
        _items[0].offset = const Offset(30, 30);
        _items[1].offset = const Offset(230, 30);
        _items[2].offset = const Offset(30, 230);
        _items[3].offset = const Offset(230, 230);
        break;
      case 5:
        _items[0].offset = const Offset(30, 30);
        _items[1].offset = const Offset(230, 30);
        _items[2].offset = const Offset(30, 230);
        _items[3].offset = const Offset(230, 230);
        _items[4].offset = const Offset(130, 400);
        break;
      case 6:
        _items[0].offset = const Offset(30, 30);
        _items[1].offset = const Offset(150, 30);
        _items[2].offset = const Offset(270, 30);
        _items[3].offset = const Offset(30, 200);
        _items[4].offset = const Offset(150, 200);
        _items[5].offset = const Offset(270, 200);
        break;
      case 7:
        _items[0].offset = const Offset(30, 30);
        _items[1].offset = const Offset(150, 30);
        _items[2].offset = const Offset(270, 30);
        _items[3].offset = const Offset(30, 200);
        _items[4].offset = const Offset(230, 200);
        _items[5].offset = const Offset(80, 370);
        _items[6].offset = const Offset(280, 370);
        break;
      case 8:
        _items[0].offset = const Offset(30, 30);
        _items[1].offset = const Offset(180, 30);
        _items[2].offset = const Offset(330, 30);
        _items[3].offset = const Offset(30, 200);
        _items[4].offset = const Offset(180, 200);
        _items[5].offset = const Offset(330, 200);
        _items[6].offset = const Offset(90, 370);
        _items[7].offset = const Offset(270, 370);
        break;
      default:
        break;
    }

    for (int i = 0; i < n; i++) {
      _items[i].zIndex = i;
    }
    _maxZIndex = n;
  }

  @override
  Widget build(BuildContext context) {
    // Сортируем _items по zIndex
    final sorted = [..._items]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final screenSize = MediaQuery.of(context).size;
    const iconSize = 64.0;
    final iconLeft = (screenSize.width - iconSize) / 2;
    final iconTop = screenSize.height - 80 - iconSize - 80;
    _deleteRect = Rect.fromLTWH(iconLeft, iconTop, iconSize, iconSize);

    return Scaffold(
      appBar: AppBar(
        title: Text('Collage (${widget.photos.length} photos)'),
      ),
      body: Column(
        children: [
          // Канвас
          Expanded(
            child: Stack(
              children: [
                Container(color: _backgroundColor),

                // RepaintBoundary => коллаж
                RepaintBoundary(
                  key: _collageKey,
                  child: SizedBox.expand(
                    child: Stack(
                      children: [
                        for (final item in sorted) _buildPhotoItem(item),
                      ],
                    ),
                  ),
                ),

                // Иконка удаления (если тянем)
                if (_draggingIndex != null)
                  Positioned(
                    left: iconLeft,
                    top: iconTop,
                    child: Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: _deleteHover ? Colors.red : Colors.white30,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ),

          // Меню снизу
          Container(
            height: 80,
            color: Colors.black54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.color_lens, color: Colors.white),
                  onPressed: _showColorPickerDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.done, color: Colors.white),
                  onPressed: _onGenerateCollage,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPickerDialog() {
    Color tempColor = _backgroundColor;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick Background Color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: tempColor,
              onColorChanged: (color) {
                tempColor = color;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрыть диалог
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _backgroundColor = tempColor; // Обновить цвет фона
                });
                Navigator.of(context).pop(); // Закрыть диалог
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Построение каждого фото
  Widget _buildPhotoItem(CollagePhotoState item) {
    final fullPath = PhotoPathHelper().getFullPath(item.photo.fileName);

    // На базе precomputed baseWidth/baseHeight
    double effectiveWidth = item.baseWidth * item.scale;
    double effectiveHeight = item.baseHeight * item.scale;

    return Positioned(
      left: item.offset.dx,
      top: item.offset.dy,
      child: GestureDetector(
        onTap: () {
          setState(() {
            // Повышаем zIndex
            _maxZIndex++;
            item.zIndex = _maxZIndex;
          });
        },
        onScaleStart: (details) {
          setState(() {
            item.baseScaleOnGesture = item.scale;
            _draggingIndex = _items.indexOf(item);
          });
        },
        onScaleUpdate: (details) {
          setState(() {
            // Перемещаем
            item.offset += details.focalPointDelta;

            // Плавный зум
            if (item.baseScaleOnGesture != null) {
              final newScale = item.baseScaleOnGesture! * details.scale;
              item.scale = newScale.clamp(0.5, 3.0);
            }

            // Проверка зоны удаления
            final pointer = details.focalPoint;
            final wasHover = _deleteHover;
            _deleteHover = _deleteRect.contains(pointer);
            if (_deleteHover && !wasHover) {
              vibrate(5);
            }
          });
        },
        onScaleEnd: (details) {
          setState(() {
            if (_deleteHover && _draggingIndex != null) {
              _items.removeAt(_draggingIndex!);
            }
            _draggingIndex = null;
            _deleteHover = false;
          });
        },
        child: Container(
          width: effectiveWidth,
          height: effectiveHeight,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Image.file(
            File(fullPath),
            width: effectiveWidth,
            height: effectiveHeight,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Future<void> _onGenerateCollage() async {
    await CollageSaveHelper.saveCollage(_collageKey, context);
  }
}
