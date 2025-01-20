import 'dart:io';
import 'dart:ui' as ui; // for toImage
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
// Для вибрации — проверьте, правильно ли у вас подключена зависимость vibration
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
  Offset offset;
  double scale;
  int zIndex;

  /// Для «плавного» зума мы сохраняем «базовый» scale
  /// при onScaleStart. При onScaleUpdate используем
  /// = baseScaleOnGesture * details.scale
  double? baseScaleOnGesture;

  CollagePhotoState({
    required this.photo,
    required this.offset,
    required this.scale,
    required this.zIndex,
  });
}

class PhotoCollageWidget extends StatefulWidget {
  final List<Photo> photos;

  const PhotoCollageWidget({Key? key, required this.photos}) : super(key: key);

  @override
  State<PhotoCollageWidget> createState() => _PhotoCollageWidgetState();
}

class _PhotoCollageWidgetState extends State<PhotoCollageWidget> {
  final GlobalKey _collageKey = GlobalKey();

  late List<CollagePhotoState> _items;
  int _maxZIndex = 0;

  /// Информация о «текущем» перетаскивании (какую фотку тянем)
  int? _draggingIndex;

  /// Нужно ли подсветить «delete icon»
  bool _deleteHover = false;

  /// Прямоугольник (позиция) «иконки удаления»
  Rect _deleteRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _initCollageItems();
  }

  void _initCollageItems() {
    _items = widget.photos.map((p) {
      return CollagePhotoState(
        photo: p,
        offset: Offset.zero,
        scale: 1.0,
        zIndex: 0,
      );
    }).toList();

    final n = _items.length; // 2..8 (по условию)
    // Делайте "ближе" — т.е. меньше расстояния
    // Просто пример (вы можете поправить координаты по вкусу)
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
        // 2+2+1 схема (пример)
        _items[0].offset = const Offset(30, 30);
        _items[1].offset = const Offset(230, 30);
        _items[2].offset = const Offset(30, 230);
        _items[3].offset = const Offset(230, 230);
        _items[4].offset = const Offset(130, 400);
        break;
      case 6:
        // 2+2+2
        _items[0].offset = const Offset(30, 30);
        _items[1].offset = const Offset(150, 30);
        _items[2].offset = const Offset(270, 30);
        _items[3].offset = const Offset(30, 200);
        _items[4].offset = const Offset(150, 200);
        _items[5].offset = const Offset(270, 200);
        break;
      case 7:
        // 3+2+2, скажем
        _items[0].offset = const Offset(30, 30);
        _items[1].offset = const Offset(150, 30);
        _items[2].offset = const Offset(270, 30);
        _items[3].offset = const Offset(30, 200);
        _items[4].offset = const Offset(230, 200);
        _items[5].offset = const Offset(80, 370);
        _items[6].offset = const Offset(280, 370);
        break;
      case 8:
        // 2+2+2+2
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

    // zIndex
    for (int i = 0; i < n; i++) {
      _items[i].zIndex = i;
    }
    _maxZIndex = n;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._items]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // Расчёт зоны для иконки удаления
    final screenSize = MediaQuery.of(context).size;
    const iconSize = 64.0;
    final iconLeft = (screenSize.width - iconSize) / 2;
    // Допустим, на ~80 px от низа канваса (потом снизу под ним меню)
    final iconTop = screenSize.height - 80 - iconSize - 80; 
    // "80" — высота меню, ещё 80 — отступ. Подстройте по вкусу.

    _deleteRect = Rect.fromLTWH(iconLeft, iconTop, iconSize, iconSize);

    return Scaffold(
      appBar: AppBar(title: Text('Collage (${widget.photos.length} photos)')),
      body: Column(
        children: [
          // Канвас
          Expanded(
            child: Stack(
              children: [
                // Фон
                Container(color: Colors.black),

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

          // Меню (высота 80)
          Container(
            height: 80,
            color: Colors.black54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Generate
                IconButton(
                  icon: const Icon(Icons.done, color: Colors.white),
                  onPressed: _onGenerateCollage,
                ),
                // Close
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

  Widget _buildPhotoItem(CollagePhotoState item) {
    final fullPath = PhotoPathHelper().getFullPath(item.photo.fileName);

    return Positioned(
      left: item.offset.dx,
      top: item.offset.dy,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _maxZIndex++;
            item.zIndex = _maxZIndex;
          });
        },
        onScaleStart: (details) {
          item.baseScaleOnGesture = item.scale;
          _draggingIndex = _items.indexOf(item);
        },
        onScaleUpdate: (details) {
          setState(() {
            // Двигаем
            item.offset += details.focalPointDelta;

            // Плавный зум
            if (item.baseScaleOnGesture != null) {
              final newScale = item.baseScaleOnGesture! * details.scale;
              item.scale = newScale.clamp(0.5, 3.0);
            }

            // Проверяем Delete icon
            final pointer = details.focalPoint;
            final wasHover = _deleteHover;
            _deleteHover = _deleteRect.contains(pointer);

            // Если только что вошли в DeleteRect => vibrate(1)
            if (_deleteHover && !wasHover) {
              vibrate(5);
            }

            // Если хотите ограничить уход за экран, можно клампить offset
            // item.offset = Offset(
            //   item.offset.dx.clamp(0, screenWidth - 50),
            //   item.offset.dy.clamp(0, screenHeight - 50),
            // );
          });
        },
        onScaleEnd: (details) {
          if (_deleteHover && _draggingIndex != null) {
            _items.removeAt(_draggingIndex!);
          }
          setState(() {
            _draggingIndex = null;
            _deleteHover = false;
          });
        },
        child: Transform.scale(
          scale: item.scale,
          alignment: Alignment.topLeft,
          child: Image.file(
            File(fullPath),
            width: 150,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  // Генерация (склейка) коллажа
  Future<void> _onGenerateCollage() async {
    try {
      final boundary = _collageKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("No boundary found for collageKey");
      }

      final ui.Image fullImage = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await fullImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Failed to convert finalImage");
      final pngBytes = byteData.buffer.asUint8List();

      // Сохраняем
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      final fileName = 'collage_${DateTime.now().millisecondsSinceEpoch}.png';
      final outPath = p.join(photosDir.path, fileName);
      await File(outPath).writeAsBytes(pngBytes);

      // Добавляем в базу
      final newPhoto = Photo(
        id: const Uuid().v4(),
        path: outPath,
        fileName: fileName,
        folderIds: [],
        tagIds: [],
        comment: '',
        dateAdded: DateTime.now(),
        sortOrder: 0,
        isStoredInApp: true,
        geoLocation: null,
        mediaType: 'image',
      );

      final repo = RepositoryProvider.of<PhotoRepositoryImpl>(context);
      await repo.addPhoto(newPhoto);
      context.read<PhotoBloc>().add(LoadPhotos());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collage saved successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating collage: $e')),
      );
    }
  }
}
