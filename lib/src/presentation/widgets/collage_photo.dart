import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/domain/entities/collage.dart';
import 'package:photographers_reference_app/src/presentation/bloc/collage_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/collage_preview_helper.dart';
import 'package:photographers_reference_app/src/presentation/helpers/get_media_type.dart';
import 'package:photographers_reference_app/src/presentation/helpers/photo_save_helper.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_picker_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_controls_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_surface_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_view.dart';
import 'package:photographers_reference_app/src/utils/edit_build_crop_handlers.dart';
import 'package:photographers_reference_app/src/utils/edit_combined_color_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/helpers/collage_save_helper.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:video_player/video_player.dart';

/// Состояние одного фото (drag + zoom + zIndex + edit + brightness + saturation + rotation).
class CollagePhotoState {
  final String id;

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
    required this.id,
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
  final Collage? initialCollage; // <-- добавили

  const PhotoCollageWidget({
    Key? key,
    required this.photos,
    required this.allPhotos,
    this.initialCollage, // <-- добавили
  }) : super(key: key);

  @override
  State<PhotoCollageWidget> createState() => _PhotoCollageWidgetState();
}

class _PhotoCollageWidgetState extends State<PhotoCollageWidget> {
  final GlobalKey _collageKey = GlobalKey(); // для RepaintBoundary
  final GlobalKey _deleteIconKey = GlobalKey(); // для иконки удаления
  FocusNode _focusNode = FocusNode(); // Фокус на виджете
  int? _activeItemIndex;
  double _collageScale = 1.0;
  late List<CollagePhotoState> _items = [];
  int _maxZIndex = 0;
  int? _draggingIndex;
  bool _deleteHover = false;
  Rect _deleteRect = Rect.zero;

  Color _backgroundColor = Colors.black;
  bool _isFullscreen = false;

  bool _overviewMode = false;
  late List<Offset> _originalOffsets = [];
  late List<double> _originalScales = [];

  // по item.id храним состояние слайдеров/позиции/громкости/скорости
  final Map<String, _VideoUi> _videoStates = {};

  // когда курсор над панелью контролов конкретного item — отключаем жесты перетаскивания
  final Map<String, bool> _controlsHover = {};

  // когда мышь над самим видео (не над контролами)
  final Map<String, bool> _videoHover = {};

  /// Туториал
  bool _showTutorial = false; // Проверим SharedPreferences

  /// Нужно при первом построении
  bool showForInit = true;
  Offset _collageOffset = Offset.zero; // Опционально
  /// Индикатор, что мы уже делали один раз auto-fit
  bool _hasAutoFitted = false;

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

  void _bringToFront(CollagePhotoState item) {
    if (_overviewMode) return;
    setState(() {
      // НЕ трогаем isEditing здесь
      _maxZIndex++;
      item.zIndex = _maxZIndex;
      _activeItemIndex = _items.indexOf(item);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Если массив items уже не пуст (значит, мы уже инициализировали), пропускаем
    if (_items.isEmpty) {
      if (widget.initialCollage != null) {
        _initCollageFromExisting(widget.initialCollage!);
      } else {
        _initCollageItems();
      }
    }

    if (!_hasAutoFitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCollageScale();
        _hasAutoFitted = true;
      });
    }
  }

  Future<void> _loadCollageScale() async {
    final prefs = await SharedPreferences.getInstance();
    final scale = prefs.getDouble('collage_scale');
    if (scale != null) {
      setState(() {
        _collageScale = scale;
        _hasAutoFitted = true; // чтобы не сбросилось autoFit-ом
      });
    }
  }

  Future<void> _saveCollageScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('collage_scale', scale);
  }

  void _initCollageFromExisting(Collage collage) {
    // 1) Присваиваем цвет фона
    _backgroundColor = Color(collage.backgroundColorValue);

    // 2) Превращаем каждый CollageItem в CollagePhotoState
    _items = collage.items.map((collageItem) {
      // Найдём объект Photo из allPhotos по fileName:
      // (либо, если нет, создадим Photo-заглушку)
      final photo = widget.allPhotos.firstWhere(
        (p) => p.fileName == collageItem.fileName,
        orElse: () => Photo(
            folderIds: [],
            comment: '',
            tagIds: [],
            path: '',
            id: 'dummy',
            fileName: collageItem.fileName,
            mediaType: 'image', // или что нужно
            dateAdded: DateTime.now(),
            sortOrder: 0),
      );

      return CollagePhotoState(
        id: const Uuid().v4(),
        photo: photo,
        offset: Offset(collageItem.offsetX, collageItem.offsetY),
        scale: collageItem.scale,
        rotation: collageItem.rotation,
        zIndex: collageItem.zIndex,
        baseWidth: collageItem.baseWidth,
        baseHeight: collageItem.baseHeight,
        brightness: collageItem.brightness,
        saturation: collageItem.saturation,
        temp: collageItem.temp,
        hue: collageItem.hue,
        cropRect: Rect.fromLTRB(
          collageItem.cropRectLeft,
          collageItem.cropRectTop,
          collageItem.cropRectRight,
          collageItem.cropRectBottom,
        ),
      )..internalOffset = Offset(
          collageItem.internalOffsetX,
          collageItem.internalOffsetY,
        );
    }).toList();

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final src = collage.items[i];

      if (item.photo.mediaType == 'video') {
        _videoStates[item.id] = _VideoUi(
          startFrac: (src.videoStartFrac ?? 0.0).clamp(0.0, 1.0),
          endFrac: (src.videoEndFrac ?? 1.0).clamp(0.0, 1.0),
          speed: (src.videoSpeed ?? 1.0).clamp(0.1, 4.0),
          // остальное будет заполнено позже колбэками VideoSurface:
          posFrac: 0.0,
          volume: 0.0,
          duration: Duration.zero,
        );
      }
    }

    // Опционально, сортируем по zIndex или инициализируем _maxZIndex
    _maxZIndex =
        _items.isEmpty ? 0 : _items.map((e) => e.zIndex).reduce(math.max);

    setState(() {});
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

    if (_items.length == 1) {
      final singleItem = _items.first;
      final canvasWidth = MediaQuery.of(context).size.width;
      final canvasHeight = MediaQuery.of(context).size.height;

      final photoAspectRatio = singleItem.baseWidth / singleItem.baseHeight;
      final screenAspectRatio = canvasWidth / canvasHeight;

      double scale;
      if (photoAspectRatio > screenAspectRatio) {
        scale = canvasWidth / singleItem.baseWidth; // Подгоняем по ширине
      } else {
        scale = canvasHeight / singleItem.baseHeight; // Подгоняем по высоте
      }

      final newWidth = singleItem.baseWidth * scale;
      final newHeight = singleItem.baseHeight * scale;

      singleItem.offset = Offset(
        (canvasWidth - newWidth) / 2, // Центрируем по X
        (canvasHeight - newHeight) / 2, // Центрируем по Y
      );
      singleItem.scale = scale;

      _activeItemIndex = 0; // Делаем фото активным
    } else {
      // твой каскад/раскладка
      const cascadeOffset = 50.0;
      for (int i = 0; i < n; i++) {
        final item = _items[i];
        item.offset = Offset(
          (i * cascadeOffset) % (canvasWidth - item.baseWidth),
          (i * cascadeOffset) % (canvasHeight - item.baseHeight),
        );
      }
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
      id: const Uuid().v4(),
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

      // Готовим размеры новой фотки
      final fullPath = PhotoPathHelper().getFullPath(newPhoto.fileName);
      final file = File(fullPath);

      // Исходные «естественные» размеры фото
      double naturalWidth = 150;
      double naturalHeight = 150;
      if (file.existsSync()) {
        final decoded = img.decodeImage(file.readAsBytesSync());
        if (decoded != null && decoded.width > 0) {
          naturalHeight = decoded.height * (naturalWidth / decoded.width);
        }
      }

      // Сбрасываем внутр. offset и crop
      item.internalOffset = Offset.zero;
      item.cropRect = const Rect.fromLTWH(0, 0, 1, 1);

      // Подменяем саму photo
      item.photo = newPhoto;

      // Если в коллаже всего одно фото
      if (_items.length == 1) {
        // Вписываем фото во весь экран:
        final canvasWidth = MediaQuery.of(context).size.width;
        final canvasHeight = MediaQuery.of(context).size.height;

        final photoAspect = naturalWidth / naturalHeight;
        final screenAspect = canvasWidth / canvasHeight;

        double scale;
        if (photoAspect > screenAspect) {
          scale = canvasWidth / naturalWidth; // Подгоняем по ширине экрана
        } else {
          scale = canvasHeight / naturalHeight; // Подгоняем по высоте экрана
        }

        // Ставим baseWidth/baseHeight с учётом того, что scale будет 1.0
        item.baseWidth = naturalWidth * scale;
        item.baseHeight = naturalHeight * scale;

        // Центрируем
        item.offset = Offset(
          (canvasWidth - item.baseWidth) / 2,
          (canvasHeight - item.baseHeight) / 2,
        );

        item.scale = 1.0;
      } else {
        // В коллаже несколько фото —
        // 1) Сохраняем прежний offset (не двигаем контейнер!)
        final oldOffset = item.offset;

        // 2) Сохраняем прежнюю высоту (контейнер)
        final oldHeight = item.baseHeight;
        // 3) Новая ширина по соотношению сторон
        //    (фото должно «занять» всю высоту контейнера)
        final newAspect = naturalWidth / naturalHeight;
        final newWidth = oldHeight * newAspect;

        // Обновляем baseWidth/baseHeight
        item.baseWidth = newWidth;
        item.baseHeight = oldHeight;

        // Возвращаем offset на место
        item.offset = oldOffset;

        // Сбрасываем scale (равно 1.0, т.к. размеры уже «учтены»)
        item.scale = 1.0;
      }
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
        id: const Uuid().v4(),
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
      child: DropTarget(
        // 1) Когда файл(ы) «перетащили и бросили»
        onDragDone: (DropDoneDetails details) async {
          for (final xfile in details.files) {
            final file = File(xfile.path); // Превращаем XFile в File
            final bytes = await file.readAsBytes(); // Читаем как Uint8List
            final fileName = p.basename(file.path); // Извлекаем имя файла
            final mediaType = getMediaType(file.path);

            // Сохраняем фото через PhotoSaveHelper
            final newPhoto = await PhotoSaveHelper.savePhoto(
              fileName: fileName,
              bytes: bytes,
              context: context,
              mediaType: mediaType,
            );

            // Добавляем фото в коллаж
            setState(() {
              _addPhotoToCollage(newPhoto);
            });
          }
        },

        // 2) Опционально: когда курсор «влетел» в DropTarget
        onDragEntered: (details) {
          // Можно включить «подсветку» области
          // setState(() => _dragOver = true);
        },

        // 3) Когда курсор «улетел»
        onDragExited: (details) {
          // setState(() => _dragOver = false);
        },

        // 4) UI-контейнер, внутри которого ваша логика
        child: Scaffold(
          appBar: !_isFullscreen
              ? AppBar(
                  title: Text('${widget.initialCollage?.title} (${_items.length} images)'),
                  actions: [
                    IconButton(
                      tooltip: 'Help / Info',
                      icon: const Icon(Icons.info_outline),
                      onPressed: _showHelp,
                    ),
                    IconButton(
                      tooltip: 'Toggle Fullscreen',
                      icon: const Icon(Icons.fullscreen_exit,
                          color: Colors.white),
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
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() {
                          for (final it in _items) {
                            it.isEditing = false;
                          }
                        });
                      },
                      child: Stack(
                        children: [
                          // Цвет фона холста
                          Container(color: _backgroundColor),

                          InteractiveViewer(
                            boundaryMargin: const EdgeInsets.all(999999),
                            // теперь глобальный зум отключен
                            scaleEnabled: false,
                            panEnabled: false,
                            clipBehavior: Clip.none,
                            child: Transform.scale(
                              scale: _collageScale,
                              alignment: Alignment.topLeft,
                              child: RepaintBoundary(
                                key: _collageKey,
                                child: SizedBox(
                                  width: 5000,
                                  height: 5000,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.blue.withOpacity(
                                                  0.6), // например, синий
                                              width: 3,
                                            ),
                                            color: Colors.transparent,
                                          ),
                                        ),
                                      ),
                                      for (final item in sorted)
                                        _buildPhotoItem(item),
                                    ],
                                  ),
                                ),
                              ),
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
                                    color: _deleteHover
                                        ? Colors.red
                                        : Colors.white30,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.delete,
                                      color: Colors.black),
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
                                            setState(
                                                () => _showTutorial = false);
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
                  ),

                  // Нижняя панель

                  Container(
                      height: isSomePhotoInEditMode ? 120 : 40,
                      color: _isFullscreen
                          ? const ui.Color.fromARGB(0, 0, 0, 0)
                          : const ui.Color.fromARGB(60, 0, 0, 0),
                      child: isSomePhotoInEditMode
                          ? _buildEditPanel(editingPhoto)
                          : _buildDefaultPanel()),
                ],
              ),

              // Кнопка выхода из фуллскрина
              if (_isFullscreen)
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon:
                        const Icon(Icons.fullscreen_exit, color: Colors.white),
                    onPressed: _toggleFullscreen,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }

  void _onSaveCollageToDb() async {
  final now = DateTime.now();
  final formattedDate =
        "My_collage_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

  final TextEditingController titleController =
      TextEditingController(text: formattedDate);

  final itemsList = _items.map((it) {
    final ui = _videoStates[it.id];
    final isVideo = it.photo.mediaType == 'video';
    return CollageItem(
      fileName: it.photo.fileName,
      offsetX: it.offset.dx,
      offsetY: it.offset.dy,
      scale: it.scale,
      rotation: it.rotation,
      baseWidth: it.baseWidth,
      baseHeight: it.baseHeight,
      internalOffsetX: it.internalOffset.dx,
      internalOffsetY: it.internalOffset.dy,
      brightness: it.brightness,
      saturation: it.saturation,
      temp: it.temp,
      hue: it.hue,
      cropRectLeft: it.cropRect.left,
      cropRectTop: it.cropRect.top,
      cropRectRight: it.cropRect.right,
      cropRectBottom: it.cropRect.bottom,
      zIndex: it.zIndex,
      videoStartFrac: isVideo ? (ui?.startFrac ?? 0.0) : null,
      videoEndFrac: isVideo ? (ui?.endFrac ?? 1.0) : null,
      videoSpeed: isVideo ? (ui?.speed ?? 1.0) : null,
    );
  }).toList();

  if (widget.initialCollage == null) {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Collage'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Collage Title'),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(ctx).pop(); // Returns null
            },
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () {
              Navigator.of(ctx).pop(titleController.text); // Returns the text
            },
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;

    final collageId = const Uuid().v4();

    // 1) Сначала рендерим превью (перезаписывать нечего — создаём)
    String previewPath = '';
    try {
      previewPath = await CollagePreviewHelper.renderPreviewPng(
        boundaryKey: _collageKey,
        collageId: collageId,
        pixelRatio: 1.25,
      );
    } catch (_) {
      // превью — не критично, можно проглотить и оставить пустым
    }

    // 2) Собираем и сохраняем в БД
    final newCollage = Collage(
      id: collageId,
      title: result.trim(),
      backgroundColorValue: _backgroundColor.value,
      items: itemsList,
      dateCreated: now,
      dateUpdated: now,
      previewPath: previewPath.isEmpty ? null : previewPath,
    );
    context.read<CollageBloc>().add(AddCollage(newCollage));
  } else {
    final existing = widget.initialCollage!;
    // 1) Перерисовываем превью для того же id — файл перезапишется
    String previewPath = existing.previewPath ?? '';
    try {
      previewPath = await CollagePreviewHelper.renderPreviewPng(
        boundaryKey: _collageKey,
        collageId: existing.id,
        pixelRatio: 1.25,
      );
    } catch (_) {
      // не фейлим сохранение коллажа из-за проблем превью
    }

    // 2) Обновляем запись
    final updatedCollage = Collage(
      id: existing.id,
      title: existing.title,
      backgroundColorValue: _backgroundColor.value,
      items: itemsList,
      dateCreated: existing.dateCreated,
      dateUpdated: now,
      previewPath: previewPath.isEmpty ? existing.previewPath : previewPath,
    );
    context.read<CollageBloc>().add(UpdateCollage(updatedCollage));
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Collage saved to DB!')),
  );
}

  /// Панель, когда не редактируется конкретное фото
  Widget _buildDefaultPanel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (Platform.isMacOS)
          Expanded(
              child: Row(
            children: [
              SizedBox(
                width: 120, // фиксированная ширина
                child: Slider(
                  min: 0.1,
                  max: 2.0,
                  value: _collageScale,
                  onChanged: (val) {
                    setState(() {
                      _collageScale = val;
                    });
                    _saveCollageScale(val);
                  },
                ),
              ),
            ],
          )),
        IconButton(
          icon: const Icon(Iconsax.add, color: Colors.white),
          tooltip: 'Add photo',
          onPressed: _showAllPhotosSheet,
        ),
        IconButton(
          icon: Icon(Icons.grid_view, color: Colors.white),
          tooltip: 'Overview mode',
          onPressed: _toggleOverviewMode,
        ),

        IconButton(
          icon: const Icon(Iconsax.colorfilter, color: Colors.white),
          tooltip: 'Change background color',
          onPressed: _showColorPickerDialog,
        ),
        // --- НОВАЯ КНОПКА ДЛЯ СОХРАНЕНИЯ В БАЗУ ---
        IconButton(
          icon: const Icon(Iconsax.save_2, color: Colors.white),
          tooltip: 'Save collage',
          onPressed: _onSaveCollageToDb,
        ),
        IconButton(
          icon: const Icon(Iconsax.image, color: Colors.green),
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

  void _toggleOverviewMode() {
    setState(() {
      _overviewMode = !_overviewMode;

      if (_overviewMode) {
        _enterOverviewLayout();
      } else {
        _exitOverviewLayout(); // если хочешь возврат из кнопки
      }
    });
  }

  void _enterOverviewLayout() {
    _originalOffsets = _items.map((e) => e.offset).toList();
    _originalScales = _items.map((e) => e.scale).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    const spacing = 20.0;
    const itemTargetWidth = 200.0;

    // Автоматически подбираем количество колонок
    final columns = (screenWidth / (itemTargetWidth + spacing))
            .floor()
            .clamp(1, _items.length) -
        1;
    final actualItemWidth = (screenWidth - (columns + 1) * spacing) / columns;

    for (int i = 0; i < _items.length; i++) {
      final row = i ~/ columns;
      final col = i % columns;

      final x = spacing + col * (actualItemWidth + spacing);
      final y = spacing + row * (actualItemWidth + spacing);

      final item = _items[i];
      final scale = actualItemWidth / item.baseWidth;

      item.offset = Offset(x, y);
      item.scale = scale;
    }
  }

  void _exitOverviewLayout({int? bringToFrontIndex}) {
    for (int i = 0; i < _items.length; i++) {
      _items[i].offset = _originalOffsets[i];
      _items[i].scale = _originalScales[i];
    }

    if (bringToFrontIndex != null) {
      _maxZIndex++;
      _items[bringToFrontIndex].zIndex = _maxZIndex;
    }

    setState(() {
      _overviewMode = false;
    });
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
              max: 4.0,
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
        key: ValueKey(item.id),
        left: item.offset.dx,
        top: item.offset.dy,
        child: Listener(
          behavior: HitTestBehavior.translucent, // важно!
          onPointerDown: (_) {
            _bringToFront(item); // сработает и по видео, и по контролам
          },
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
              if (_overviewMode) {
                final tappedIndex = _items.indexOf(item);
                _exitOverviewLayout(bringToFrontIndex: tappedIndex);
              } else {
                setState(() {
                  for (final it in _items) {
                    it.isEditing = false;
                  }
                  _maxZIndex++;
                  item.zIndex = _maxZIndex;
                  _activeItemIndex = _items.indexOf(item);
                });
              }
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

  /// Собираем контент (учитываем cropRect + полный colorFilter)
  Widget _buildEditableContent(
    CollagePhotoState item,
    double effectiveWidth,
    double effectiveHeight,
  ) {
    final cropLeft = item.cropRect.left * effectiveWidth;
    final cropTop = item.cropRect.top * effectiveHeight;

    final filter = combinedColorFilter(
      item.brightness,
      item.saturation,
      item.temp,
      item.hue,
    );

    final fullPath = PhotoPathHelper().getFullPath(item.photo.fileName);
    final isVideo = item.photo.mediaType == 'video';

    // доступ к состоянию этого элемента
    final uiState = _videoStates[item.id] ??= _VideoUi();

    // helpers
    Duration _fracToTime(Duration total, double f) {
      if (total == Duration.zero) return Duration.zero;
      final ms = (total.inMilliseconds * f.clamp(0.0, 1.0)).round();
      return Duration(milliseconds: ms);
    }

    double _timeToFrac(Duration total, Duration t) {
      if (total == Duration.zero) return 0.0;
      return (t.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // КРОПИМ ТОЛЬКО КОНТЕНТ
        ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: item.cropRect.width,
            heightFactor: item.cropRect.height,
            child: Transform.translate(
              offset: Offset(-cropLeft, -cropTop) + item.internalOffset,
              child: ColorFiltered(
                colorFilter: filter,
                child: SizedBox(
                  width: effectiveWidth,
                  height: effectiveHeight,
                  child: isVideo
                      ? MouseRegion(
                          onEnter: (_) =>
                              setState(() => _videoHover[item.id] = true),
                          onExit: (_) =>
                              setState(() => _videoHover[item.id] = false),
                          child: VideoSurface(
                            key: ValueKey(
                              'vs-${item.id}-'
                              '${uiState.duration.inMilliseconds}-'
                              '${uiState.startFrac.toStringAsFixed(3)}-'
                              '${uiState.endFrac.toStringAsFixed(3)}-'
                              '${uiState.speed.toStringAsFixed(2)}',
                            ),
                            filePath: fullPath,
                            startTime: _fracToTime(
                                uiState.duration, uiState.startFrac),
                            endTime: uiState.duration == Duration.zero
                                ? null
                                : _fracToTime(
                                    uiState.duration, uiState.endFrac),
                            volume: uiState.volume,
                            speed: uiState.speed,

                            // ВАЖНО: не стартуем, пока не знаем duration
                            autoplay: uiState.duration != Duration.zero,

                            onDuration: (d) => setState(() {
                              uiState.duration = d;
                              // setState приведёт к ребилду, key поменяется из-за duration,
                              // и VideoSurface пересоздастся с корректным startTime и autoplay=true
                            }),
                            onPosition: (p) => setState(() {
                              uiState.posFrac =
                                  _timeToFrac(uiState.duration, p);
                            }),
                          ),
                        )
                      : Image.file(
                          File(fullPath),
                          width: effectiveWidth,
                          height: effectiveHeight,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
          ),
        ),

        // КОНТРОЛЫ — поверх, НЕ кропятся
        if (isVideo)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MouseRegion(
              onEnter: (_) => setState(() => _controlsHover[item.id] = true),
              onExit: (_) => setState(() => _controlsHover[item.id] = false),
              child: Builder(builder: (context) {
                final visible = (_videoHover[item.id] == true) ||
                    (_controlsHover[item.id] == true) ||
                    item.isEditing;

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: visible ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !visible, // когда скрыто — не ловим события
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black45, Colors.transparent],
                          ),
                        ),
                        child: VideoControls(
                          startFrac: uiState.startFrac,
                          endFrac: uiState.endFrac,
                          positionFrac: uiState.posFrac,
                          volume: uiState.volume,
                          speed: uiState.speed,
                          onSeekFrac: (f) => setState(() {
                            uiState.startFrac =
                                f.clamp(0.0, uiState.endFrac - 0.001);
                          }),
                          onChangeRange: (rv) => setState(() {
                            uiState.startFrac = rv.start;
                            uiState.endFrac = rv.end;
                          }),
                          onChangeVolume: (v) => setState(() {
                            uiState.volume = v;
                          }),
                          onChangeSpeed: (s) => setState(() {
                            uiState.speed = s;
                          }),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

        // Рамка и хэндлы кропа (как было)
        if (item.isEditing) ...[
          Positioned.fill(child: CustomPaint(painter: _CropBorderPainter())),
          ...buildCropHandles(
            item,
            effectiveWidth,
            effectiveHeight,
            (Rect newRect) => setState(() => item.cropRect = newRect),
          ),
        ],
      ],
    );
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black, // фон внутри
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: PhotoPickerWidget(
              onPhotoSelected: (photo) {
                Navigator.pop(context); // закрываем bottom-sheet
                _addPhotoToCollage(photo); // одиночное добавление
              },
              onMultiSelectDone: (List<Photo> list) {
                Navigator.pop(context); // закрываем bottom-sheet один раз
                for (final photo in list) {
                  _addPhotoToCollage(photo); // добавляем по одному
                }
              },
            ),
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

class _VideoUiStateCache extends InheritedWidget {
  double? startFrac, endFrac, posFrac, volume, speed;
  Duration? duration;

  _VideoUiStateCache({
    super.key,
    required super.child,
    this.startFrac,
    this.endFrac,
    this.posFrac,
    this.volume,
    this.speed,
    this.duration,
  }) : super();

  static _VideoUiStateCache? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_VideoUiStateCache>();

  static _VideoUiStateCache init(BuildContext context) {
    final widget = _VideoUiStateCache(
      child: const SizedBox.shrink(),
      startFrac: 0.0,
      endFrac: 1.0,
      posFrac: 0.0,
      volume: 0.0,
      speed: 1.0,
      duration: Duration.zero,
    );
    // В реальном коде лучше держать состояние у родителя этого блока.
    return widget;
  }

  @override
  bool updateShouldNotify(covariant _VideoUiStateCache oldWidget) => true;
}

class _VideoUi {
  double startFrac, endFrac, posFrac, volume, speed;
  Duration duration;
  _VideoUi({
    this.startFrac = 0.0,
    this.endFrac = 1.0,
    this.posFrac = 0.0,
    this.volume = 0.0,
    this.speed = 1.0,
    this.duration = Duration.zero,
  });
}
