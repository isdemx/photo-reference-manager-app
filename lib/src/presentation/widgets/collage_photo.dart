import 'dart:io';
import 'dart:ui' as ui; // for toImage
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:iconsax/iconsax.dart';
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

/// Состояние одного фото (drag+zoom+zIndex).
class CollagePhotoState {
  final Photo photo;

  // Позиция и масштаб
  Offset offset;
  double scale;

  // Слои наложения (чем больше, тем выше)
  int zIndex;

  /// Базовый масштаб при onScaleStart — для плавного зума
  double? baseScaleOnGesture;

  /// "Исходные" размеры (без учёта `scale`)
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
  /// Начальный набор фотографий, уже выбранных для коллажа
  final List<Photo> photos;

  /// Все доступные фотографии, чтобы можно было добавлять новые
  final List<Photo> allPhotos;

  const PhotoCollageWidget({
    Key? key,
    required this.photos,
    required this.allPhotos,
  }) : super(key: key);

  @override
  State<PhotoCollageWidget> createState() => _PhotoCollageWidgetState();
}

class _PhotoCollageWidgetState extends State<PhotoCollageWidget> {
  final GlobalKey _collageKey = GlobalKey(); // для RepaintBoundary
  final GlobalKey _deleteIconKey = GlobalKey(); // для измерения иконки удаления

  late List<CollagePhotoState> _items; // Состояния фото
  int _maxZIndex = 0;

  /// Индекс перетаскиваемого фото
  int? _draggingIndex;

  /// Подсветка при наведении на иконку удаления
  bool _deleteHover = false;

  /// Реальный прямоугольник для зоны удаления
  Rect _deleteRect = Rect.zero;

  /// Цвет фона по умолчанию
  Color _backgroundColor = Colors.black;

  /// Флаг для отображения мини-руководства
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    _initCollageItems();

    // После построения виджета вычислим реальные координаты иконки удаления
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDeleteRect();
    });
  }

  /// Инициализация состояния фото для начальных widget.photos
  void _initCollageItems() {
    _items = widget.photos.map((p) => _createCollagePhotoState(p)).toList();

    // Пример простого размещения (псевдо-раскладки для n=2..8)
    final n = _items.length;
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
      // Добавьте остальные кейсы при необходимости...
      default:
        // Не делаем раскладку
        break;
    }

    // zIndex
    for (int i = 0; i < _items.length; i++) {
      _items[i].zIndex = i;
    }
    _maxZIndex = _items.length;
  }

  /// Фабрика создания `CollagePhotoState` — вычисляет baseWidth/baseHeight
  CollagePhotoState _createCollagePhotoState(Photo photo) {
    const double initialWidth = 150.0;
    double baseW = initialWidth;
    double baseH = initialWidth;

    final fullPath = PhotoPathHelper().getFullPath(photo.fileName);
    final file = File(fullPath);
    if (file.existsSync()) {
      final decoded = img.decodeImage(file.readAsBytesSync());
      if (decoded != null && decoded.width != 0) {
        baseH = decoded.height * (baseW / decoded.width);
      }
    }

    return CollagePhotoState(
      photo: photo,
      offset: Offset.zero,
      scale: 1.0,
      zIndex: 0,
      baseWidth: baseW,
      baseHeight: baseH,
    );
  }

  /// Пересчёт позиции и размеров зоны удаления
  void _updateDeleteRect() {
    final iconBox =
        _deleteIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (iconBox == null) return;

    final position = iconBox.localToGlobal(Offset.zero);
    _deleteRect = Rect.fromLTWH(
      position.dx,
      position.dy,
      iconBox.size.width,
      iconBox.size.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Сортируем фото по zIndex, чтобы "верхние" рендерились последними
    final sorted = [..._items]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return Scaffold(
      appBar: AppBar(
        title: Text('Free collage (${_items.length} images)'),
      ),
      body: Column(
        children: [
          // Канвас
          Expanded(
            child: Stack(
              children: [
                Container(color: _backgroundColor),

                // Наш коллаж (RepaintBoundary)
                RepaintBoundary(
                  key: _collageKey,
                  child: Stack(
                    children: [
                      // Расширяем на весь экран
                      Positioned.fill(
                          child: Container(color: _backgroundColor)),

                      for (final item in sorted) _buildPhotoItem(item),
                    ],
                  ),
                ),

                // Иконка удаления (прикрепляем GlobalKey)
                if (_draggingIndex != null)
                  Positioned(
                    key: _deleteIconKey,
                    left: 0,
                    right: 0,
                    bottom: 100, // Расположим над нижними кнопками
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _deleteHover ? Colors.red : Colors.white30,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete, color: Colors.black),
                      ),
                    ),
                  ),

                // Туториал
                if (_showTutorial)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.8),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app,
                                size: 60, color: Colors.white),
                            const SizedBox(height: 20),
                            const Text(
                              'Move with one finger\nZoom with two fingers\nPlace on top with a tap',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showTutorial = false;
                                });
                              },
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      ),
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
                  icon: const Icon(Iconsax.add, color: Colors.white),
                  tooltip: 'Add photo',
                  onPressed: _showAllPhotosSheet,
                ),
                IconButton(
                  icon: const Icon(Iconsax.colorfilter, color: Colors.white),
                  tooltip: 'Change background color',
                  onPressed: _showColorPickerDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.done, color: Colors.white),
                  tooltip: 'Save collage as image',
                  onPressed: _onGenerateCollage,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Cancel collage',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Диалог выбора цвета
  void _showColorPickerDialog() {
    final oldColor = _backgroundColor;
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
                setState(() => _backgroundColor = tempColor);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _backgroundColor = oldColor;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _backgroundColor = tempColor);
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Построение каждого фото внутри коллажа
  Widget _buildPhotoItem(CollagePhotoState item) {
    final fullPath = PhotoPathHelper().getFullPath(item.photo.fileName);

    // Учитываем "масштабированные" размеры
    final effectiveWidth = item.baseWidth * item.scale;
    final effectiveHeight = item.baseHeight * item.scale;

    return Positioned(
      left: item.offset.dx,
      top: item.offset.dy,
      child: GestureDetector(
        onTap: () {
          // Повышаем zIndex, фото становится "выше" других
          setState(() {
            _maxZIndex++;
            item.zIndex = _maxZIndex;
          });
        },
        onScaleStart: (_) {
          // Начинаем перетаскивать
          setState(() {
            item.baseScaleOnGesture = item.scale;
            _draggingIndex = _items.indexOf(item);
          });
        },
        onScaleUpdate: (details) {
          setState(() {
            // Двигаем по экрану
            item.offset += details.focalPointDelta;

            // Зум
            if (item.baseScaleOnGesture != null) {
              final newScale = item.baseScaleOnGesture! * details.scale;
              item.scale = newScale.clamp(0.5, 3.0);
            }

            // Проверяем зону удаления
            final pointer = details.focalPoint; // Глобальные координаты
            final wasHover = _deleteHover;
            _deleteHover = _deleteRect.contains(pointer);
            if (_deleteHover && !wasHover) {
              vibrate(5);
            }
          });
        },
        onScaleEnd: (_) {
          // Завершаем перетаскивание
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

  /// Сохранение коллажа в изображение
  Future<void> _onGenerateCollage() async {
    await CollageSaveHelper.saveCollage(_collageKey, context);
  }

  /// Показать лист всех фотографий -> выбор -> добавить
  void _showAllPhotosSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final all = widget.allPhotos;
        return Container(
          color: Colors.black,
          padding: const EdgeInsets.all(8),
          child: GridView.builder(
            itemCount: all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 4 миниатюры в ряду
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final photo = all[index];
              final path = PhotoPathHelper().getFullPath(photo.fileName);

              return GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Закрываем BottomSheet
                  _addPhotoToCollage(photo);
                },
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Добавление нового фото в коллаж
  void _addPhotoToCollage(Photo photo) {
    setState(() {
      final collageState = _createCollagePhotoState(photo);
      // Ставим фото куда-нибудь (например, слева сверху)
      collageState.offset = const Offset(50, 50);

      // Увеличиваем zIndex
      _maxZIndex++;
      collageState.zIndex = _maxZIndex;

      // Добавляем в список
      _items.add(collageState);
    });
  }
}
