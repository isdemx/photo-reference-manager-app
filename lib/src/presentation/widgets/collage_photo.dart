// photo_collage_refactor_one_file.dart
// Один большой файл. Потом разнесёшь по папкам:
// helpers/*, services/*, controller/*, widget/*

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

// --- твои доменные/проектные импорты ---
import 'package:photographers_reference_app/src/domain/entities/collage.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';

import 'package:photographers_reference_app/src/presentation/bloc/collage_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/collage_preview_helper.dart';
import 'package:photographers_reference_app/src/presentation/helpers/collage_save_helper.dart';
import 'package:photographers_reference_app/src/presentation/helpers/get_media_type.dart';
import 'package:photographers_reference_app/src/presentation/helpers/photo_save_helper.dart';

import 'package:photographers_reference_app/src/presentation/widgets/photo_adjustments_panel.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_picker_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_controls_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_surface_widget.dart';

import 'package:photographers_reference_app/src/services/window_service.dart';
import 'package:photographers_reference_app/src/utils/edit_build_crop_handlers.dart';
import 'package:photographers_reference_app/src/utils/edit_combined_color_filter.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

////////////////////////////////////////////////////////////////
/// SECTION: Models (State)
////////////////////////////////////////////////////////////////

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

  /// Флип по горизонтали
  bool flipX;

  /// Поле для сдвига фото внутри контейнера (когда item.isEditing)
  Offset internalOffset;

  /// Начальный масштаб при onScaleStart (плавный зум)
  double? baseScaleOnGesture;
  Offset? baseOffsetOnGesture;

  /// "Базовые" размеры (без учёта scale)
  double baseWidth;
  double baseHeight;

  /// Режим редактирования
  bool isEditing;

  /// Область обрезки [0..1] (left, top, right, bottom)
  Rect cropRect;

  /// Яркость (0..4), по умолчанию 1
  double brightness;

  /// Насыщенность (0..2), по умолчанию 1
  double saturation;

  /// Оттенок (угол в радианах, -π/4..π/4), по умолчанию 0
  double hue;

  /// Температура (условно -5..5)
  double temp;

  /// Контраст (0..2), по умолчанию 1
  double contrast;

  /// Прозрачность (0..1), по умолчанию 1
  double opacity;

  /// Контекст выбора из PhotoPickerWidget
  String? pickContextId;
  int? pickContextIndex;

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
    this.contrast = 1.0,
    this.opacity = 1.0,
    this.flipX = false,
    this.pickContextId,
    this.pickContextIndex,
    Offset? internalOffset,
    this.baseOffsetOnGesture,
  })  : cropRect = cropRect ?? const Rect.fromLTWH(0, 0, 1, 1),
        internalOffset = internalOffset ?? Offset.zero;

  bool get isVideo => photo.mediaType == 'video';
  bool get isImage => photo.mediaType == 'image';
}

/// UI-состояние видео.
class VideoUi {
  double startFrac;
  double endFrac;
  double posFrac;
  double volume;
  double speed;
  Duration duration;
  int seekRequestId;
  VideoPlayerController? controller;

  VideoUi({
    this.startFrac = 0.0,
    this.endFrac = 1.0,
    this.posFrac = 0.0,
    this.volume = 0.0,
    this.speed = 1.0,
    this.duration = Duration.zero,
    this.seekRequestId = 0,
    this.controller,
  });

  void disposeControllerIfAny() {
    final c = controller;
    controller = null;
    if (c != null) {
      try {
        c.dispose();
      } catch (_) {}
    }
  }
}

////////////////////////////////////////////////////////////////
/// SECTION: Helpers
////////////////////////////////////////////////////////////////

/// A) Video time helpers (у тебя уже было; оставляю тут)
Duration fracToTime(Duration total, double f) {
  if (total == Duration.zero) return Duration.zero;
  final ms = (total.inMilliseconds * f.clamp(0.0, 1.0)).round();
  return Duration(milliseconds: ms);
}

double timeToFrac(Duration total, Duration t) {
  if (total == Duration.zero) return 0.0;
  return (t.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
}

/// B) Tap vs Drag tracker: вместо двух Map’ов в State.
/// Работает так:
/// - pointerDown(id, pos)
/// - pointerMove(id, pos)
/// - pointerUp(id) => true если это TAP (движения почти не было)
class TapDragTracker {
  final double slopPx;

  final Map<String, Offset> _downPos = <String, Offset>{};
  final Set<String> _moved = <String>{};

  TapDragTracker({this.slopPx = 8.0});

  void pointerDown(String id, Offset position) {
    _downPos[id] = position;
    _moved.remove(id);
  }

  void pointerMove(String id, Offset position) {
    final start = _downPos[id];
    if (start == null) return;
    if (_moved.contains(id)) return;
    final moved = (position - start).distance > slopPx;
    if (moved) _moved.add(id);
  }

  /// returns true if TAP (no drag)
  bool pointerUp(String id) {
    final isTap = !_moved.contains(id);
    _downPos.remove(id);
    _moved.remove(id);
    return isTap;
  }

  void clear(String id) {
    _downPos.remove(id);
    _moved.remove(id);
  }

  void clearAll() {
    _downPos.clear();
    _moved.clear();
  }
}

/// C) Matrix / transform helpers для InteractiveViewer.
class TransformMath {
  static double getScale(Matrix4 matrix) => matrix.getMaxScaleOnAxis();

  static Offset getTranslation(Matrix4 matrix) =>
      Offset(matrix.storage[12], matrix.storage[13]);

  static Matrix4 matrixFromOffsetScale(Offset offset, double scale) {
    return Matrix4.identity()
      ..translate(offset.dx, offset.dy)
      ..scale(scale);
  }

  /// Зум к абсолютному scale вокруг focalPoint.
  static Matrix4 zoomToScale({
    required Matrix4 current,
    required double targetScale,
    required double minScale,
    required double maxScale,
    required Offset focalPoint,
  }) {
    final currentScale = getScale(current);
    final clamped = targetScale.clamp(minScale, maxScale);
    final scaleDelta = clamped / currentScale;
    if (scaleDelta == 1.0) return current;

    final zoom = Matrix4.identity()
      ..translate(focalPoint.dx, focalPoint.dy)
      ..scale(scaleDelta)
      ..translate(-focalPoint.dx, -focalPoint.dy);

    return zoom * current;
  }
}

/// D) Overview grid helper.
/// Возвращает рассчитанные offsets/scales, ничего не мутируя.
class OverviewLayoutResult {
  final List<Offset> offsets;
  final List<double> scales;

  const OverviewLayoutResult({required this.offsets, required this.scales});
}

class OverviewLayoutHelper {
  static OverviewLayoutResult compute({
    required List<CollagePhotoState> items,
    required double screenWidth,
    double spacing = 20.0,
    double itemTargetWidth = 200.0,
  }) {
    if (items.isEmpty) {
      return const OverviewLayoutResult(offsets: [], scales: []);
    }

    final columns = (screenWidth / (itemTargetWidth + spacing))
        .floor()
        .clamp(1, items.length);
    final actualItemWidth = (screenWidth - (columns + 1) * spacing) / columns;

    final offsets = <Offset>[];
    final scales = <double>[];

    for (int i = 0; i < items.length; i++) {
      final row = i ~/ columns;
      final col = i % columns;

      final x = spacing + col * (actualItemWidth + spacing);
      final y = spacing + row * (actualItemWidth + spacing);

      final item = items[i];
      final scale = actualItemWidth / item.baseWidth;

      offsets.add(Offset(x, y));
      scales.add(scale);
    }

    return OverviewLayoutResult(offsets: offsets, scales: scales);
  }
}

////////////////////////////////////////////////////////////////
/// SECTION: Services (Prefs + Persist)
////////////////////////////////////////////////////////////////

class CollagePrefsService {
  static const String _kTutorPassed = 'collage_tutor_passed';
  static const String _kCollageScale = 'collage_scale';

  Future<bool> isTutorPassed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTutorPassed) ?? false;
  }

  Future<void> markTutorPassed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorPassed, true);
  }

  Future<double?> loadCollageScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kCollageScale);
  }

  Future<void> saveCollageScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kCollageScale, scale);
  }
}

class CollagePersistService {
  /// Сохранить/обновить коллаж в БД через Bloc + перерендерить превью.
  Future<void> saveToDb({
    required BuildContext context,
    required GlobalKey boundaryKey,
    required Collage? existing,
    required String titleForNew,
    required int backgroundColorValue,
    required List<CollagePhotoState> items,
    required Map<String, VideoUi> videoStates,
    required bool isPrivate,
    required double canvasOffsetX,
    required double canvasOffsetY,
    required double canvasScale,
  }) async {
    final now = DateTime.now();

    final itemsList = items.map((it) {
      final ui = videoStates[it.id];
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
        contrast: it.contrast,
        opacity: it.opacity,
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

    if (existing == null) {
      final collageId = const Uuid().v4();

      String previewPath = '';
      try {
        previewPath = await CollagePreviewHelper.renderPreviewPng(
          boundaryKey: boundaryKey,
          collageId: collageId,
          pixelRatio: 1.25,
        );
      } catch (_) {}

      final newCollage = Collage(
        id: collageId,
        title: titleForNew.trim(),
        backgroundColorValue: backgroundColorValue,
        items: itemsList,
        dateCreated: now,
        dateUpdated: now,
        previewPath: previewPath.isEmpty ? null : previewPath,
        isPrivate: isPrivate,
        canvasOffsetX: canvasOffsetX,
        canvasOffsetY: canvasOffsetY,
        canvasScale: canvasScale,
      );

      context.read<CollageBloc>().add(AddCollage(newCollage));
    } else {
      String previewPath = existing.previewPath ?? '';
      try {
        previewPath = await CollagePreviewHelper.renderPreviewPng(
          boundaryKey: boundaryKey,
          collageId: existing.id,
          pixelRatio: 1.25,
        );
      } catch (_) {}

      final updated = Collage(
        id: existing.id,
        title: existing.title,
        backgroundColorValue: backgroundColorValue,
        items: itemsList,
        dateCreated: existing.dateCreated,
        dateUpdated: now,
        previewPath: previewPath.isEmpty ? existing.previewPath : previewPath,
        isPrivate: isPrivate,
        canvasOffsetX: canvasOffsetX,
        canvasOffsetY: canvasOffsetY,
        canvasScale: canvasScale,
      );

      context.read<CollageBloc>().add(UpdateCollage(updated));
    }
  }
}

////////////////////////////////////////////////////////////////
/// SECTION: Controller (вся логика изменений)
////////////////////////////////////////////////////////////////

class CollageController {
  final List<CollagePhotoState> items;
  final Map<String, VideoUi> videoStates;

  int maxZIndex;

  CollageController({
    required this.items,
    required this.videoStates,
    required this.maxZIndex,
  });

  int indexOf(CollagePhotoState item) => items.indexOf(item);

  void bringToFront(CollagePhotoState item) {
    maxZIndex++;
    item.zIndex = maxZIndex;
  }

  void sendBackward(CollagePhotoState item) {
    if (items.length < 2) return;
    final sorted = List<CollagePhotoState>.of(items)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final index = sorted.indexOf(item);
    if (index <= 0) return;
    final below = sorted[index - 1];
    final tmp = item.zIndex;
    item.zIndex = below.zIndex;
    below.zIndex = tmp;
  }

  void sendForward(CollagePhotoState item) {
    if (items.length < 2) return;
    final sorted = List<CollagePhotoState>.of(items)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final index = sorted.indexOf(item);
    if (index == -1 || index >= sorted.length - 1) return;
    final above = sorted[index + 1];
    final tmp = item.zIndex;
    item.zIndex = above.zIndex;
    above.zIndex = tmp;
  }

  void ensureVideoStateFor(CollagePhotoState item) {
    if (item.photo.mediaType != 'video') return;
    videoStates.putIfAbsent(item.id, () => VideoUi());
  }

  void removeAt(int index) {
    if (index < 0 || index >= items.length) return;
    final removed = items.removeAt(index);
    final ui = videoStates.remove(removed.id);
    ui?.disposeControllerIfAny();
  }

  void removeById(String id) {
    final idx = items.indexWhere((e) => e.id == id);
    if (idx != -1) removeAt(idx);
  }

  void clearEditing() {
    for (final it in items) {
      it.isEditing = false;
    }
  }

  void setEditing(CollagePhotoState item, bool editing) {
    if (editing) {
      for (final it in items) {
        it.isEditing = false;
      }
    }
    item.isEditing = editing;
  }

  CollagePhotoState addPhoto({
    required Photo photo,
    required CollagePhotoState Function(Photo) createState,
    Offset initialOffset = const Offset(50, 50),
  }) {
    final s = createState(photo);
    addState(s, initialOffset: initialOffset);
    return s;
  }

  void addState(
    CollagePhotoState state, {
    Offset? initialOffset,
  }) {
    state.offset = initialOffset ?? state.offset;
    maxZIndex++;
    state.zIndex = maxZIndex;
    items.add(state);
    ensureVideoStateFor(state);
  }

  Future<void> seekActiveVideoBySeconds({
    required int? activeItemIndex,
    required int deltaSeconds,
  }) async {
    if (activeItemIndex == null) return;
    if (activeItemIndex < 0 || activeItemIndex >= items.length) return;

    final item = items[activeItemIndex];
    if (item.photo.mediaType != 'video') return;

    final ui = videoStates[item.id];
    final c = ui?.controller;
    if (ui == null || c == null || !c.value.isInitialized) return;

    final cur = c.value.position;
    final dur = c.value.duration;

    final target = cur + Duration(seconds: deltaSeconds);

    Duration clamped;
    if (target < Duration.zero) {
      clamped = Duration.zero;
    } else if (target > dur) {
      clamped = dur;
    } else {
      clamped = target;
    }

    await c.seekTo(clamped);

    ui.posFrac = (dur == Duration.zero)
        ? 0.0
        : (clamped.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
    ui.seekRequestId++;
  }

  Future<void> toggleActiveVideoPlayPause(int? activeItemIndex) async {
    if (activeItemIndex == null) return;
    if (activeItemIndex < 0 || activeItemIndex >= items.length) return;

    final item = items[activeItemIndex];
    if (item.photo.mediaType != 'video') return;

    final ui = videoStates[item.id];
    final c = ui?.controller;
    if (ui == null || c == null || !c.value.isInitialized) return;

    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
  }
}

////////////////////////////////////////////////////////////////
/// SECTION: Widget (UI)
////////////////////////////////////////////////////////////////

class PhotoCollageWidget extends StatefulWidget {
  final List<Photo> photos; // Уже выбранные фото
  final List<Photo> allPhotos; // Все доступные фото
  final Collage? initialCollage;
  final bool startWithSelectedPhotos;

  const PhotoCollageWidget({
    super.key,
    required this.photos,
    required this.allPhotos,
    this.initialCollage,
    this.startWithSelectedPhotos = false,
  });

  @override
  State<PhotoCollageWidget> createState() => _PhotoCollageWidgetState();
}

class _PhotoCollageWidgetState extends State<PhotoCollageWidget> {
  // --- Keys ---
  final GlobalKey _collageKey = GlobalKey();
  final GlobalKey _deleteIconKey = GlobalKey();

  // --- Focus ---
  final FocusNode _focusNode = FocusNode();

  // --- Helpers/Services/Controller ---
  final TapDragTracker _tapDrag = TapDragTracker(slopPx: 8.0);
  final CollagePrefsService _prefs = CollagePrefsService();
  final CollagePersistService _persist = CollagePersistService();

  // --- Transform ---
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _ignoreTransformUpdates = false;

  double _collageScale = 1.0;
  static const double _minCollageScale = 0.9;
  static const double _maxCollageScale = 60.0;
  static const double _canvasSizeMultiplier = 10.0;
  static const int _maxViewZones = 10;
  static const List<Color> _viewZonePalette = [
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.amber,
    Colors.greenAccent,
    Colors.cyanAccent,
    Colors.blueAccent,
    Colors.indigoAccent,
    Colors.purpleAccent,
    Colors.pinkAccent,
    Colors.tealAccent,
  ];

  // --- Items state ---
  late final Map<String, VideoUi> _videoStates = <String, VideoUi>{};
  late final List<CollagePhotoState> _items = <CollagePhotoState>[];
  late CollageController _controller;

  final Map<String, List<String>> _pickContexts = <String, List<String>>{};
  final Map<String, Photo> _photoByFileName = <String, Photo>{};
  final List<Photo> _allPhotosLocal = <Photo>[];

  int _maxZIndex = 0;
  int? _activeItemIndex;
  int? _activeViewZoneIndex;
  final List<_ViewZone?> _viewZones =
      List<_ViewZone?>.filled(_maxViewZones, null, growable: true);
  final List<Color> _viewZoneColors =
      List<Color>.generate(_maxViewZones, (i) => _viewZonePalette[i]);
  bool _showViewZoneOverlay = false;
  int? _draggingViewZoneIndex;
  Offset? _viewZoneDragLastScreen;
  int? _resizingViewZoneIndex;
  Offset? _viewZoneResizeStartScreenPos;
  Rect? _viewZoneResizeStartScreenRect;
  Offset? _viewZoneResizeAnchorTopLeft;
  double? _viewZoneResizeStartScale;
  Matrix4? _preViewZoneMatrix;
  PersistentBottomSheetController? _viewZoneSheetController;
  bool _skipViewZoneRestore = false;
  int? _pendingViewZoneIndex;
  double? _pendingZoomMultiplier;

  // --- Delete drag target ---
  Rect _deleteRect = Rect.zero;
  bool _deleteHover = false;
  int? _draggingIndex; // индекс в _items (не в sorted!)
  final Map<String, DateTime> _recentlyDropped = <String, DateTime>{};

  // --- Modes ---
  bool _overviewMode = false;
  List<Offset> _originalOffsets = <Offset>[];
  List<double> _originalScales = <double>[];

  bool _isItemScaleGestureActive = false;
  bool _isTrackpadPanZoomActive = false;
  bool _fullscreenBottomHoverLeft = false;
  bool _fullscreenBottomHoverRight = false;
  Timer? _arrowRepeatDelay;
  Timer? _arrowRepeatTick;
  LogicalKeyboardKey? _heldArrowKey;

  void _exitEditingMode({bool keepActiveSelection = true}) {
    setState(() {
      _controller.clearEditing();
      _isItemScaleGestureActive = false;
      _draggingIndex = null;
      _deleteHover = false;
      _tapDrag.clearAll();
      for (final key in _controlsHover.keys) {
        _controlsHover[key] = false;
      }
      if (!keepActiveSelection) {
        _activeItemIndex = null;
      }
    });
  }

  void _scheduleDeleteRectUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateDeleteRect();
    });
  }

  void _startArrowRepeat(LogicalKeyboardKey key) {
    if (_heldArrowKey == key && _arrowRepeatTick != null) return;
    _heldArrowKey = key;
    _arrowRepeatDelay?.cancel();
    _arrowRepeatTick?.cancel();
    _arrowRepeatDelay = Timer(const Duration(milliseconds: 250), () {
      _arrowRepeatTick =
          Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (_heldArrowKey == LogicalKeyboardKey.arrowRight) {
          _switchPhotoInActiveContainer(next: true);
        } else if (_heldArrowKey == LogicalKeyboardKey.arrowLeft) {
          _switchPhotoInActiveContainer(next: false);
        }
      });
    });
  }

  void _cancelArrowRepeat() {
    _heldArrowKey = null;
    _arrowRepeatDelay?.cancel();
    _arrowRepeatTick?.cancel();
    _arrowRepeatDelay = null;
    _arrowRepeatTick = null;
  }

  // --- UI ---
  Color _backgroundColor = Colors.black;
  bool _isPrivate = false;
  bool _isFullscreen = false;
  bool _wasMaximizedBeforeFullscreen = false;

  bool _showTutorial = false;
  bool _showForInitDeleteIcon = true;
  bool _hasAutoFitted = false;
  bool _pendingInitialLayout = false;

  // hover state for video
  final Map<String, bool> _controlsHover = <String, bool>{};
  final Map<String, bool> _videoHover = <String, bool>{};

  Size _canvasViewportSize = Size.zero;
  static const double _videoControlsHeight = 34.0;
  final ScrollController _overviewScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _isPrivate = widget.initialCollage?.isPrivate ?? false;

    _controller = CollageController(
      items: _items,
      videoStates: _videoStates,
      maxZIndex: _maxZIndex,
    );

    _focusNode.requestFocus();
    _transformationController.addListener(_handleTransformChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initTutorialFlag();
      _updateDeleteRect();
      _ensureViewZoneState();
      if (!mounted) return;
      setState(() {
        _showForInitDeleteIcon = false;
      });
    });
  }

  void _ensureViewZoneState() {
    _ensureViewZoneListSize();
    _ensureViewZoneColors();
  }

  void _ensureViewZoneListSize() {
    if (_viewZones.length >= _maxViewZones) return;
    for (int i = _viewZones.length; i < _maxViewZones; i++) {
      _viewZones.add(null);
    }
  }

  void _ensureViewZoneColors() {
    if (_viewZoneColors.length >= _maxViewZones) return;
    for (int i = _viewZoneColors.length; i < _maxViewZones; i++) {
      _viewZoneColors.add(_viewZonePalette[i % _viewZonePalette.length]);
    }
  }

  Future<void> _initTutorialFlag() async {
    final passed = await _prefs.isTutorPassed();
    if (!passed && mounted) {
      setState(() => _showTutorial = true);
    }
  }

  void _syncAllPhotosFromWidget() {
    for (final p in widget.allPhotos) {
      if (_photoByFileName.containsKey(p.fileName)) continue;
      _photoByFileName[p.fileName] = p;
      _allPhotosLocal.add(p);
    }
  }

  void _registerPhoto(Photo photo) {
    if (_photoByFileName.containsKey(photo.fileName)) return;
    _photoByFileName[photo.fileName] = photo;
    _allPhotosLocal.add(photo);
  }

  void _initEmptyCollage() {
    _items.clear();
    _videoStates.clear();
    _maxZIndex = 0;
    _activeItemIndex = null;
    _controller.maxZIndex = 0;
    _pendingInitialLayout = false;
    setState(() {});
  }

  void _initCollageFromSelectedPhotos() {
    _items.clear();
    _videoStates.clear();
    _pendingInitialLayout = true;

    final filtered = widget.photos.where(
      (p) => p.mediaType == 'image' || p.mediaType == 'video',
    );

    for (final p in filtered) {
      final s = _createCollagePhotoState(p);
      _items.add(s);
      if (p.mediaType == 'video') {
        _videoStates[s.id] = VideoUi();
      }
    }
  }

  void _applyInitialLayoutForSelectedPhotos() {
    if (_items.isEmpty) return;

    if (_items.length == 1) {
      final item = _items.first;
      _fitAndCenterFirstItem(item);
      _activeItemIndex = 0;
    } else {
      for (int i = 0; i < _items.length; i++) {
        final it = _items[i];
        it.offset = _cascadeOffsetForIndex(i, it);
      }
    }

    for (int i = 0; i < _items.length; i++) {
      _items[i].zIndex = i;
    }
    _maxZIndex = _items.length;
    _controller.maxZIndex = _maxZIndex;

    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _syncAllPhotosFromWidget();

    if (_items.isEmpty) {
      if (widget.initialCollage != null) {
        _initCollageFromExisting(widget.initialCollage!);
      } else if (widget.startWithSelectedPhotos && widget.photos.isNotEmpty) {
        _initCollageFromSelectedPhotos();
      } else {
        _initEmptyCollage(); // ✅ только пусто
      }
      _controller.maxZIndex = _maxZIndex;
    }

    if (!_hasAutoFitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final saved = await _prefs.loadCollageScale();
        if (!mounted) return;
        if (widget.initialCollage == null) {
          final size = _viewportSize();
          final scale = 5.0;
          final center = Offset(size.width / 2, size.height / 2);
          final translation =
              Offset(center.dx * (1 - scale), center.dy * (1 - scale));
          _setTransform(
              TransformMath.matrixFromOffsetScale(translation, scale));
        } else if (widget.initialCollage?.canvasOffsetX != null &&
            widget.initialCollage?.canvasOffsetY != null &&
            widget.initialCollage?.canvasScale != null) {
          final savedScale = widget.initialCollage!.canvasScale!
              .clamp(_minCollageScale, _maxCollageScale);
          final translation = Offset(
            widget.initialCollage!.canvasOffsetX!,
            widget.initialCollage!.canvasOffsetY!,
          );
          _setTransform(
              TransformMath.matrixFromOffsetScale(translation, savedScale));
        } else if (saved != null) {
          final clamped = saved.clamp(_minCollageScale, _maxCollageScale);
          final translation =
              TransformMath.getTranslation(_transformationController.value);
          _setTransform(
              TransformMath.matrixFromOffsetScale(translation, clamped));
        }
        if (_pendingInitialLayout) {
          _pendingInitialLayout = false;
          _applyInitialLayoutForSelectedPhotos();
        }
        _ensureDefaultViewZone();
        _updateDeleteRect();
        _hasAutoFitted = true;
      });
    }
  }

  void _handleTransformChanged() {
    if (_ignoreTransformUpdates) return;
    final matrix = _transformationController.value;
    final scale = TransformMath.getScale(matrix);
    if (!mounted) return;
    setState(() {
      _collageScale = scale;
    });
  }

  void _setTransform(Matrix4 matrix) {
    _ignoreTransformUpdates = true;
    _transformationController.value = matrix;
    _ignoreTransformUpdates = false;

    final scale = TransformMath.getScale(matrix);
    if (mounted) {
      setState(() {
        _collageScale = scale;
      });
    }
  }

  Future<void> _saveCollageScale(double scale) async {
    await _prefs.saveCollageScale(scale);
  }

  void _zoomToScale(double scale, Offset focalPoint) {
    final next = TransformMath.zoomToScale(
      current: _transformationController.value,
      targetScale: scale,
      minScale: _minCollageScale,
      maxScale: _maxCollageScale,
      focalPoint: focalPoint,
    );
    _setTransform(next);
  }

  void _updateDeleteRect() {
    final iconBox =
        _deleteIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (iconBox == null) return;
    final position = iconBox.localToGlobal(Offset.zero);
    setState(() {
      _deleteRect = Rect.fromLTWH(
        position.dx,
        position.dy,
        iconBox.size.width,
        iconBox.size.height,
      );
    });
  }

  // ----------------------------
  // Init collage items
  // ----------------------------

  void _initCollageFromExisting(Collage collage) {
    _backgroundColor = Color(collage.backgroundColorValue);
    _isPrivate = collage.isPrivate ?? false;
    _pendingInitialLayout = false;

    _items.clear();
    _videoStates.clear();

    for (final src in collage.items) {
      final photo = widget.allPhotos.firstWhere(
        (p) => p.fileName == src.fileName,
        orElse: () => Photo(
          folderIds: [],
          comment: '',
          tagIds: [],
          path: '',
          id: 'dummy',
          fileName: src.fileName,
          mediaType: 'image',
          dateAdded: DateTime.now(),
          sortOrder: 0,
        ),
      );
      _registerPhoto(photo);

      final item = CollagePhotoState(
        id: const Uuid().v4(),
        photo: photo,
        offset: Offset(src.offsetX, src.offsetY),
        scale: src.scale,
        rotation: src.rotation,
        zIndex: src.zIndex,
        baseWidth: src.baseWidth,
        baseHeight: src.baseHeight,
        brightness: src.brightness,
        saturation: src.saturation,
        temp: src.temp,
        hue: src.hue,
        contrast: src.contrast,
        opacity: src.opacity,
        cropRect: Rect.fromLTRB(
          src.cropRectLeft,
          src.cropRectTop,
          src.cropRectRight,
          src.cropRectBottom,
        ),
        internalOffset: Offset(src.internalOffsetX, src.internalOffsetY),
      );

      _items.add(item);

      if (photo.mediaType == 'video') {
        _videoStates[item.id] = VideoUi(
          startFrac: (src.videoStartFrac ?? 0.0).clamp(0.0, 1.0),
          endFrac: (src.videoEndFrac ?? 1.0).clamp(0.0, 1.0),
          speed: (src.videoSpeed ?? 1.0).clamp(0.1, 4.0),
          posFrac: 0.0,
          volume: 0.0,
          duration: Duration.zero,
        );
      }
    }

    _maxZIndex =
        _items.isEmpty ? 0 : _items.map((e) => e.zIndex).reduce(math.max);
    _controller.maxZIndex = _maxZIndex;

    setState(() {});
  }

  void _initCollageItems() {
    if (widget.initialCollage == null) {
      // ✅ создаём новый коллаж — всегда пустой
      _items.clear();
      _videoStates.clear();
      _maxZIndex = 0;
      _activeItemIndex = null;
      setState(() {});
      return;
    }
    _items.clear();
    _videoStates.clear();

    final filtered = widget.photos.where(
      (p) => p.mediaType == 'image' || p.mediaType == 'video',
    );

    for (final p in filtered) {
      final s = _createCollagePhotoState(p);
      _items.add(s);
      if (p.mediaType == 'video') {
        _videoStates[s.id] = VideoUi();
      }
    }

    final canvasWidth = MediaQuery.of(context).size.width;
    final canvasHeight = MediaQuery.of(context).size.height;

    if (_items.length == 1) {
      final item = _items.first;

      final photoAspect = item.baseWidth / item.baseHeight;
      final screenAspect = canvasWidth / canvasHeight;

      double scale;
      if (photoAspect > screenAspect) {
        scale = canvasWidth / item.baseWidth;
      } else {
        scale = canvasHeight / item.baseHeight;
      }

      final newWidth = item.baseWidth * scale;
      final newHeight = item.baseHeight * scale;

      item.offset =
          Offset((canvasWidth - newWidth) / 2, (canvasHeight - newHeight) / 2);
      item.scale = scale;

      _activeItemIndex = 0;
    } else {
      for (int i = 0; i < _items.length; i++) {
        final it = _items[i];
        it.offset = _cascadeOffsetForIndex(i, it);
      }
    }

    for (int i = 0; i < _items.length; i++) {
      _items[i].zIndex = i;
    }
    _maxZIndex = _items.length;
    _controller.maxZIndex = _maxZIndex;

    setState(() {});
  }

  CollagePhotoState _createCollagePhotoState(Photo photo) {
    final naturalSize = _getNaturalSizeForPhoto(photo);
    final baseW = naturalSize.width;
    final baseH = naturalSize.height;

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
      contrast: 1.0,
      opacity: 1.0,
      flipX: false,
    );
  }

  // ----------------------------
  // Keyboard actions
  // ----------------------------

  Future<void> _seekActiveVideoBySeconds(int deltaSeconds) async {
    await _controller.seekActiveVideoBySeconds(
      activeItemIndex: _activeItemIndex,
      deltaSeconds: deltaSeconds,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleActiveVideoPlayPause() async {
    await _controller.toggleActiveVideoPlayPause(_activeItemIndex);
    if (!mounted) return;
    setState(() {});
  }

  void _zoomByStep(double multiplier) {
    final current = _collageScale;
    final next = (current * multiplier).clamp(_minCollageScale, _maxCollageScale);
    final focal = _canvasViewportSize == Size.zero
        ? Offset.zero
        : _canvasViewportSize.center(Offset.zero);
    _zoomToScale(next, focal);
    _saveCollageScale(next);
  }

  // ----------------------------
  // Overview mode
  // ----------------------------

  void _toggleOverviewMode() {
    setState(() {
      _overviewMode = !_overviewMode;
      if (_overviewMode) {
        _enterOverviewLayout();
      } else {
        _exitOverviewLayout();
      }
    });
  }

  void _enterOverviewLayout() {
    _originalOffsets = _items.map((e) => e.offset).toList();
    _originalScales = _items.map((e) => e.scale).toList();
  }

  void _exitOverviewLayout({int? bringToFrontIndex}) {
    if (_originalOffsets.length == _items.length &&
        _originalScales.length == _items.length) {
      for (int i = 0; i < _items.length; i++) {
        _items[i].offset = _originalOffsets[i];
        _items[i].scale = _originalScales[i];
      }
    }

    if (bringToFrontIndex != null &&
        bringToFrontIndex >= 0 &&
        bringToFrontIndex < _items.length) {
      _controller.bringToFront(_items[bringToFrontIndex]);
      _maxZIndex = _controller.maxZIndex;
    }

    setState(() {
      _overviewMode = false;
    });
  }

  // ----------------------------
  // UI actions
  // ----------------------------

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    setState(() {
      _isFullscreen = next;
    });
    if (Platform.isIOS) {
      if (next) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        WakelockPlus.enable();
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        WakelockPlus.disable();
      }
      return;
    }
    if (!Platform.isMacOS) return;
    try {
      if (next) {
        WakelockPlus.enable();
        _wasMaximizedBeforeFullscreen = await windowManager.isMaximized();
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: false,
        );
        await windowManager.maximize();
      } else {
        WakelockPlus.disable();
        await windowManager.setTitleBarStyle(
          TitleBarStyle.normal,
          windowButtonVisibility: true,
        );
        if (!_wasMaximizedBeforeFullscreen) {
          await windowManager.unmaximize();
        }
      }
    } catch (_) {}
  }

  void _showHelp() {
    setState(() {
      _showTutorial = true;
    });
  }

  Future<void> _markTutorialPassed() async {
    await _prefs.markTutorPassed();
  }

  void _showColorPickerDialog() {
    final oldColor = _backgroundColor;
    Color tempColor = _backgroundColor;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Pick Background Color'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BlockPicker(
                  pickerColor: tempColor,
                  availableColors: const [
                    Colors.white,
                    Colors.black,
                    Color(0xFF111111),
                    Colors.grey,
                    Colors.blueGrey,
                    Colors.brown,
                    Colors.red,
                    Colors.redAccent,
                    Colors.pink,
                    Colors.purple,
                    Colors.indigo,
                    Colors.blue,
                    Colors.lightBlue,
                    Colors.cyan,
                    Colors.teal,
                    Colors.green,
                    Colors.lightGreen,
                    Colors.lime,
                    Colors.yellow,
                    Colors.amber,
                    Colors.orange,
                    Colors.deepOrange,
                  ],
                  layoutBuilder: (context, colors, child) {
                    return SizedBox(
                      width: 260,
                      height: 150,
                      child: GridView.count(
                        crossAxisCount: 8,
                        crossAxisSpacing: 3,
                        mainAxisSpacing: 3,
                        children: [for (final c in colors) child(c)],
                      ),
                    );
                  },
                  itemBuilder: (color, isCurrentColor, changeColor) {
                    final isLight = color.computeLuminance() > 0.7;
                    return Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: isLight ? Colors.black12 : Colors.white12,
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: changeColor,
                              customBorder: const CircleBorder(),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity: isCurrentColor ? 1 : 0,
                                child: Icon(
                                  Icons.check,
                                  color: isLight ? Colors.black : Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  onColorChanged: (c) {
                    tempColor = c;
                    setState(() => _backgroundColor = tempColor);
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 260,
                  child: HueRingPicker(
                    pickerColor: tempColor,
                    onColorChanged: (c) {
                      tempColor = c;
                      setState(() => _backgroundColor = tempColor);
                    },
                    colorPickerHeight: 140,
                    hueRingStrokeWidth: 14,
                    enableAlpha: false,
                    displayThumbColor: false,
                    portraitOnly: true,
                  ),
                ),
              ],
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

  void _showAllPhotosSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          widthFactor: 1,
          heightFactor: 1,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1000,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: PhotoPickerWidget(
                  onPhotoSelected: (result) {
                    Navigator.pop(context);
                    _addPickedToCollage(result, cascadeIndex: 0);
                  },
                  onMultiSelectDone: (List<PhotoPickResult> list) {
                    Navigator.pop(context);
                    for (int i = 0; i < list.length; i++) {
                      _addPickedToCollage(list[i], cascadeIndex: i);
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _addPickedToCollage(
    PhotoPickResult result, {
    required int cascadeIndex,
  }) {
    _registerPhoto(result.photo);
    _pickContexts.putIfAbsent(
      result.contextId,
      () => result.contextFileNames,
    );

    setState(() {
      final item = _createCollagePhotoState(result.photo);
      if (_items.isEmpty) {
        _fitAndCenterFirstItem(item);
      } else {
        item.scale = item.scale * 0.5;
      }
      final offset = _items.isEmpty
          ? item.offset
          : _cascadeOffsetForIndex(cascadeIndex, item);
      _controller.addState(item, initialOffset: offset);
      item.pickContextId = result.contextId;
      item.pickContextIndex = result.indexInContext;
      _maxZIndex = _controller.maxZIndex;
    });
  }

  void _addPhotoToCollage(
    Photo photo, {
    required int cascadeIndex,
  }) {
    _registerPhoto(photo);
    setState(() {
      final item = _createCollagePhotoState(photo);
      if (_items.isEmpty) {
        _fitAndCenterFirstItem(item);
      } else {
        item.scale = item.scale * 0.5;
      }
      final offset = _items.isEmpty
          ? item.offset
          : _cascadeOffsetForIndex(cascadeIndex, item);
      _controller.addState(item, initialOffset: offset);
      _maxZIndex = _controller.maxZIndex;
    });
  }

  Future<void> _onGenerateCollage() async {
    _controller.clearEditing();
    setState(() {});
    await CollageSaveHelper.saveCollage(_collageKey, context);
  }

  Future<void> _onSaveCollageToDb() async {
    final now = DateTime.now();
    final formattedDate =
        "My_collage_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final titleController = TextEditingController(text: formattedDate);

    String? newTitle;
    if (widget.initialCollage == null) {
      newTitle = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Save Collage'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) =>
                Navigator.of(ctx).pop(titleController.text),
            decoration: const InputDecoration(hintText: 'Collage Title'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () => Navigator.of(ctx).pop(titleController.text),
            ),
          ],
        ),
      );

      if (newTitle == null || newTitle.trim().isEmpty) return;
    }

    // Перед сохранением выключаем edit mode
    _controller.clearEditing();
    setState(() {});

    await _persist.saveToDb(
      context: context,
      boundaryKey: _collageKey,
      existing: widget.initialCollage,
      titleForNew: newTitle ?? widget.initialCollage?.title ?? 'Collage',
      backgroundColorValue: _backgroundColor.value,
      items: _items,
      videoStates: _videoStates,
      isPrivate: _isPrivate,
      canvasOffsetX:
          TransformMath.getTranslation(_transformationController.value).dx,
      canvasOffsetY:
          TransformMath.getTranslation(_transformationController.value).dy,
      canvasScale: TransformMath.getScale(_transformationController.value),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collage saved to DB!')),
    );
  }

  // ----------------------------
  // Active photo switching (arrow keys)
  // ----------------------------

  void _switchPhotoInActiveContainer({required bool next}) {
    if (_activeItemIndex == null) return;
    if (_activeItemIndex! < 0 || _activeItemIndex! >= _items.length) return;

    final item = _items[_activeItemIndex!];
    final contextId = item.pickContextId;
    if (contextId != null && _pickContexts.containsKey(contextId)) {
      final contextFileNames = _pickContexts[contextId]!;
      if (contextFileNames.isEmpty) return;

      int curIndex = item.pickContextIndex ?? -1;
      if (curIndex < 0 || curIndex >= contextFileNames.length) {
        curIndex = contextFileNames.indexOf(item.photo.fileName);
      }
      if (curIndex < 0) return;

      int newIndex = next ? curIndex + 1 : curIndex - 1;
      newIndex = newIndex.clamp(0, contextFileNames.length - 1);

      final nextFileName = contextFileNames[newIndex];
      final nextPhoto = _photoByFileName[nextFileName];
      if (nextPhoto == null) return;

      setState(() {
        _applyPhotoSwitch(item, nextPhoto);
        item.pickContextIndex = newIndex;
      });
      return;
    }

    final currentPhoto = item.photo;
    final allIndex = _allPhotosLocal
        .indexWhere((p) => p.fileName == currentPhoto.fileName);
    if (allIndex == -1) return;

    int newIndex = next ? allIndex + 1 : allIndex - 1;
    newIndex = newIndex.clamp(0, _allPhotosLocal.length - 1);

    setState(() {
      final newPhoto = _allPhotosLocal[newIndex];
      _applyPhotoSwitch(item, newPhoto);
    });
  }

  void _applyPhotoSwitch(CollagePhotoState item, Photo newPhoto) {
    final wasVideo = item.photo.mediaType == 'video';
    final oldW = item.baseWidth * item.scale;
    final oldH = item.baseHeight * item.scale;
    final oldCenter = item.offset + Offset(oldW / 2, oldH / 2);
    if (wasVideo && newPhoto.mediaType != 'video') {
      final ui = _videoStates[item.id];
      ui?.disposeControllerIfAny();
      _videoStates.remove(item.id);
    }

    final naturalSize = _getNaturalSizeForPhoto(newPhoto);
    final naturalWidth = naturalSize.width;
    final naturalHeight = naturalSize.height;

    item.internalOffset = Offset.zero;
    item.cropRect = const Rect.fromLTWH(0, 0, 1, 1);
    item.photo = newPhoto;

    final canvasSize = _viewportSize();
    final maxScreenSide = math.min(canvasSize.width, canvasSize.height);
    final screenScale = _collageScale == 0 ? 1.0 : _collageScale;
    final maxAllowedCanvasSide = maxScreenSide / screenScale;

    final targetMaxSide =
        math.min(math.max(oldW, oldH), maxAllowedCanvasSide);
    final naturalMax = math.max(naturalWidth, naturalHeight);
    final scale =
        naturalMax == 0 ? 1.0 : (targetMaxSide / naturalMax).clamp(0.001, 1000);

    item.baseWidth = naturalWidth * scale;
    item.baseHeight = naturalHeight * scale;
    item.scale = 1.0;
    item.offset =
        oldCenter - Offset(item.baseWidth / 2, item.baseHeight / 2);
    _clampItemOffset(item);

    // Если заменили на видео — гарантируем VideoUi
    _controller.ensureVideoStateFor(item);
  }

  Size _viewportSize() {
    if (_canvasViewportSize != Size.zero) return _canvasViewportSize;
    return MediaQuery.of(context).size;
  }

  Size _currentCanvasSize() {
    final base = _viewportSize();
    return Size(
      base.width * _canvasSizeMultiplier,
      base.height * _canvasSizeMultiplier,
    );
  }

  double _containScaleForCanvas() {
    final viewport = _viewportSize();
    final canvas = _currentCanvasSize();
    if (viewport.width <= 0 ||
        viewport.height <= 0 ||
        canvas.width <= 0 ||
        canvas.height <= 0) {
      debugPrint(
        '[ViewZones] fitCanvas skipped viewport=$viewport canvas=$canvas',
      );
      return _minCollageScale;
    }

    return math.min(
      viewport.width / canvas.width,
      viewport.height / canvas.height,
    );
  }

  Matrix4 _fitCanvasToViewportMatrix() {
    final viewport = _viewportSize();
    final canvas = _currentCanvasSize();
    if (viewport.width <= 0 ||
        viewport.height <= 0 ||
        canvas.width <= 0 ||
        canvas.height <= 0) {
      debugPrint(
        '[ViewZones] fitCanvas skipped viewport=$viewport canvas=$canvas',
      );
      return _transformationController.value.clone();
    }

    final containScale = _containScaleForCanvas();
    final scale = math.max(containScale, _minCollageScale);
    final clamped = scale.clamp(0.001, _maxCollageScale);
    final offset = Offset(
      (viewport.width - canvas.width * clamped) / 2,
      (viewport.height - canvas.height * clamped) / 2,
    );
    debugPrint(
      '[ViewZones] fitCanvas viewport=$viewport canvas=$canvas '
      'contain=$containScale scale=$scale clamped=$clamped offset=$offset',
    );
    return TransformMath.matrixFromOffsetScale(offset, clamped);
  }

  Offset _screenToCanvas(Offset screen) {
    final inv = Matrix4.inverted(_transformationController.value);
    final v = Vector3(screen.dx, screen.dy, 0);
    final out = inv.transform3(v);
    return Offset(out.x, out.y);
  }

  Offset _canvasToScreen(Offset canvas) {
    final v = Vector3(canvas.dx, canvas.dy, 0);
    final out = _transformationController.value.transform3(v);
    return Offset(out.x, out.y);
  }

  void _clampItemOffset(CollagePhotoState item) {
    const double padding = 24.0;
    final size = _currentCanvasSize();
    if (size.width <= 0 || size.height <= 0) return;

    final w = item.baseWidth * item.scale;
    final h = item.baseHeight * item.scale;

    final minX = padding;
    final maxX = size.width - w - padding;
    final minY = padding;
    final maxY = size.height - h - padding;

    double nextX;
    if (maxX < minX) {
      nextX = (size.width - w) / 2;
    } else {
      nextX = item.offset.dx.clamp(minX, maxX);
    }

    double nextY;
    if (maxY < minY) {
      nextY = (size.height - h) / 2;
    } else {
      nextY = item.offset.dy.clamp(minY, maxY);
    }

    item.offset = Offset(nextX, nextY);
  }

  Offset _cascadeOffsetForIndex(int index, CollagePhotoState item) {
    const cascadeOffset = 50.0;
    const padding = 20.0;
    final size = _viewportSize();
    final screenScale = _collageScale;
    final w = item.baseWidth * item.scale * screenScale;
    final h = item.baseHeight * item.scale * screenScale;

    final maxX = math.max(padding, size.width - w - padding);
    final maxY = math.max(padding, size.height - h - padding);
    final screenOffset = Offset(
      padding + (index * cascadeOffset) % (maxX - padding + 1),
      padding + (index * cascadeOffset) % (maxY - padding + 1),
    );

    return _screenToCanvas(screenOffset);
  }

  void _fitAndCenterFirstItem(CollagePhotoState item) {
    final size = _viewportSize();
    final screenScale = _collageScale == 0 ? 1.0 : _collageScale;
    final scaleW = size.width / (item.baseWidth * screenScale);
    final scaleH = size.height / (item.baseHeight * screenScale);
    final scale = math.min(scaleW, scaleH);

    final screenW = item.baseWidth * scale * screenScale;
    final screenH = item.baseHeight * scale * screenScale;
    final screenOffset = Offset(
      (size.width - screenW) / 2,
      (size.height - screenH) / 2,
    );

    item.scale = scale;
    item.offset = _screenToCanvas(screenOffset);
  }

  bool _shouldSkipDroppedFile(File file) {
    final now = DateTime.now();
    _recentlyDropped.removeWhere(
      (_, ts) => now.difference(ts) > const Duration(seconds: 3),
    );
    String key = p.basename(file.path);
    try {
      final stat = file.statSync();
      final name = p.basename(file.path);
      key = '$name:${stat.size}:${stat.modified.millisecondsSinceEpoch}';
    } catch (_) {
      // fallback to basename-only to de-dupe double onDragDone with alias paths
    }
    final last = _recentlyDropped[key];
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return true;
    }
    _recentlyDropped[key] = now;
    return false;
  }

  Size _getNaturalSizeForPhoto(Photo photo) {
    const double targetShortSide = 150;

    if (photo.mediaType == 'video') {
      final vw = photo.videoWidth;
      final vh = photo.videoHeight;
      debugPrint('[Collage] video size meta: ${vw}x$vh');
      if (vw != null && vh != null && vw > 0 && vh > 0) {
        final shortSide = math.min(vw, vh);
        final scale = targetShortSide / shortSide;
        return Size(vw * scale, vh * scale);
      }
      if (photo.videoPreview != null && photo.videoPreview!.isNotEmpty) {
        final previewPath =
            PhotoPathHelper().getFullPath(photo.videoPreview!);
        final previewFile = File(previewPath);
        if (previewFile.existsSync()) {
          final decoded = img.decodeImage(previewFile.readAsBytesSync());
          if (decoded != null && decoded.width > 0 && decoded.height > 0) {
            debugPrint(
              '[Collage] video preview size: ${decoded.width}x${decoded.height}',
            );
            final shortSide = math.min(decoded.width, decoded.height);
            final scale = targetShortSide / shortSide;
            return Size(
              decoded.width * scale,
              decoded.height * scale,
            );
          }
        }
      }
      debugPrint('[Collage] video size fallback to 16:9');
      return const Size(targetShortSide * 16 / 9, targetShortSide);
    }

    final fullPath = _resolvePhotoPath(photo);
    final file = File(fullPath);
    if (file.existsSync()) {
      final decoded = img.decodeImage(file.readAsBytesSync());
      if (decoded != null && decoded.width > 0) {
        final height = decoded.height * (targetShortSide / decoded.width);
        return Size(targetShortSide, height);
      }
    }

    return const Size(targetShortSide, targetShortSide);
  }

  // ----------------------------
  // Build
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    final sorted = List<CollagePhotoState>.from(_items)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final CollagePhotoState? editingPhoto =
        sorted.cast<CollagePhotoState?>().firstWhere(
              (it) => it != null && it.isEditing,
              orElse: () => null,
            );

    final isSomePhotoInEditMode = sorted.any((it) => it.isEditing);

    final bool isIOS = Platform.isIOS;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    final videoOverlays = _overviewMode
        ? const <Widget>[]
        : sorted
            .where((it) => it.isVideo)
            .map((item) {
              final uiState = _videoStates[item.id];
              if (uiState == null) return const SizedBox.shrink();
              return _buildVideoControlsViewportOverlay(item, uiState);
            })
            .toList(growable: false);

    final rotationOverlays = _overviewMode
        ? const <Widget>[]
        : sorted
            .where((it) => it.isEditing)
            .map(_buildRotationSliderViewportOverlay)
            .toList(growable: false);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          if (event is KeyUpEvent) {
            _cancelArrowRepeat();
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent) {
            final next = event.logicalKey == LogicalKeyboardKey.arrowRight;
            _switchPhotoInActiveContainer(next: next);
            _startArrowRepeat(event.logicalKey);
            return KeyEventResult.handled;
          }
          if (event is KeyRepeatEvent) {
            _startArrowRepeat(event.logicalKey);
            return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }

        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (_handleViewZoneHotkeys(event)) {
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          if (_activeItemIndex != null &&
              _activeItemIndex! >= 0 &&
              _activeItemIndex! < _items.length) {
            final item = _items[_activeItemIndex!];
            if (item.isEditing) {
              _exitEditingMode();
              return KeyEventResult.handled;
            }
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.keyF) {
          _toggleFullscreen();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyA) {
          _showAllPhotosSheet();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyZ) {
          if (_showViewZoneOverlay) {
            _exitViewZoneOverlay();
          } else {
            _showViewZonePanel();
          }
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyO) {
          _toggleOverviewMode();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyB) {
          _showColorPickerDialog();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyS) {
          _onSaveCollageToDb();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyP) {
          setState(() => _isPrivate = !_isPrivate);
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyI) {
          _onGenerateCollage();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.space) {
          _toggleActiveVideoPlayPause();
          return KeyEventResult.handled;
        }

        final label = event.logicalKey.keyLabel;
        final isPlus = label == '+' || label == '=';
        final isMinus = label == '-' || label == '_';

        if (isPlus ||
            event.logicalKey == LogicalKeyboardKey.equal ||
            event.logicalKey == LogicalKeyboardKey.numpadAdd) {
          if (isPlus ||
              HardwareKeyboard.instance.isShiftPressed ||
              event.logicalKey == LogicalKeyboardKey.numpadAdd) {
            if (_showViewZoneOverlay) {
              _pendingViewZoneIndex = null;
              _skipViewZoneRestore = false;
              _pendingZoomMultiplier = 1.1;
              _viewZoneSheetController?.close();
            } else {
              _zoomByStep(1.1);
            }
            return KeyEventResult.handled;
          }
        }

        if (isMinus ||
            event.logicalKey == LogicalKeyboardKey.minus ||
            event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
          if (_showViewZoneOverlay) {
            _pendingViewZoneIndex = null;
            _skipViewZoneRestore = false;
            _pendingZoomMultiplier = 0.9;
            _viewZoneSheetController?.close();
          } else {
            _zoomByStep(0.9);
          }
          return KeyEventResult.handled;
        }

        final shift = HardwareKeyboard.instance.isShiftPressed;

        if (event.logicalKey == LogicalKeyboardKey.comma && shift) {
          _seekActiveVideoBySeconds(-5);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.period && shift) {
          _seekActiveVideoBySeconds(5);
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.comma) {
          _seekActiveVideoBySeconds(-5);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.period) {
          _seekActiveVideoBySeconds(5);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: DropTarget(
        onDragDone: (details) async {
          for (int i = 0; i < details.files.length; i++) {
            final xfile = details.files[i];
            final file = File(xfile.path);
            if (!file.existsSync()) {
              continue;
            }
            if (_shouldSkipDroppedFile(file)) continue;
            final bytes = await file.readAsBytes();
            if (bytes.isEmpty) {
              continue;
            }
            final fileName = p.basename(file.path);
            final mediaType = getMediaType(file.path);

            final newPhoto = await PhotoSaveHelper.savePhoto(
              fileName: fileName,
              bytes: bytes,
              context: context,
              mediaType: mediaType,
            );
            if (!File(newPhoto.path).existsSync()) {
              continue;
            }

            if (!mounted) return;
            setState(() {
              _addPhotoToCollage(newPhoto, cascadeIndex: i);
            });
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _canvasViewportSize =
                            Size(constraints.maxWidth, constraints.maxHeight);
                        final canvasSize = _currentCanvasSize();
                        final topInset =
                            isIOS && !_isFullscreen ? MediaQuery.of(context).padding.top : 0.0;

                        return Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerPanZoomStart: (_) {
                            if (_overviewMode) return;
                            _isTrackpadPanZoomActive = true;
                          },
                          onPointerPanZoomUpdate: (e) {
                            if (_overviewMode) return;
                            if (_isItemScaleGestureActive &&
                                !_isTrackpadPanZoomActive) {
                              return;
                            }
                            _isTrackpadPanZoomActive = true;
                            if (e.panDelta != Offset.zero) {
                              final next = _transformationController.value
                                  .clone()
                                ..translate(e.panDelta.dx, e.panDelta.dy);
                              _setTransform(next);
                            }
                          },
                          onPointerPanZoomEnd: (_) {
                            if (_overviewMode) return;
                            _isTrackpadPanZoomActive = false;
                            _saveCollageScale(_collageScale);
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              if (_overviewMode) return;
                              _exitEditingMode();
                            },
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(color: Colors.grey[900]),
                                ),
                                Positioned.fill(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: topInset),
                                    child: InteractiveViewer(
                                      transformationController:
                                          _transformationController,
                                      boundaryMargin:
                                          const EdgeInsets.all(999999),
                                      minScale: _minCollageScale,
                                      maxScale: _maxCollageScale,
                                      scaleEnabled: false,
                                      panEnabled: false,
                                      clipBehavior: Clip.none,
                                      onInteractionEnd: (_) {
                                        _setTransform(
                                            _transformationController.value);
                                        _saveCollageScale(_collageScale);
                                      },
                                      child: IgnorePointer(
                                        ignoring: _overviewMode,
                                        child: RepaintBoundary(
                                          key: _collageKey,
                                          child: SizedBox(
                                            width: canvasSize.width,
                                            height: canvasSize.height,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Positioned.fill(
                                                    child: Container(
                                                        color:
                                                            _backgroundColor)),
                                                for (final item in sorted)
                                                  _buildPhotoItem(item),
                                                if (_showViewZoneOverlay)
                                                  Positioned.fill(
                                                    child: CustomPaint(
                                                      painter: _ViewZonesPainter(
                                                        zones: _viewZones,
                                                        colors: _viewZoneColors,
                                                        viewportSize:
                                                            _viewportSize(),
                                                        strokeWidth: math.max(
                                                          1.0,
                                                          2 / (_collageScale ==
                                                                  0
                                                              ? 1
                                                              : _collageScale),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (_showViewZoneOverlay)
                                                  Positioned.fill(
                                                    child: GestureDetector(
                                                      behavior: HitTestBehavior
                                                          .translucent,
                                                      onTap:
                                                          _exitViewZoneOverlay,
                                                    ),
                                                  ),
                                                if (_showViewZoneOverlay)
                                                  ..._buildViewZoneHandles(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                ...videoOverlays,
                                ...rotationOverlays,
                                if (_overviewMode)
                                  const Positioned.fill(
                                    child: ModalBarrier(
                                      dismissible: false,
                                      color: Colors.black,
                                    ),
                                  ),
                                if (_overviewMode) _buildOverviewGrid(_items),
                                if (!isSomePhotoInEditMode &&
                                    (_showForInitDeleteIcon ||
                                        _draggingIndex != null))
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
                                                  size: 60,
                                                  color: Colors.white),
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
                                                onPressed: () async {
                                                  if (!mounted) return;
                                                  setState(() =>
                                                      _showTutorial = false);
                                                  await _markTutorialPassed();
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
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (isSomePhotoInEditMode && editingPhoto != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12 + (isIOS ? bottomInset : 0.0),
                  child: PhotoAdjustmentsPanel(
                    onRotateLeft: () =>
                        setState(() => editingPhoto.rotation -= math.pi / 2),
                    onRotateRight: () =>
                        setState(() => editingPhoto.rotation += math.pi / 2),
                    onFlipX: () =>
                        setState(() => editingPhoto.flipX = !editingPhoto.flipX),
                    onSendBackward: () => _sendItemBackward(editingPhoto),
                    onBringForward: () => _sendItemForward(editingPhoto),
                    onFlipY: null,
                    onDone: () =>
                        _exitEditingMode(),
                    brightness: editingPhoto.brightness,
                    saturation: editingPhoto.saturation,
                    temp: editingPhoto.temp,
                    hue: editingPhoto.hue,
                    contrast: editingPhoto.contrast,
                    opacity: editingPhoto.opacity,
                    onBrightnessChanged: (v) =>
                        setState(() => editingPhoto.brightness = v),
                    onSaturationChanged: (v) =>
                        setState(() => editingPhoto.saturation = v),
                    onTempChanged: (v) =>
                        setState(() => editingPhoto.temp = v),
                    onHueChanged: (v) => setState(() => editingPhoto.hue = v),
                    onContrastChanged: (v) =>
                        setState(() => editingPhoto.contrast = v),
                    onOpacityChanged: (v) =>
                        setState(() => editingPhoto.opacity = v),
                  ),
                )
              else if (_draggingIndex == null) ...[
                if (_isFullscreen)
                  ...[
                    if (Platform.isMacOS)
                      Positioned(
                        left: 12,
                        bottom: 12 + (isIOS ? bottomInset : 0.0),
                        child: MouseRegion(
                          onEnter: (_) {
                            if (!_fullscreenBottomHoverLeft) {
                              setState(() => _fullscreenBottomHoverLeft = true);
                            }
                          },
                          onExit: (_) {
                            if (_fullscreenBottomHoverLeft) {
                              setState(() => _fullscreenBottomHoverLeft = false);
                            }
                          },
                          child: AnimatedOpacity(
                            opacity: (_fullscreenBottomHoverLeft ||
                                    _fullscreenBottomHoverRight)
                                ? 1.0
                                : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: IgnorePointer(
                              ignoring: !(_fullscreenBottomHoverLeft ||
                                  _fullscreenBottomHoverRight),
                              child: _buildFloatingZoomControl(),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 12,
                      bottom: 12 + (isIOS ? bottomInset : 0.0),
                      child: MouseRegion(
                        onEnter: (_) {
                          if (!_fullscreenBottomHoverRight) {
                            setState(() =>
                                _fullscreenBottomHoverRight = true);
                          }
                        },
                        onExit: (_) {
                          if (_fullscreenBottomHoverRight) {
                            setState(() =>
                                _fullscreenBottomHoverRight = false);
                          }
                        },
                        child: AnimatedOpacity(
                          opacity: (_fullscreenBottomHoverLeft ||
                                  _fullscreenBottomHoverRight)
                              ? 1.0
                              : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: IgnorePointer(
                            ignoring: !(_fullscreenBottomHoverLeft ||
                                _fullscreenBottomHoverRight),
                            child: _buildFloatingActionButtons(),
                          ),
                        ),
                      ),
                    ),
                  ]
                else ...[
                  if (Platform.isMacOS)
                    Positioned(
                      left: 12,
                      bottom: 12 + (isIOS ? bottomInset : 0.0),
                      child: _buildFloatingZoomControl(),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 12 + (isIOS ? bottomInset : 0.0),
                    child: _buildFloatingActionButtons(),
                  ),
                ],
              ],
              if (_isFullscreen && _draggingIndex == null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen_exit,
                            color: Colors.white),
                        onPressed: _toggleFullscreen,
                      ),
                    ),
                  ),
                ),
              if (!_isFullscreen && _draggingIndex == null) ...[
                Positioned(
                  left: 12,
                  top: 12,
                  child: SafeArea(
                    bottom: false,
                    child: _buildFloatingHeader(),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: SafeArea(
                    bottom: false,
                    child: _buildTopRightActions(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------
  // Panels
  // ----------------------------

  Widget _buildFloatingZoomControl() {
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 4,
      activeTrackColor: Colors.redAccent,
      inactiveTrackColor: Colors.white,
      thumbColor: Colors.transparent,
      overlayColor: Colors.transparent,
      thumbShape: SliderComponentShape.noThumb,
      overlayShape: SliderComponentShape.noOverlay,
    );

    return SizedBox(
      width: 100,
      child: _HoverAware(
        builder: (hovered) {
          return AnimatedOpacity(
            opacity: hovered ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 150),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hovered)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Zoom',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0.0,
                      max: 1.0,
                      value: _scaleToSliderValue(
                        _collageScale
                            .clamp(_minCollageScale, _maxCollageScale),
                      ),
                      onChanged: (t) {
                        final next = _sliderValueToScale(t);
                        final focal = _canvasViewportSize == Size.zero
                            ? Offset.zero
                            : _canvasViewportSize.center(Offset.zero);
                        _zoomToScale(next, focal);
                        _saveCollageScale(next);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    const iconShadow = [
      Shadow(
        color: Colors.black54,
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ];

    final isHorizontal = Platform.isIOS || Platform.isMacOS;
    final buttons = [
      IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        icon: const Icon(Iconsax.add, color: Colors.white, shadows: iconShadow),
        tooltip: 'Add photo (A)',
        onPressed: _showAllPhotosSheet,
      ),
      if (!Platform.isIOS)
        GestureDetector(
          onLongPress: _showViewZonePanel,
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            icon: const Icon(
              Icons.crop_free,
              color: Colors.white,
              shadows: iconShadow,
            ),
            tooltip: 'Add view zone (Z, hold for list)',
            onPressed: _addViewZone,
          ),
        ),
      IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        icon:
            const Icon(Icons.grid_view, color: Colors.white, shadows: iconShadow),
        tooltip: 'Overview mode (O)',
        onPressed: _toggleOverviewMode,
      ),
      IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        icon: const Icon(Iconsax.colorfilter,
            color: Colors.white, shadows: iconShadow),
        tooltip: 'Change background color (B)',
        onPressed: _showColorPickerDialog,
      ),
      IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        icon: const Icon(Iconsax.save_2, color: Colors.white, shadows: iconShadow),
        tooltip: 'Save collage (S)',
        onPressed: _onSaveCollageToDb,
      ),
      IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        icon: Icon(
          _isPrivate ? Icons.lock : Icons.lock_open,
          color: _isPrivate ? Colors.amber : Colors.white,
          shadows: iconShadow,
        ),
        tooltip:
            _isPrivate ? 'Private collage (P)' : 'Public collage (P)',
        onPressed: () => setState(() => _isPrivate = !_isPrivate),
      ),
      IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        icon:
            const Icon(Iconsax.image, color: Colors.green, shadows: iconShadow),
        tooltip: 'Save collage as image (I)',
        onPressed: _onGenerateCollage,
      ),
      IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        icon: const Icon(Icons.close, color: Colors.red, shadows: iconShadow),
        tooltip: 'Cancel collage',
        onPressed: () => Navigator.pop(context),
      ),
    ];

    if (isHorizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            if (i != 0) const SizedBox(width: 6),
            buttons[i],
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final button in buttons) button,
      ],
    );
  }

  Widget _buildFloatingHeader() {
    const textShadow = [
      Shadow(
        color: Colors.black54,
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ];

    final title =
        '${widget.initialCollage?.title ?? "Collage"} (${_items.length} images)';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
          icon: const Icon(Icons.arrow_back, color: Colors.white, shadows: textShadow),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            shadows: textShadow,
          ),
        ),
      ],
    );
  }

  Widget _buildTopRightActions() {
    const iconShadow = [
      Shadow(
        color: Colors.black54,
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
          tooltip: 'Help / Info',
          icon: const Icon(Icons.info_outline, color: Colors.white, shadows: iconShadow),
          onPressed: _showHelp,
        ),
        const SizedBox(width: 6),
        if (!Platform.isIOS) ...[
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            tooltip: 'Open New Window',
            icon:
                const Icon(Icons.window, color: Colors.white, shadows: iconShadow),
            onPressed: () {
              WindowService.openWindow(
                route: '/my_collages',
                args: {},
                title: 'Refma — Collage',
              );
            },
          ),
          const SizedBox(width: 6),
        ],
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
          tooltip: 'Toggle Fullscreen',
          icon:
              const Icon(Icons.fullscreen, color: Colors.white, shadows: iconShadow),
          onPressed: _toggleFullscreen,
        ),
      ],
    );
  }

  // ----------------------------
  // Item building
  // ----------------------------

  Widget _buildPhotoItem(CollagePhotoState item) {
    final w = item.baseWidth * item.scale;
    final h = item.baseHeight * item.scale;

    return Positioned(
      key: ValueKey(item.id),
      left: item.offset.dx,
      top: item.offset.dy,
      child: Builder(
        builder: (itemCtx) {
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _tapDrag.pointerDown(item.id, e.position),
            onPointerMove: (e) => _tapDrag.pointerMove(item.id, e.position),
            onPointerUp: (_) {
              final isTap = _tapDrag.pointerUp(item.id);
              if (_deleteHover && _draggingIndex != null) {
                setState(() {
                  _controller.removeAt(_draggingIndex!);
                  _draggingIndex = null;
                  _deleteHover = false;
                  _isItemScaleGestureActive = false;
                  item.baseScaleOnGesture = null;
                  item.baseOffsetOnGesture = null;
                });
                return;
              }
              if (_isItemScaleGestureActive || _draggingIndex != null) {
                setState(() {
                  _isItemScaleGestureActive = false;
                  _draggingIndex = null;
                  _deleteHover = false;
                  item.baseScaleOnGesture = null;
                  item.baseOffsetOnGesture = null;
                });
              }
              if (isTap) {
                _bringToFront(item);
              }
            },
            child: GestureDetector(
              onTap: () {
                if (_overviewMode) {
                  final tappedIndex = _items.indexOf(item);
                  _exitOverviewLayout(bringToFrontIndex: tappedIndex);
                } else {
                  setState(() {
                    _controller.clearEditing();
                    _controller.bringToFront(item);
                    _maxZIndex = _controller.maxZIndex;
                    _activeItemIndex = _items.indexOf(item);
                  });
                }
              },
              onLongPress: () {
                setState(() {
                  vibrate();
                  _controller.setEditing(item, true);
                });
              },
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: (_) {
                  setState(() {
                    _isItemScaleGestureActive = true;
                    item.baseScaleOnGesture = null;
                    item.baseOffsetOnGesture = null;
                  });
                },
                onScaleUpdate: (details) {
                  if (_controlsHover[item.id] == true) return;

                  const double scaleEps = 0.002;
                  final bool isScaling = (details.scale - 1.0).abs() > scaleEps ||
                      details.pointerCount >= 2;

                  setState(() {
                    if (isScaling) {
                      item.baseScaleOnGesture ??= item.scale;
                      item.baseOffsetOnGesture ??= item.offset;

                      _draggingIndex = null;
                      _deleteHover = false;

                      final box = itemCtx.findRenderObject() as RenderBox?;
                      final localFocal = box != null
                          ? box.globalToLocal(details.focalPoint)
                          : details.localFocalPoint;

                      final baseScale = item.baseScaleOnGesture ?? item.scale;
                      final nextScale =
                          math.max(0.001, baseScale * details.scale);
                      final baseOffset = item.baseOffsetOnGesture ?? item.offset;
                      final focalCanvas = baseOffset + localFocal;
                      final basePoint = (focalCanvas - baseOffset) / baseScale;
                      final nextOffset = focalCanvas - basePoint * nextScale;

                      item.scale = nextScale;
                      item.offset = nextOffset;
                      _clampItemOffset(item);
                      return;
                    }

                    if (_draggingIndex == null) {
                      _draggingIndex = _items.indexOf(item);
                      _scheduleDeleteRectUpdate();
                    }

                    if (item.isEditing) {
                      item.internalOffset += details.focalPointDelta;
                    } else {
                      item.offset += details.focalPointDelta;
                      _clampItemOffset(item);
                    }

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
                      _controller.removeAt(_draggingIndex!);
                    }
                    _draggingIndex = null;
                    _deleteHover = false;
                    _isItemScaleGestureActive = false;
                    item.baseScaleOnGesture = null;
                    item.baseOffsetOnGesture = null;
                    _clampItemOffset(item);
                  });
                  _tapDrag.clear(item.id);
                },
                child: Transform(
                  transform: () {
                    final m = Matrix4.identity()
                      ..translate(w / 2, h / 2)
                      ..rotateZ(item.rotation)
                      ..scale(item.flipX ? -1.0 : 1.0, 1.0)
                      ..translate(-w / 2, -h / 2);
                    return m;
                  }(),
                  child: _buildEditableContent(item, w, h),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _bringToFront(CollagePhotoState item) {
    if (_overviewMode) return;
    setState(() {
      _controller.bringToFront(item);
      _maxZIndex = _controller.maxZIndex;
      _activeItemIndex = _items.indexOf(item);
    });
  }

  void _sendItemBackward(CollagePhotoState item) {
    if (_overviewMode) return;
    setState(() {
      _controller.sendBackward(item);
    });
  }

  void _sendItemForward(CollagePhotoState item) {
    if (_overviewMode) return;
    setState(() {
      _controller.sendForward(item);
    });
  }

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
      item.contrast,
      item.temp,
      item.hue,
    );

    final fullPath = _resolvePhotoPath(item.photo);
    final isVideo = item.photo.mediaType == 'video';

    // ВАЖНО: здесь НЕ создаём state в build “на лету” для не-видео.
    // Для видео VideoUi должен быть создан при init/add.
    final VideoUi? uiState = isVideo ? _videoStates[item.id] : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: item.cropRect.width,
            heightFactor: item.cropRect.height,
            child: Transform.translate(
              offset: Offset(-cropLeft, -cropTop) + item.internalOffset,
              child: Opacity(
                opacity: item.opacity.clamp(0.0, 1.0),
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
                                  'vs-${item.id}-${(uiState?.duration.inMilliseconds ?? 0)}'),
                              filePath: fullPath,
                              startTime: fracToTime(
                                  uiState?.duration ?? Duration.zero,
                                  uiState?.startFrac ?? 0.0),
                              endTime: (uiState == null ||
                                      uiState.duration == Duration.zero)
                                  ? null
                                  : fracToTime(
                                      uiState.duration, uiState.endFrac),
                              volume: uiState?.volume ?? 0.0,
                              speed: uiState?.speed ?? 1.0,
                              autoplay: uiState != null &&
                                  uiState.duration != Duration.zero,
                              onDuration: (d) {
                                final ui = _videoStates[item.id];
                                if (ui == null) return;
                                setState(() => ui.duration = d);
                              },
                              onPosition: (p) {
                                final ui = _videoStates[item.id];
                                if (ui == null) return;
                                setState(() =>
                                    ui.posFrac = timeToFrac(ui.duration, p));
                              },
                              externalPositionFrac: uiState?.posFrac ?? 0.0,
                              externalSeekId: uiState?.seekRequestId ?? 0,
                              onControllerReady: (c) {
                                final ui = _videoStates[item.id];
                                if (ui == null) return;
                                setState(() => ui.controller = c);
                              },
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
        ),
        if (item.isEditing) ...[
          Positioned.fill(
            child: CustomPaint(
              painter: _CropBorderPainter(
                strokeWidth: math.max(0.5, 2 / (_collageScale == 0 ? 1 : _collageScale)),
              ),
            ),
          ),
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

  Widget _buildOverviewGrid(List<CollagePhotoState> items) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          const padding = 12.0;
          const spacing = 10.0;
          const targetCell = 180.0;

          final availableWidth = viewport.width - padding * 2;
          final rawColumns =
              ((availableWidth + spacing) / (targetCell + spacing)).floor();
          final columns = rawColumns.clamp(1, 6);
          final cellWidth = (availableWidth - spacing * (columns - 1)) / columns;
          final cellSize = cellWidth;
          final rows = (items.length / columns).ceil();
          final totalHeight =
              padding * 2 + rows * cellSize + spacing * (rows - 1);

          final children = <Widget>[];
          for (int i = 0; i < items.length; i++) {
            final item = items[i];
            final col = i % columns;
            final row = i ~/ columns;
            final dx = padding + col * (cellSize + spacing);
            final dy = padding + row * (cellSize + spacing);

            final baseW = item.baseWidth * item.scale;
            final baseH = item.baseHeight * item.scale;
            final fitScale = baseW <= 0 || baseH <= 0
                ? 1.0
                : math.min(cellSize / baseW, cellSize / baseH);
            final overviewScale = item.scale * fitScale;
            final w = item.baseWidth * overviewScale;
            final h = item.baseHeight * overviewScale;
            final offset = Offset(dx + (cellSize - w) / 2,
                dy + (cellSize - h) / 2);

            children.add(
              Positioned(
                left: offset.dx,
                top: offset.dy,
                child: GestureDetector(
                  onTap: () {
                    final indexInItems = _items.indexOf(item);
                    setState(() {
                      _activeItemIndex = indexInItems;
                    });
                    _exitOverviewLayout(bringToFrontIndex: indexInItems);
                  },
                  child: Transform(
                    transform: () {
                      final m = Matrix4.identity()
                        ..translate(w / 2, h / 2)
                        ..rotateZ(item.rotation)
                        ..scale(item.flipX ? -1.0 : 1.0, 1.0)
                        ..translate(-w / 2, -h / 2);
                      return m;
                    }(),
                    child: _buildEditableContent(item, w, h),
                  ),
                ),
              ),
            );
          }

          return Container(
            color: Colors.black,
            child: Scrollbar(
              controller: _overviewScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _overviewScrollController,
                primary: false,
                child: SizedBox(
                  height: totalHeight,
                  width: viewport.width,
                  child: Stack(children: children),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _rotationToSliderValue(double rotation) {
    const min = -math.pi / 2;
    const max = math.pi / 2;
    return rotation.clamp(min, max);
  }

  double _scaleToSliderValue(double scale) {
    final min = _minCollageScale;
    final max = _maxCollageScale;
    final clamped = scale.clamp(min, max);
    final logMin = math.log(min);
    final logMax = math.log(max);
    return (math.log(clamped) - logMin) / (logMax - logMin);
  }

  double _sliderValueToScale(double t) {
    final min = _minCollageScale;
    final max = _maxCollageScale;
    final logMin = math.log(min);
    final logMax = math.log(max);
    final clampedT = t.clamp(0.0, 1.0);
    return math.exp(logMin + (logMax - logMin) * clampedT);
  }

  bool _handleViewZoneHotkeys(KeyDownEvent event) {
    final label = event.logicalKey.keyLabel;
    final digit = int.tryParse(label);
    if (digit == null) return false;
    final index = digit == 0 ? 9 : digit - 1;
    if (index < 0 || index >= _maxViewZones) return false;
    if (HardwareKeyboard.instance.isShiftPressed) {
      if (_showViewZoneOverlay) {
        _pendingZoomMultiplier = null;
        _pendingViewZoneIndex = null;
        _skipViewZoneRestore = false;
        _setZoneAtIndex(index);
        _viewZoneSheetController?.close();
      } else {
        _setZoneAtIndex(index);
      }
      return true;
    }
    if (_viewZones[index] == null) return false;
    if (_showViewZoneOverlay) {
      _pendingZoomMultiplier = null;
      _pendingViewZoneIndex = index;
      _skipViewZoneRestore = true;
      _viewZoneSheetController?.close();
    } else {
      _applyViewZone(index);
    }
    return true;
  }

  void _ensureDefaultViewZone() {
    if (_viewZones.any((z) => z != null)) return;
    _setZoneAtIndex(0);
  }

  _ViewZone _captureCurrentViewZone() {
    final translation =
        TransformMath.getTranslation(_transformationController.value);
    final scale = TransformMath.getScale(_transformationController.value);
    return _ViewZone(translation: translation, scale: scale);
  }

  void _addViewZone() {
    final index = _viewZones.indexWhere((z) => z == null);
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum view zones reached')),
      );
      return;
    }
    _setZoneAtIndex(index);
  }

  void _setZoneAtIndex(int index) {
    if (index < 0 || index >= _maxViewZones) return;
    final zone = _captureCurrentViewZone();
    setState(() {
      _viewZones[index] = zone;
      _activeViewZoneIndex = index;
    });
  }

  void _applyViewZone(int index) {
    if (index < 0 || index >= _viewZones.length) return;
    final zone = _viewZones[index];
    if (zone == null) return;
    _setTransform(
      TransformMath.matrixFromOffsetScale(zone.translation, zone.scale),
    );
    setState(() {
      _activeViewZoneIndex = index;
    });
  }

  void _showViewZonePanel() {
    _ensureDefaultViewZone();
    if (_viewZones.every((z) => z == null)) return;
    _ensureViewZoneState();
    _preViewZoneMatrix = _transformationController.value.clone();
    setState(() => _showViewZoneOverlay = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showViewZoneOverlay) return;
      final containScale = _containScaleForCanvas();
      final focal = _viewportSize().center(Offset.zero);
      if (containScale >= _minCollageScale) {
        _setTransform(_fitCanvasToViewportMatrix());
      } else {
        _zoomToScale(_minCollageScale, focal);
      }
    });
    final state = _scaffoldKey.currentState;
    if (state == null) return;
    final controller = state.showBottomSheet(
      (sheetContext) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return Container(
              color: Colors.black87,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (int i = 0; i < _maxViewZones; i++)
                    _ViewZoneChip(
                      index: i,
                      isActive: i == _activeViewZoneIndex,
                      color: _viewZoneColors[i % _viewZoneColors.length],
                      isSet: _viewZones[i] != null,
                      onTap: () {
                        if (_viewZones[i] == null) return;
                        _pendingViewZoneIndex = i;
                        _skipViewZoneRestore = true;
                        Navigator.of(sheetContext).pop();
                      },
                      onDelete: () {
                        setState(() {
                          _viewZones[i] = null;
                          if (_activeViewZoneIndex == i) {
                            _activeViewZoneIndex = null;
                          }
                        });
                        sheetSetState(() {});
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
    controller.closed.whenComplete(() {
      if (!mounted) return;
      setState(() {
        _showViewZoneOverlay = false;
        if (_skipViewZoneRestore && _pendingViewZoneIndex != null) {
          final idx = _pendingViewZoneIndex!;
          _skipViewZoneRestore = false;
          _pendingViewZoneIndex = null;
          _pendingZoomMultiplier = null;
          _preViewZoneMatrix = null;
          _applyViewZone(idx);
        } else {
          if (_preViewZoneMatrix != null) {
            _setTransform(_preViewZoneMatrix!);
          }
          _preViewZoneMatrix = null;
          _skipViewZoneRestore = false;
          _pendingViewZoneIndex = null;
          final zoom = _pendingZoomMultiplier;
          _pendingZoomMultiplier = null;
          if (zoom != null) {
            _zoomByStep(zoom);
          }
        }
        _viewZoneSheetController = null;
      });
    });
    _viewZoneSheetController = controller;
  }

  void _exitViewZoneOverlay() {
    if (!_showViewZoneOverlay) return;
    setState(() {
      _showViewZoneOverlay = false;
      if (_preViewZoneMatrix != null) {
        _setTransform(_preViewZoneMatrix!);
      }
      _preViewZoneMatrix = null;
      _pendingViewZoneIndex = null;
      _pendingZoomMultiplier = null;
      _skipViewZoneRestore = false;
    });
    _viewZoneSheetController?.close();
    _viewZoneSheetController = null;
  }

  Rect _zoneCanvasRect(_ViewZone zone) {
    final viewport = _viewportSize();
    if (viewport.width <= 0 || viewport.height <= 0) return Rect.zero;
    final matrix =
        TransformMath.matrixFromOffsetScale(zone.translation, zone.scale);
    final inv = Matrix4.inverted(matrix);
    final topLeft = inv.transform3(Vector3(0, 0, 0));
    final bottomRight =
        inv.transform3(Vector3(viewport.width, viewport.height, 0));
    return Rect.fromPoints(
      Offset(topLeft.x, topLeft.y),
      Offset(bottomRight.x, bottomRight.y),
    );
  }

  Rect _zoneScreenRect(_ViewZone zone) {
    final canvasRect = _zoneCanvasRect(zone);
    if (canvasRect.isEmpty) return Rect.zero;
    final topLeft = MatrixUtils.transformPoint(
      _transformationController.value,
      canvasRect.topLeft,
    );
    final bottomRight = MatrixUtils.transformPoint(
      _transformationController.value,
      canvasRect.bottomRight,
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  void _startViewZoneDrag(int index, Offset screenPos) {
    _draggingViewZoneIndex = index;
    _viewZoneDragLastScreen = screenPos;
  }

  void _updateViewZoneDrag(Offset screenPos) {
    if (_draggingViewZoneIndex == null) return;
    final last = _viewZoneDragLastScreen;
    if (last == null) return;
    final deltaScreen = screenPos - last;
    if (deltaScreen == Offset.zero) return;

    final inv = Matrix4.inverted(_transformationController.value);
    final c0 = inv.transform3(Vector3(0, 0, 0));
    final c1 = inv.transform3(Vector3(deltaScreen.dx, deltaScreen.dy, 0));
    final deltaCanvas = Offset(c1.x - c0.x, c1.y - c0.y);

    final index = _draggingViewZoneIndex!;
    final zone = _viewZones[index];
    if (zone == null) return;
    final nextTranslation = zone.translation - deltaScreen;

    setState(() {
      _viewZones[index] = _ViewZone(
        translation: nextTranslation,
        scale: zone.scale,
      );
      _viewZoneDragLastScreen = screenPos;
    });
  }

  void _endViewZoneDrag() {
    _draggingViewZoneIndex = null;
    _viewZoneDragLastScreen = null;
  }

  void _startViewZoneResize(int index, Offset screenPos) {
    final zone = _viewZones[index];
    if (zone == null) return;
    _resizingViewZoneIndex = index;
    _viewZoneResizeStartScreenPos = screenPos;
    _viewZoneResizeStartScreenRect = _zoneScreenRect(zone);
    _viewZoneResizeAnchorTopLeft = _zoneCanvasRect(zone).topLeft;
    _viewZoneResizeStartScale = zone.scale;
  }

  void _updateViewZoneResize(Offset screenPos) {
    final index = _resizingViewZoneIndex;
    final startPos = _viewZoneResizeStartScreenPos;
    final startRect = _viewZoneResizeStartScreenRect;
    final anchor = _viewZoneResizeAnchorTopLeft;
    final startScale = _viewZoneResizeStartScale;
    if (index == null ||
        startPos == null ||
        startRect == null ||
        anchor == null ||
        startScale == null) {
      return;
    }
    final delta = screenPos - startPos;
    if (delta == Offset.zero) return;

    final nextWidth = math.max(40.0, startRect.width + delta.dx);
    final nextHeight = math.max(40.0, startRect.height + delta.dy);
    final factorW = nextWidth / startRect.width;
    final factorH = nextHeight / startRect.height;
    final factor = math.max(factorW, factorH);
    if (factor <= 0) return;

    final nextScale = (startScale / factor).clamp(0.001, _maxCollageScale);
    final nextTranslation = Offset(
      -anchor.dx * nextScale,
      -anchor.dy * nextScale,
    );

    setState(() {
      _viewZones[index] = _ViewZone(
        translation: nextTranslation,
        scale: nextScale,
      );
    });
  }

  void _endViewZoneResize() {
    _resizingViewZoneIndex = null;
    _viewZoneResizeStartScreenPos = null;
    _viewZoneResizeStartScreenRect = null;
    _viewZoneResizeAnchorTopLeft = null;
    _viewZoneResizeStartScale = null;
  }

  Rect _getItemScreenRect(CollagePhotoState item) {
    final w = item.baseWidth * item.scale;
    final h = item.baseHeight * item.scale;
    final topLeft =
        MatrixUtils.transformPoint(_transformationController.value, item.offset);
    final bottomRight = MatrixUtils.transformPoint(
      _transformationController.value,
      item.offset + Offset(w, h),
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  List<Widget> _buildViewZoneHandles() {
    const double handleSize = 18;
    final widgets = <Widget>[];
    for (int i = 0; i < _viewZones.length; i++) {
      final zone = _viewZones[i];
      if (zone == null) continue;
      final rect = _zoneCanvasRect(zone);
      if (rect.isEmpty) continue;
      final color = _viewZoneColors.isEmpty
          ? Colors.white
          : _viewZoneColors[i % _viewZoneColors.length];
      widgets.add(
        Positioned(
          left: rect.right - handleSize / 2,
          top: rect.top - handleSize / 2,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (d) => _startViewZoneDrag(i, d.globalPosition),
            onPanUpdate: (d) => _updateViewZoneDrag(d.globalPosition),
            onPanEnd: (_) => _endViewZoneDrag(),
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(
                Icons.drag_indicator,
                size: 12,
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      widgets.add(
        Positioned(
          left: rect.center.dx - handleSize / 2,
          top: rect.bottom - handleSize / 2,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (d) => _startViewZoneResize(i, d.globalPosition),
            onPanUpdate: (d) => _updateViewZoneResize(d.globalPosition),
            onPanEnd: (_) => _endViewZoneResize(),
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: color.withOpacity(0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(
                Icons.open_in_full,
                size: 12,
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  String _resolvePhotoPath(Photo photo) {
    if (photo.path.isNotEmpty) {
      final direct = File(photo.path);
      if (direct.existsSync()) return photo.path;
    }
    return PhotoPathHelper().getFullPath(photo.fileName);
  }

  Widget _buildVideoControlsViewportOverlay(
    CollagePhotoState item,
    VideoUi uiState,
  ) {
    final rect = _getItemScreenRect(item);
    if (rect.isEmpty) return const SizedBox.shrink();

    final isActive =
        _activeItemIndex != null && _items.indexOf(item) == _activeItemIndex;
    final visible = (_videoHover[item.id] == true) ||
        (_controlsHover[item.id] == true) ||
        item.isEditing ||
        isActive;

    return Positioned(
      left: rect.left,
      top: rect.bottom - _videoControlsHeight,
      width: rect.width,
      child: Builder(
        builder: (context) {
          final baseVisible = (_videoHover[item.id] == true) ||
              (_controlsHover[item.id] == true) ||
              item.isEditing ||
              isActive;
          final controlsHover = _controlsHover[item.id] == true;
          final show = baseVisible || controlsHover;

          return MouseRegion(
            onEnter: (_) =>
                setState(() => _controlsHover[item.id] = true),
            onExit: (_) => setState(() => _controlsHover[item.id] = false),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: show ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !show,
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        uiState.posFrac = f.clamp(0.0, 1.0);
                        uiState.seekRequestId++;
                      }),
                      onChangeRange: (rv) => setState(() {
                        uiState.startFrac = rv.start;
                        uiState.endFrac = rv.end;
                      }),
                      onChangeVolume: (v) =>
                          setState(() => uiState.volume = v),
                      onChangeSpeed: (s) =>
                          setState(() => uiState.speed = s),
                      totalDuration: uiState.duration,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRotationSliderViewportOverlay(CollagePhotoState item) {
    final rect = _getItemScreenRect(item);
    if (rect.isEmpty) return const SizedBox.shrink();

    final sliderWidth = (rect.width * 0.9).clamp(80.0, 160.0);

    return Positioned(
      left: rect.left + (rect.width - sliderWidth) / 2,
      top: rect.bottom + 6,
      width: sliderWidth,
      child: _RotationSlider(
        width: sliderWidth,
        value: _rotationToSliderValue(item.rotation),
        onChanged: (v) => setState(() => item.rotation = v),
      ),
    );
  }

  @override
  void dispose() {
    if (Platform.isIOS && _isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      WakelockPlus.disable();
    }
    _cancelArrowRepeat();
    _transformationController.removeListener(_handleTransformChanged);
    _transformationController.dispose();
    _overviewScrollController.dispose();
    _focusNode.dispose();

    // Dispose video controllers safely
    for (final ui in _videoStates.values) {
      ui.disposeControllerIfAny();
    }

    super.dispose();
  }
}

////////////////////////////////////////////////////////////////
/// SECTION: Painters
////////////////////////////////////////////////////////////////

class _CropBorderPainter extends CustomPainter {
  final double strokeWidth;

  const _CropBorderPainter({required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRect(r, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ViewZonesPainter extends CustomPainter {
  final List<_ViewZone?> zones;
  final List<Color> colors;
  final Size viewportSize;
  final double strokeWidth;

  const _ViewZonesPainter({
    required this.zones,
    required this.colors,
    required this.viewportSize,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (zones.isEmpty) return;
    for (int i = 0; i < zones.length; i++) {
      final zone = zones[i];
      if (zone == null) continue;
      final color = colors.isEmpty
          ? Colors.white
          : colors[i % colors.length];
      final rect = _canvasRectForZone(zone, viewportSize);
      if (rect.isEmpty) continue;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawRect(rect, paint);
    }
  }

  Rect _canvasRectForZone(_ViewZone zone, Size viewport) {
    if (viewport.width <= 0 || viewport.height <= 0) return Rect.zero;
    final matrix =
        TransformMath.matrixFromOffsetScale(zone.translation, zone.scale);
    final inv = Matrix4.inverted(matrix);
    final topLeft = inv.transform3(Vector3(0, 0, 0));
    final bottomRight =
        inv.transform3(Vector3(viewport.width, viewport.height, 0));
    return Rect.fromPoints(
      Offset(topLeft.x, topLeft.y),
      Offset(bottomRight.x, bottomRight.y),
    );
  }

  @override
  bool shouldRepaint(covariant _ViewZonesPainter oldDelegate) {
    return oldDelegate.zones != zones ||
        oldDelegate.colors != colors ||
        oldDelegate.viewportSize != viewportSize ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _RotationSlider extends StatefulWidget {
  static const double _min = -math.pi / 2;
  static const double _max = math.pi / 2;

  final double value;
  final double width;
  final ValueChanged<double> onChanged;

  const _RotationSlider({
    super.key,
    required this.width,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_RotationSlider> createState() => _RotationSliderState();
}

class _RotationSliderState extends State<_RotationSlider> {
  bool _isDragging = false;
  double _lastValue = 0.0;

  @override
  void didUpdateWidget(covariant _RotationSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 2,
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white,
      thumbColor: Colors.white70,
      overlayColor: Colors.transparent,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
      overlayShape: SliderComponentShape.noOverlay,
    );

    final angleDeg = (_lastValue * 180 / math.pi).round();

    return SizedBox(
      width: widget.width,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (_isDragging)
            Positioned(
              top: -16,
              child: Text(
                '$angleDeg°',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(999),
            ),
            child: SliderTheme(
              data: sliderTheme,
              child: Slider(
                min: _RotationSlider._min,
                max: _RotationSlider._max,
                value: widget.value
                    .clamp(_RotationSlider._min, _RotationSlider._max),
                onChangeStart: (v) =>
                    setState(() => _isDragging = true),
                onChangeEnd: (v) => setState(() => _isDragging = false),
                onChanged: (v) {
                  setState(() => _lastValue = v);
                  widget.onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewZone {
  final Offset translation;
  final double scale;

  const _ViewZone({
    required this.translation,
    required this.scale,
  });
}

class _ViewZoneChip extends StatelessWidget {
  final int index;
  final bool isActive;
  final Color color;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ViewZoneChip({
    required this.index,
    required this.isActive,
    required this.color,
    required this.isSet,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final label = index == 9 ? '0' : '${index + 1}';
    return InkWell(
      onTap: isSet ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Tooltip(
        message: isSet ? '' : 'Shift+$label to add',
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSet
                ? ((isActive && isSet) ? color.withOpacity(0.35) : Colors.white10)
                : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSet
                  ? ((isActive && isSet) ? color : Colors.white24)
                  : Colors.white12,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSet ? Colors.white : Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSet) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child:
                        const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
          foregroundDecoration: isSet
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color, width: 2),
                )
              : null,
        ),
      ),
    );
  }
}

class _ViewZoneAddChip extends StatelessWidget {
  final int nextIndex;
  final VoidCallback onTap;

  const _ViewZoneAddChip({
    required this.nextIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = '+${nextIndex + 1}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HoverAware extends StatefulWidget {
  final Widget Function(bool hovered) builder;

  const _HoverAware({required this.builder});

  @override
  State<_HoverAware> createState() => _HoverAwareState();
}

class _HoverAwareState extends State<_HoverAware> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(_hovered),
    );
  }
}
