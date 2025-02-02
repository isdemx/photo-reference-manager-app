import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  Photo photo;

  /// Позиция (drag)
  Offset offset;

  /// Масштаб (zoom)
  double scale;

  /// Угол поворота (радианы)
  double rotation;

  /// Слои наложения (чем больше, тем выше)
  int zIndex;

  /// Новое поле для сдвига фото внутри контейнера
  Offset internalOffset = Offset.zero;

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

  /// Оттенок (угол в радианах, -π/4..π/4), по умолчанию 0
  double hue;

  double temp;

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
    this.temp = 0.0,
    this.hue = 0.0,
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
  FocusNode _focusNode = FocusNode(); // Фокус на виджете
  int? _activeItemIndex;

  late List<CollagePhotoState> _items;
  int _maxZIndex = 0;
  int? _draggingIndex;
  bool _deleteHover = false;
  Rect _deleteRect = Rect.zero;

  Color _backgroundColor = Colors.black;
  bool _isFullscreen = false;

  /// Туториал
  bool _showTutorial = false; // Проверим SharedPreferences

  /// Нужно при первом построении
  bool showForInit = true;

  @override
  void initState() {
    super.initState();
    _checkTutorial(); // Проверяем, нужно ли показывать подсказку
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateDeleteRect());
    _focusNode.requestFocus();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initCollageItems(); // Теперь метод будет вызван после полной инициализации context
  }

  /// Инициализация списка фото для коллажа
  void _initCollageItems() {
    _items = widget.photos
        .where((photo) =>
            photo.mediaType == 'image') // Фильтрация: оставляем только фото
        .map(_createCollagePhotoState)
        .toList();

    final canvasWidth = MediaQuery.of(context).size.width;
    final canvasHeight = MediaQuery.of(context).size.height;
    final n = _items.length;

    // Если больше 6 фото, размещаем каскадом
    const cascadeOffset = 50.0;
    for (int i = 0; i < n; i++) {
      final item = _items[i];
      item.offset = Offset(
        (i * cascadeOffset) % (canvasWidth - item.baseWidth),
        (i * cascadeOffset) % (canvasHeight - item.baseHeight),
      );
    }

    // Устанавливаем zIndex
    for (int i = 0; i < _items.length; i++) {
      _items[i].zIndex = i;
    }
    _maxZIndex = _items.length;

    setState(() {});
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
      temp: 0.0,
      hue: 0.0,
    );
  }

  /// Обновляем прямоугольник иконки удаления
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

  void _switchPhotoInActiveContainer({required bool next}) {
    if (_activeItemIndex == null) return;

    final item = _items[_activeItemIndex!];
    final currentPhoto = item.photo;
    final allIndex =
        widget.allPhotos.indexWhere((p) => p.fileName == currentPhoto.fileName);

    if (allIndex == -1) return;

    int newIndex = next ? allIndex + 1 : allIndex - 1;
    newIndex = newIndex.clamp(0, widget.allPhotos.length - 1);

    setState(() {
      final newPhoto = widget.allPhotos[newIndex];
      final fullPath = PhotoPathHelper().getFullPath(newPhoto.fileName);
      final file = File(fullPath);

      // Вычисляем новые baseWidth/baseHeight как при обычном добавлении
      double newBaseW = 150;
      double newBaseH = 150;
      if (file.existsSync()) {
        final decoded = img.decodeImage(file.readAsBytesSync());
        if (decoded != null && decoded.width > 0) {
          newBaseH = decoded.height * (newBaseW / decoded.width);
        }
      }

      // Сбрасываем масштаб, cropRect, internalOffset
      item.baseWidth = newBaseW;
      item.baseHeight = newBaseH;
      item.scale = 1.0;
      item.internalOffset = Offset.zero;
      item.cropRect = const Rect.fromLTWH(0, 0, 1, 1);

      // И только потом подменяем саму photo
      item.photo = newPhoto;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Сортируем по zIndex (чтобы последний всегда был сверху)
    final sorted = [..._items]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // Пытаемся найти элемент в режиме редактирования (если есть)
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
        brightness: 1.0,
        saturation: 1.0,
        temp: 1.0,
        hue: 0.0,
      ),
    );
    final isSomePhotoInEditMode = sorted.any((it) => it.isEditing);

    return Focus(
      focusNode: _focusNode,
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (Platform.isMacOS) {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _switchPhotoInActiveContainer(next: true);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _switchPhotoInActiveContainer(next: false);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              if (_activeItemIndex != null) {
                final item = _items[_activeItemIndex!];
                if (item.isEditing) {
                  // То же самое, что по нажатию "OK":
                  setState(() {
                    item.isEditing = false;
                  });
                  return KeyEventResult.handled;
                }
              }
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: !_isFullscreen
            ? AppBar(
                title: Text('Free collage (${_items.length} images)'),
                actions: [
                  IconButton(
                    tooltip: 'Help / Info',
                    icon: const Icon(Icons.info_outline),
                    onPressed: _showHelp,
                  ),
                  IconButton(
                    tooltip: 'Toggle Fullscreen',
                    icon:
                        const Icon(Icons.fullscreen_exit, color: Colors.white),
                    onPressed: _toggleFullscreen,
                  ),
                ],
              )
            : null,
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // Цвет фона холста
                      Container(color: _backgroundColor),

                      // RepaintBoundary для сохранения в CollageSaveHelper
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

                      // Иконка удаления (появляется, когда начинаем drag)
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
                                color:
                                    _deleteHover ? Colors.red : Colors.white30,
                                shape: BoxShape.circle,
                              ),
                              child:
                                  const Icon(Icons.delete, color: Colors.black),
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
                                      'Rotate + Brightness + Saturation + Temperature + Hue\n'
                                      'Crop corners when in Edit Mode\n'
                                      'Tap to bring to front\n'
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
                                        _markTutorialPassed();
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

                // Нижняя панель
                Container(
                  height: isSomePhotoInEditMode ? 220 : 80,
                  color: Colors.black54,
                  child: isSomePhotoInEditMode
                      ? _buildEditPanel(editingPhoto)
                      : _isFullscreen
                          ? null
                          : _buildDefaultPanel(),
                ),
              ],
            ),

            // Кнопка выхода из фуллскрина
            if (_isFullscreen)
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                  onPressed: _toggleFullscreen,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }

  /// Панель, когда не редактируется конкретное фото
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
          icon: const Icon(Icons.check, color: Colors.green),
          tooltip: 'Save collage as image',
          onPressed: _onGenerateCollage,
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          tooltip: 'Cancel collage',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  /// Панель при режиме редактирования (brightness, saturation, temp, hue, rotation)
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
                  item.rotation -= math.pi / 2;
                });
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.rotate_right),
              label: const Text('Rotate Right'),
              onPressed: () {
                setState(() {
                  item.rotation += math.pi / 2;
                });
              },
            ),
          ],
        ),
        // Вторая строка — яркость, насыщенность
        Row(
          children: [
            const SizedBox(width: 16),
            _buildSlider(
              label: 'Brt',
              min: 0.0,
              max: 2.0,
              divisions: 20,
              value: item.brightness,
              centerValue: 1.0,
              onChanged: (val) {
                setState(() => item.brightness = val);
              },
            ),
            _buildSlider(
              label: 'Sat',
              min: 0.0,
              max: 2.0,
              divisions: 20,
              value: item.saturation,
              centerValue: 1.0,
              onChanged: (val) {
                setState(() => item.saturation = val);
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        // Третья строка — контраст и hue
        Row(
          children: [
            const SizedBox(width: 16),
            _buildSlider(
              label: 'Tmp',
              min: -5.0,
              max: 5.0,
              divisions: 20,
              value: item.temp,
              centerValue: 0.0,
              onChanged: (val) {
                setState(() => item.temp = val);
              },
            ),
            _buildSlider(
              label: 'Hue',
              min: -math.pi / 4,
              max: math.pi / 4,
              divisions: 20,
              value: item.hue,
              centerValue: 0.0,
              onChanged: (val) {
                setState(() => item.hue = val);
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        // Четвертая строка — кнопка OK
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
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              setState(() {
                // Регулируем масштаб
                final scaleFactor = event.scrollDelta.dy > 0 ? 1.1 : 0.9;
                item.scale = (item.scale * scaleFactor).clamp(0.1, 999.0);
              });
            }
          },
          child: GestureDetector(
            onTap: () {
              setState(() {
                _maxZIndex++;
                item.zIndex = _maxZIndex;
                _activeItemIndex =
                    _items.indexOf(item); // вот тут сохраняем активный
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
                if (item.isEditing) {
                  // Когда фото в режиме редактирования,
                  // двигаем само изображение внутри контейнера:
                  item.internalOffset += details.focalPointDelta;
                  // (При желании можно ограничить internalOffset, чтобы не «уходило» слишком далеко)
                } else {
                  // По-старому двигаем весь контейнер
                  item.offset += details.focalPointDelta;

                  // И масштаб меняем (зум контейнера)
                  if (item.baseScaleOnGesture != null) {
                    final newScale = item.baseScaleOnGesture! * details.scale;
                    item.scale = newScale.clamp(0.1, 999.0);
                  }
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
        ));
  }

  /// Комбинируем яркость + насыщенность + контраст + hue
  ColorFilter _combinedColorFilter(
    double brightness,
    double saturation,
    double temp,
    double hue,
  ) {
    // 1) Матрица яркости (brightness)
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

    // 2) Матрица насыщенности (saturation)
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

    // 3) Матрица контраста (temperature)
    // Если temp в диапазоне [-1..1],
// то при temp>0 картинка теплеет, при temp<0 – холодеет.

    final temperatureMatrix = [
      // R' = R + 2*temp
      1, 0, 0, 0, 2 * temp,
      // G' = G
      0, 1, 0, 0, 0,
      // B' = B - 2*temp
      0, 0, 1, 0, -2 * temp,
      // A' = A
      0, 0, 0, 1, 0,
    ];

    // 4) Матрица оттенка (hue)
    final cosA = math.cos(hue);
    final sinA = math.sin(hue);
    // Пример поворота матрицы для hue
    final hueMatrix = [
      0.213 + cosA * 0.787 - sinA * 0.213,
      0.715 - cosA * 0.715 - sinA * 0.715,
      0.072 - cosA * 0.072 + sinA * 0.928,
      0,
      0,
      0.213 - cosA * 0.213 + sinA * 0.143,
      0.715 + cosA * 0.285 + sinA * 0.140,
      0.072 - cosA * 0.072 - sinA * 0.283,
      0,
      0,
      0.213 - cosA * 0.213 - sinA * 0.787,
      0.715 - cosA * 0.715 + sinA * 0.715,
      0.072 + cosA * 0.928 + sinA * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];

    // Функция умножения матриц 4x5
    List<double> multiply(List<double> m1, List<double> m2) {
      final out = List<double>.filled(20, 0.0);
      for (int row = 0; row < 4; row++) {
        for (int col = 0; col < 5; col++) {
          double sum = 0;
          for (int k = 0; k < 4; k++) {
            sum += m1[row * 5 + k] * m2[k * 5 + col];
          }
          // offset
          if (col == 4) {
            sum += m1[row * 5 + 4];
          }
          out[row * 5 + col] = sum;
        }
      }
      return out;
    }

    // Последовательно умножаем: brightness -> saturation -> temp -> hue
    final m1 = multiply(
      brightnessMatrix.map((e) => e.toDouble()).toList(),
      saturationMatrix.map((e) => e.toDouble()).toList(),
    );
    final m2 = multiply(
      m1.map((e) => e.toDouble()).toList(),
      temperatureMatrix.map((e) => e.toDouble()).toList(),
    );
    final m3 = multiply(
      m2.map((e) => e.toDouble()).toList(),
      hueMatrix.map((e) => e.toDouble()).toList(),
    );

    return ColorFilter.matrix(m3);
  }

  /// Собираем контент (учитываем cropRect + полный colorFilter)
  Widget _buildEditableContent(
      CollagePhotoState item, double effectiveWidth, double effectiveHeight) {
    final cropLeft = item.cropRect.left * effectiveWidth;
    final cropTop = item.cropRect.top * effectiveHeight;
    final cropWidth = item.cropRect.width * effectiveWidth;
    final cropHeight = item.cropRect.height * effectiveHeight;

    final filter = _combinedColorFilter(
      item.brightness,
      item.saturation,
      item.temp,
      item.hue,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Основное изображение + обрезка
        ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: item.cropRect.width,
            heightFactor: item.cropRect.height,
            child: Transform.translate(
              offset: Offset(-cropLeft, -cropTop) + item.internalOffset,
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
        // Рамка и уголки при edit mode
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

    // Четыре угла
    handles.add(
      cornerWidget(
        alignment: Alignment.topLeft,
        onDrag: (delta) => updateCropRect(delta, true, true),
      ),
    );
    handles.add(
      cornerWidget(
        alignment: Alignment.topRight,
        onDrag: (delta) => updateCropRect(delta, false, true),
      ),
    );
    handles.add(
      cornerWidget(
        alignment: Alignment.bottomLeft,
        onDrag: (delta) => updateCropRect(delta, true, false),
      ),
    );
    handles.add(
      cornerWidget(
        alignment: Alignment.bottomRight,
        onDrag: (delta) => updateCropRect(delta, false, false),
      ),
    );

    return handles;
  }

  /// Специальный метод для Slider'а с поддержкой:
  /// - double tap = сброс к centerValue
  /// - «примагничивание» к centerValue при приближении
  /// - лёгкая вибрация при примагничивании
  Widget _buildSlider({
    required String label,
    required double min,
    required double max,
    required int divisions,
    required double value,
    required double centerValue,
    required ValueChanged<double> onChanged,
  }) {
    return Expanded(
      child: GestureDetector(
        onDoubleTap: () {
          // Сброс в центр
          vibrate(3);
          onChanged(centerValue);
        },
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Expanded(
              child: Slider(
                min: min,
                max: max,
                divisions: divisions,
                value: value,
                onChanged: (val) {
                  // Примагничивание к centerValue
                  final threshold = (max - min) * 0.03; // 5% от диапазона
                  final diff = (val - centerValue).abs();
                  if (diff < threshold) {
                    // Считаем «достаточно близко», делаем привязку
                    vibrate(5);
                    onChanged(centerValue);
                  } else {
                    onChanged(val);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
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
        final all = widget.allPhotos
            .where((photo) => photo.mediaType == 'image')
            .toList();
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

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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
