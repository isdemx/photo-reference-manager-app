import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/helpers/collage_save_helper.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

/// Состояние одного фото (drag + zoom + zIndex + edit + brightness + saturation + rotation).
class CollagePhotoState {
  final Photo photo;

  /// Позиция (drag)
  Offset offset;

  /// Масштаб (zoom)
  double scale;

  /// Угол поворота (радианы)
  double rotation;

  /// Слои наложения (чем больше, тем выше)
  int zIndex;

  /// Начальный масштаб при onScaleStart (плавный зум)
  double? baseScaleOnGesture;

  /// Начальный угол при onScaleStart
  double? baseRotationOnGesture;

  /// "Базовые" размеры (без учёта scale)
  double baseWidth;
  double baseHeight;

  /// Режим редактирования
  bool isEditing;

  /// Область обрезки [0..1] (left, top, right, bottom)
  Rect cropRect;

  /// Яркость (0..2), по умолчанию 1
  double brightness;

  /// Насыщенность (0..2), по умолчанию 1
  double saturation;

  CollagePhotoState({
    required this.photo,
    required this.offset,
    required this.scale,
    required this.rotation,
    required this.zIndex,
    required this.baseWidth,
    required this.baseHeight,
    this.isEditing = false,
    Rect? cropRect,
    this.brightness = 1.0,
    this.saturation = 1.0,
  }) : cropRect = cropRect ?? const Rect.fromLTWH(0, 0, 1, 1);
}

class PhotoCollageWidget extends StatefulWidget {
  final List<Photo> photos; // Уже выбранные фото
  final List<Photo> allPhotos; // Все доступные фото

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
  final GlobalKey _deleteIconKey = GlobalKey(); // для иконки удаления

  late List<CollagePhotoState> _items;
  int _maxZIndex = 0;
  int? _draggingIndex;
  bool _deleteHover = false;
  Rect _deleteRect = Rect.zero;

  Color _backgroundColor = Colors.black;

  /// Туториал
  bool _showTutorial = false; // Проверим SharedPreferences

  /// Нужно при первом построении
  bool showForInit = true;

  @override
  void initState() {
    super.initState();
    _initCollageItems();
    _checkTutorial(); // Проверяем, нужно ли показывать подсказку
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateDeleteRect());
  }

  /// Читаем SharedPreferences, нужно ли показывать tutorial
  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final passed = prefs.getBool('collage_tutor_passed') ?? false;
    if (!passed) {
      setState(() => _showTutorial = true);
    }
  }

  /// Записываем, что тутор показан
  Future<void> _markTutorialPassed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('collage_tutor_passed', true);
  }

  void _initCollageItems() {
    _items = widget.photos.map(_createCollagePhotoState).toList();

    // Пример раскладки для 2..3 фото
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
      default:
        break;
    }
    for (int i = 0; i < _items.length; i++) {
      _items[i].zIndex = i;
    }
    _maxZIndex = _items.length;
  }

  CollagePhotoState _createCollagePhotoState(Photo photo) {
    const double initialWidth = 150;
    double baseW = initialWidth;
    double baseH = initialWidth;
    final fullPath = PhotoPathHelper().getFullPath(photo.fileName);
    final file = File(fullPath);
    if (file.existsSync()) {
      final decoded = img.decodeImage(file.readAsBytesSync());
      if (decoded != null && decoded.width > 0) {
        baseH = decoded.height * (baseW / decoded.width);
      }
    }
    return CollagePhotoState(
      photo: photo,
      offset: Offset.zero,
      scale: 1.0,
      rotation: 0.0,
      zIndex: 0,
      baseWidth: baseW,
      baseHeight: baseH,
      isEditing: false,
      cropRect: const Rect.fromLTWH(0, 0, 1, 1),
      brightness: 1.0,
      saturation: 1.0,
    );
  }

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
    setState(() {
      showForInit = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Сортируем по zIndex
    final sorted = [..._items]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // Пытаемся найти, есть ли одна фотка в режиме редактирования
    final editingPhoto = sorted.firstWhere(
      (it) => it.isEditing,
      orElse: () => CollagePhotoState(
        photo: widget.photos.first,
        offset: Offset.zero,
        scale: 1.0,
        rotation: 0.0,
        zIndex: 0,
        baseWidth: 1,
        baseHeight: 1,
      ),
    );
    final isSomePhotoInEditMode = sorted.any((it) => it.isEditing);

    return Scaffold(
      appBar: AppBar(
        title: Text('Free collage (${_items.length} images)'),
        actions: [
          IconButton(
            tooltip: 'Help / Info',
            icon: const Icon(Icons.info_outline),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: Column(
        children: [
          // === Основной Canvas ===
          Expanded(
            child: Stack(
              children: [
                Container(color: _backgroundColor),

                // RepaintBoundary для сохранения
                RepaintBoundary(
                  key: _collageKey,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(color: _backgroundColor),
                      ),
                      for (final item in sorted) _buildPhotoItem(item),
                    ],
                  ),
                ),

                // Иконка удаления
                if (!isSomePhotoInEditMode &&
                    (showForInit || _draggingIndex != null))
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 50,
                    child: Center(
                      child: Container(
                        key: _deleteIconKey,
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

                // Туториал поверх всего
                if (_showTutorial)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.8),
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.touch_app,
                                  size: 60, color: Colors.white),
                              const SizedBox(height: 20),
                              const Text(
                                'Move with one finger\n'
                                'Zoom with two fingers\n'
                                'Long Press to toggle Edit Mode\n'
                                'Rotate in bottom panel\n'
                                'Brightness & Saturation in bottom panel\n'
                                'Crop corners when in Edit Mode\n'
                                'Place on top with a tap\n'
                                'Press check to save image',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() => _showTutorial = false);
                                  _markTutorialPassed(); // Запомнить в prefs
                                },
                                child: const Text('Got it'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // === Панель снизу ===
          Container(
            height: isSomePhotoInEditMode ? 160 : 80,
            color: Colors.black54,
            child: isSomePhotoInEditMode
                ? _buildEditPanel(editingPhoto)
                : _buildDefaultPanel(),
          ),
        ],
      ),
    );
  }

  /// Панель, если никто не в edit mode
  Widget _buildDefaultPanel() {
    return Row(
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
          icon: const Icon(Icons.check, color: Colors.white),
          tooltip: 'Save collage as image',
          onPressed: _onGenerateCollage,
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'Cancel collage',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  /// Панель, если какая-то фотка в edit mode (rotate, brightness, saturation, ok)
  Widget _buildEditPanel(CollagePhotoState item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Первая строка — кнопки вращения
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.rotate_left),
              label: const Text('Rotate Left'),
              onPressed: () {
                setState(() {
                  item.rotation -= math.pi / 2; // -90 градусов
                });
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.rotate_right),
              label: const Text('Rotate Right'),
              onPressed: () {
                setState(() {
                  item.rotation += math.pi / 2; // +90 градусов
                });
              },
            ),
          ],
        ),
        // Вторая строка — ползунки яркости и насыщенности
        Row(
          children: [
            const SizedBox(width: 16),
            const Text('Brt', style: TextStyle(color: Colors.grey)),
            Expanded(
              child: Slider(
                min: 0.0,
                max: 2.0,
                divisions: 20,
                value: item.brightness,
                onChanged: (val) {
                  setState(() {
                    item.brightness = val;
                  });
                },
              ),
            ),
            const Text('Sat', style: TextStyle(color: Colors.grey)),
            Expanded(
              child: Slider(
                min: 0.0,
                max: 2.0,
                divisions: 20,
                value: item.saturation,
                onChanged: (val) {
                  setState(() {
                    item.saturation = val;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        // Третья строка — кнопка OK
        ElevatedButton(
          child: const Text('OK'),
          onPressed: () {
            setState(() {
              item.isEditing = false;
            });
          },
        ),
      ],
    );
  }

  /// Построение одного элемента коллажа
  Widget _buildPhotoItem(CollagePhotoState item) {
    final w = item.baseWidth * item.scale;
    final h = item.baseHeight * item.scale;

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
        onLongPress: () {
          // Отключаем edit mode у всех, включаем у текущего
          setState(() {
            vibrate();
            for (final it in _items) {
              it.isEditing = false;
            }
            item.isEditing = true;
          });
        },
        onScaleStart: (details) {
          setState(() {
            item.baseScaleOnGesture = item.scale;
            item.baseRotationOnGesture = item.rotation;
            _draggingIndex = _items.indexOf(item);
          });
        },
        onScaleUpdate: (details) {
          setState(() {
            // Двигаем
            item.offset += details.focalPointDelta;
            // Зум
            if (item.baseScaleOnGesture != null) {
              final newScale = item.baseScaleOnGesture! * details.scale;
              item.scale = newScale.clamp(0.1, 999.0);
            }

            // Проверяем удаление
            final pointer = details.focalPoint;
            final wasHover = _deleteHover;
            _deleteHover = _deleteRect.contains(pointer);
            if (_deleteHover && !wasHover) {
              vibrate(5);
            }
          });
        },
        onScaleEnd: (_) {
          setState(() {
            if (_deleteHover && _draggingIndex != null) {
              _items.removeAt(_draggingIndex!);
            }
            _draggingIndex = null;
            _deleteHover = false;
          });
        },
        child: Transform(
          transform: Matrix4.identity()
            ..translate(w / 2, h / 2)
            ..rotateZ(item.rotation)
            ..translate(-w / 2, -h / 2),
          child: _buildEditableContent(item, w, h),
        ),
      ),
    );
  }

  /// Яркость + насыщенность => итоговая ColorFilter
  /// (в примере линейная матрица для яркости и насыщенности)
  ColorFilter _combinedColorFilter(double brightness, double saturation) {
    // brightnessMatrix
    final b = brightness;
    final brightnessMatrix = [
      b,
      0,
      0,
      0,
      0,
      0,
      b,
      0,
      0,
      0,
      0,
      0,
      b,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];

    // saturationMatrix (упрощённо)
    // 1) Вычислим интенсивность серого: lumR, lumG, lumB
    // 2) Формула для saturation
    final s = saturation;
    const lumR = 0.3086, lumG = 0.6094, lumB = 0.0820;
    final sr = (1 - s) * lumR;
    final sg = (1 - s) * lumG;
    final sb = (1 - s) * lumB;
    final saturationMatrix = [
      sr + s,
      sg,
      sb,
      0,
      0,
      sr,
      sg + s,
      sb,
      0,
      0,
      sr,
      sg,
      sb + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
    // multiply 2 matrices
    final combined = _multiplyColorMatrices(
        brightnessMatrix.map((e) => e.toDouble()).toList(),
        saturationMatrix.map((e) => e.toDouble()).toList());
    return ColorFilter.matrix(combined);
  }

  /// Умножаем две 4x5 матрицы
  List<double> _multiplyColorMatrices(
    List<double> a,
    List<double> b,
  ) {
    // Матрицы A и B, размер 20 (4 строки, 5 столбцов)
    // result = A x B
    final out = List<double>.filled(20, 0.0);

    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        double sum = 0;
        for (int k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        // + компонент смещения
        if (col == 4) {
          sum += a[row * 5 + 4];
        }
        out[row * 5 + col] = sum;
      }
    }
    return out;
  }

  /// Собираем контент (учитываем cropRect + colorFilter)
  Widget _buildEditableContent(
      CollagePhotoState item, double effectiveWidth, double effectiveHeight) {
    final cropLeft = item.cropRect.left * effectiveWidth;
    final cropTop = item.cropRect.top * effectiveHeight;
    final cropWidth = item.cropRect.width * effectiveWidth;
    final cropHeight = item.cropRect.height * effectiveHeight;

    final filter = _combinedColorFilter(item.brightness, item.saturation);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Основное изображение + ClipRect
        ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: item.cropRect.width,
            heightFactor: item.cropRect.height,
            child: Transform.translate(
              offset: Offset(-cropLeft, -cropTop),
              child: ColorFiltered(
                colorFilter: filter,
                child: Image.file(
                  File(PhotoPathHelper().getFullPath(item.photo.fileName)),
                  width: effectiveWidth,
                  height: effectiveHeight,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        // Рамка и уголки, если edit mode
        if (item.isEditing) ...[
          Positioned.fill(
            child: CustomPaint(painter: _CropBorderPainter()),
          ),
          ..._buildCropHandles(item, effectiveWidth, effectiveHeight),
        ],
      ],
    );
  }

  /// Уголки для обрезки
  List<Widget> _buildCropHandles(CollagePhotoState item, double w, double h) {
    final handles = <Widget>[];

    Widget cornerWidget({
      required Alignment alignment,
      required Function(Offset delta) onDrag,
    }) {
      return Positioned.fill(
        child: Align(
          alignment: alignment,
          child: GestureDetector(
            onPanUpdate: (details) => onDrag(details.delta),
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

    void updateCropRect(Offset delta, bool isLeft, bool isTop) {
      setState(() {
        final dxNorm = delta.dx / w;
        final dyNorm = delta.dy / h;

        double left = item.cropRect.left;
        double top = item.cropRect.top;
        double right = item.cropRect.right;
        double bottom = item.cropRect.bottom;

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

        item.cropRect = Rect.fromLTRB(left, top, right, bottom);
      });
    }

    // Top-left
    handles.add(
      cornerWidget(
        alignment: Alignment.topLeft,
        onDrag: (delta) => updateCropRect(delta, true, true),
      ),
    );
    // Top-right
    handles.add(
      cornerWidget(
        alignment: Alignment.topRight,
        onDrag: (delta) => updateCropRect(delta, false, true),
      ),
    );
    // Bottom-left
    handles.add(
      cornerWidget(
        alignment: Alignment.bottomLeft,
        onDrag: (delta) => updateCropRect(delta, true, false),
      ),
    );
    // Bottom-right
    handles.add(
      cornerWidget(
        alignment: Alignment.bottomRight,
        onDrag: (delta) => updateCropRect(delta, false, false),
      ),
    );

    return handles;
  }

  /// Сохранение коллажа
  Future<void> _onGenerateCollage() async {
    // При сохранении сбрасываем edit mode у всех
    for (final it in _items) {
      it.isEditing = false;
    }
    setState(() {});
    await CollageSaveHelper.saveCollage(_collageKey, context);
  }

  /// Меняем цвет фона
  void _showColorPickerDialog() {
    final oldColor = _backgroundColor;
    Color tempColor = _backgroundColor;
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Pick Background Color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: tempColor,
              onColorChanged: (c) {
                tempColor = c;
                setState(() => _backgroundColor = tempColor);
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                setState(() => _backgroundColor = oldColor);
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  /// Добавить фото
  void _showAllPhotosSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final all = widget.allPhotos;
        return Container(
          color: Colors.black,
          padding: const EdgeInsets.all(8),
          child: GridView.builder(
            itemCount: all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, index) {
              final p = all[index];
              final path = PhotoPathHelper().getFullPath(p.fileName);
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _addPhotoToCollage(p);
                },
                child: Image.file(File(path), fit: BoxFit.cover),
              );
            },
          ),
        );
      },
    );
  }

  /// Добавление фото
  void _addPhotoToCollage(Photo photo) {
    setState(() {
      final s = _createCollagePhotoState(photo);
      s.offset = const Offset(50, 50);
      _maxZIndex++;
      s.zIndex = _maxZIndex;
      _items.add(s);
    });
  }

  /// Нажатие на "Help"
  void _showHelp() {
    setState(() {
      _showTutorial = true;
    });
  }
}

/// Простая рамка вокруг области кропа
class _CropBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(r, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
