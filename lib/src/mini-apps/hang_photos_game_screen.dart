// lib/src/presentation/widgets/hang_photos_game_screen.dart
import 'dart:io';
import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

// Импорт блока тегов
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';

class HangPhotosGameScreen extends StatefulWidget {
  const HangPhotosGameScreen({Key? key}) : super(key: key);

  @override
  State<HangPhotosGameScreen> createState() => _HangPhotosGameScreenState();
}

enum _GamePhase { swing, burst, moveToWall, glow, result }

class _PlacedPhoto {
  final Photo photo;
  final Offset center; // центр слота на стене
  final double angleRad;

  _PlacedPhoto({
    required this.photo,
    required this.center,
    required this.angleRad,
  });
}

class _HangPhotosGameScreenState extends State<HangPhotosGameScreen>
    with TickerProviderStateMixin {
  // ---------- base fields ----------
  final Random _rand = Random();

  /// Все доступные (отфильтрованные) фото для игры
  List<Photo> _allGameCandidates = [];

  /// Текущий набор фото для конкретного забега (подборки)
  List<Photo> _gamePhotos = [];

  bool _initializedFromBloc = false;
  int _currentIndex = 0;

  final List<_PlacedPhoto> _placed = [];
  final List<double> _anglesDeg = [];

  _GamePhase _phase = _GamePhase.swing;

  // ---------- animations ----------
  late final AnimationController _swingCtrl;
  late final AnimationController _burstCtrl;
  late final AnimationController _moveCtrl;
  late final AnimationController _slotGlowCtrl;
  late final AnimationController _winCtrl;

  // состояние большой фотки
  double _currentAngleRad = 0.0;
  double _capturedAngleRad = 0.0; // угол в момент тапа
  double _baseSwingAmplitudeRad = 20 * pi / 180; // 20°

  // полёт к стене
  Offset _bigCenter = Offset.zero;
  Offset _slotCenter = Offset.zero;
  double _bigScale = 1.0;
  double _bigScaleStart = 1.0;
  double _bigScaleEnd = 0.45;

  // цвет вспышки
  Color _burstColor = Colors.white;

  // glow вокруг последнего снимка
  Offset? _lastPlacedCenter;
  Color _lastPlacedGlowColor = Colors.transparent;

  @override
  void initState() {
    super.initState();

    // маятник — чуть медленнее
    _swingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1860),
    )..addListener(_onSwingTick);
    _swingCtrl.repeat(reverse: true);

    // вспышка
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )
      ..addListener(() {
        if (!mounted) return;
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _startMoveToWall();
        }
      });

    // полёт к стене
    _moveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )
      ..addListener(() {
        if (!mounted) return;
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onMoveToWallCompleted();
        }
      });

    // свечение вокруг слота — 0.4 c
    _slotGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )
      ..addListener(() {
        if (!mounted) return;
        setState(() {});
      })
      ..addStatusListener((status) {
        if (!mounted) return;
        if (status == AnimationStatus.completed) {
          // по завершении свечения:
          // если это была последняя фотка — результат,
          // иначе — новый забег с новой фоткой
          if (_currentIndex >= _gamePhotos.length - 1) {
            setState(() {
              _phase = _GamePhase.result;
              _lastPlacedCenter = null;
              _lastPlacedGlowColor = Colors.transparent;
            });
          } else {
            setState(() {
              _currentIndex++;
              _phase = _GamePhase.swing;
              _bigScale = 1.0;
              _currentAngleRad = 0.0;
              _lastPlacedCenter = null;
              _lastPlacedGlowColor = Colors.transparent;
            });
            _swingCtrl.repeat(reverse: true);
          }
        }
      });

    // победная анимация на экране результата
    _winCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void dispose() {
    _swingCtrl.dispose();
    _burstCtrl.dispose();
    _moveCtrl.dispose();
    _slotGlowCtrl.dispose();
    _winCtrl.dispose();
    super.dispose();
  }

  // ---------- выбор нового набора фоток ----------
  void _resetGameWithNewRandomPhotos() {
    if (_allGameCandidates.isEmpty) return;

    // делаем копию, чтобы не портить исходный список
    final pool = List<Photo>.from(_allGameCandidates);
    pool.shuffle(_rand);

    final count = pool.length >= 6 ? 6 : pool.length;
    _gamePhotos = pool.take(count).toList();

    _placed.clear();
    _anglesDeg.clear();
    _currentIndex = 0;
    _phase = _GamePhase.swing;
    _bigScale = 1.0;
    _currentAngleRad = 0.0;
    _lastPlacedCenter = null;
    _lastPlacedGlowColor = Colors.transparent;
    _swingCtrl.repeat(reverse: true);

    setState(() {});
  }

  // ---------- init photos from PhotoBloc + TagBloc ----------
  void _initFromBlocIfNeeded(
    BuildContext context,
    PhotoState photoState,
    TagState tagState,
  ) {
    if (_initializedFromBloc) return;
    if (photoState is! PhotoLoaded) return;
    if (photoState.photos.isEmpty) return;

    // ищем id тега "Not Ref" (case-insensitive)
    final Set<String> notRefTagIds = {};
    if (tagState is TagLoaded) {
      for (final Tag t in tagState.tags) {
        if (t.name.trim().toLowerCase() == 'not ref') {
          notRefTagIds.add(t.id);
        }
      }
    }

    _initializedFromBloc = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // берём только изображения без тега "Not Ref"
      final filtered = photoState.photos.where((p) {
        if (p.mediaType != 'image') return false;
        if (p.fileName.isEmpty && p.path.isEmpty) return false;

        if (notRefTagIds.isEmpty) {
          // если теги ещё не пришли — не фильтруем
          return true;
        }

        final ids = (p.tagIds ?? <String>[]);
        return !ids.any(notRefTagIds.contains);
      }).toList();

      _allGameCandidates = filtered;

      // каждый вход на экран — новый набор
      _resetGameWithNewRandomPhotos();
    });
  }

  // ---------- pendulum swing ----------
  void _onSwingTick() {
    if (!mounted) return;
    if (_phase != _GamePhase.swing) return;
    if (_gamePhotos.isEmpty || _currentIndex >= _gamePhotos.length) return;

    final v = _swingCtrl.value; // 0..1
    final angle = sin(v * 2 * pi); // -1..1
    setState(() {
      _currentAngleRad = angle * _baseSwingAmplitudeRad;
    });
  }

  // ---------- slot position on wall ----------
  Offset _computeSlotCenter(Size size, int index) {
    // 3x2 вокруг центра
    final center = Offset(size.width / 2, size.height / 2);

    const double gridX = 150;
    const double gridY = 130;

    final row = index ~/ 3; // 0 or 1
    final col = index % 3; // 0..2

    final dx = (col - 1) * gridX;
    final dy = (row == 0 ? -1.0 : 1.0) * gridY;

    // лёгкий джиттер
    final jitterX = _rand.nextDouble() * 16 - 8;
    final jitterY = _rand.nextDouble() * 10 - 5;

    return center + Offset(dx + jitterX, dy + jitterY);
  }

  // ---------- tap: lock angle and start burst ----------
  void _onTap() {
    if (_phase != _GamePhase.swing) return;
    if (_gamePhotos.isEmpty || _currentIndex >= _gamePhotos.length) return;

    _swingCtrl.stop();

    setState(() {
      _phase = _GamePhase.burst;
      _capturedAngleRad = _currentAngleRad;
      _anglesDeg.add(_capturedAngleRad * 180 / pi);
      _burstColor = _angleToColor(_anglesDeg.last);
    });
    _burstCtrl.forward(from: 0);
  }

  Color _angleToColor(double angleDeg) {
    final a = angleDeg.abs();

    if (a < 2) {
      return const Color(0xFF4CAF50); // green
    } else if (a < 5) {
      return const Color(0xFFCDDC39); // lime
    } else if (a < 10) {
      return const Color(0xFFFFC107); // amber
    } else {
      return const Color(0xFFF44336); // red
    }
  }

  // ---------- after burst: fly photo into wall slot ----------
  void _startMoveToWall() {
    if (!mounted) return;
    if (_gamePhotos.isEmpty || _currentIndex >= _gamePhotos.length) return;

    final size = MediaQuery.of(context).size;

    setState(() {
      _phase = _GamePhase.moveToWall;
      _bigCenter = Offset(size.width / 2, size.height * 0.35);
      _slotCenter = _computeSlotCenter(size, _currentIndex);
      _bigScaleStart = _bigScale;
      _bigScaleEnd = 0.45;
    });

    _moveCtrl.forward(from: 0.0);
  }

  void _onMoveToWallCompleted() {
    if (!mounted) return;
    if (_gamePhotos.isEmpty || _currentIndex >= _gamePhotos.length) return;

    final photo = _gamePhotos[_currentIndex];

    setState(() {
      // кладём фотку в список повешенных
      _placed.add(
        _PlacedPhoto(
          photo: photo,
          center: _slotCenter,
          angleRad: _capturedAngleRad,
        ),
      );

      // запоминаем центр и цвет для свечения
      _lastPlacedCenter = _slotCenter;
      _lastPlacedGlowColor = _angleToColor(_anglesDeg.last);

      // остаёмся на текущем индексе — фото визуально остаётся в слоте
      _phase = _GamePhase.glow;
    });

    // запускаем плавное свечение 0.4s
    _slotGlowCtrl.forward(from: 0.0);
  }

  // ---------- final result ----------
  String _resultTitle() {
    if (_anglesDeg.isEmpty) return 'NO DATA';

    final absList = _anglesDeg.map((a) => a.abs()).toList();
    final avg = absList.reduce((a, b) => a + b) / absList.length;
    final maxTilt = absList.reduce(max);

    if (avg < 2 && maxTilt < 3) {
      return 'PERFECT INSTALLATION';
    } else if (avg < 5) {
      return 'ALMOST STRAIGHT';
    } else if (avg < 10) {
      return 'ARTISTIC TILT';
    } else {
      return 'GLORIOUS CHAOS';
    }
  }

  String _resultSubtitle() {
    if (_anglesDeg.isEmpty) return '';
    final absList = _anglesDeg.map((a) => a.abs()).toList();
    final avg = absList.reduce((a, b) => a + b) / absList.length;
    final maxTilt = absList.reduce(max);

    return 'avg tilt: ${avg.toStringAsFixed(1)}° • max: ${maxTilt.toStringAsFixed(1)}°';
  }

  void _restart() {
    if (_allGameCandidates.isEmpty) return;
    _resetGameWithNewRandomPhotos();
    _winCtrl.stop();
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06070A),
      body: SafeArea(
        child: BlocBuilder<TagBloc, TagState>(
          builder: (context, tagState) {
            return BlocBuilder<PhotoBloc, PhotoState>(
              builder: (context, photoState) {
                _initFromBlocIfNeeded(context, photoState, tagState);

                if (photoState is PhotoLoading || !_initializedFromBloc) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_gamePhotos.isEmpty) {
                  return const Center(
                    child: Text(
                      'Add some reference photos to play.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                if (_phase == _GamePhase.result) {
                  return _buildResultView(context);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTap,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // небольшой паддинг слева/справа
                      final innerWidth = constraints.maxWidth - 16;
                      final innerSize =
                          Size(innerWidth, constraints.maxHeight);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Stack(
                          children: [
                            // background
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF111520),
                                      Color(0xFF050608),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            // subtle space texture
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.04),
                                        Colors.transparent,
                                      ],
                                      radius: 1.2,
                                      center: Alignment.topCenter,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // wall guide dots
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _WallGuidesPainter(),
                              ),
                            ),
                            // placed thumbnails
                            ..._buildPlacedThumbnails(),
                            // glow around last placed photo
                            _buildSlotGlowLayer(innerSize),
                            // big swinging / flashing / moving photo
                            _buildBigPhotoLayer(innerSize),
                            // top bar
                            Positioned(
                              top: 12,
                              left: 8,
                              right: 8,
                              child: Row(
                                children: [
                                  const Spacer(),
                                  Text(
                                    '${_currentIndex + 1}/${_gamePhotos.length}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // hint
                            Positioned(
                              bottom: 24,
                              left: 8,
                              right: 8,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    'Tap to lock the angle when the photo looks straight.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ---------- big photo layer ----------
  Widget _buildBigPhotoLayer(Size size) {
    // скрываем только на экране результата; во время glow фото остаётся
    if (_phase == _GamePhase.result) {
      return const SizedBox.shrink();
    }

    if (_gamePhotos.isEmpty || _currentIndex >= _gamePhotos.length) {
      return const SizedBox.shrink();
    }

    final photo = _gamePhotos[_currentIndex];
    final helper = PhotoPathHelper();
    final String path =
        photo.isStoredInApp ? helper.getFullPath(photo.fileName) : photo.path;
    final file = File(path);

    final bigWidth = size.width * 0.78;
    final bigHeight = size.height * 0.65;

    final anchor = Offset(size.width / 2, size.height * 0.2); // nail
    final rectTop = anchor.dy + 12;

    double angle = _currentAngleRad;
    double scale = _bigScale;

    double burstT = 0.0;
    double moveT = 0.0;

    if (_phase == _GamePhase.burst) {
      burstT = Curves.easeOutCubic.transform(_burstCtrl.value);
      final shake = sin(burstT * pi) * 0.12;
      angle = _capturedAngleRad + shake;
      scale = 1.0 + 0.25 * sin(burstT * pi);
    } else if (_phase == _GamePhase.moveToWall) {
      moveT = Curves.easeInOutCubic.transform(_moveCtrl.value);
      angle = _capturedAngleRad;
      scale = lerpDouble(_bigScaleStart, _bigScaleEnd, moveT) ?? _bigScaleEnd;
    } else if (_phase == _GamePhase.glow) {
      // во время glow фото статично висит в слоте
      angle = _capturedAngleRad;
      scale = _bigScaleEnd;
    }

    Offset center;
    if (_phase == _GamePhase.moveToWall) {
      final start = Offset(size.width / 2, rectTop + bigHeight / 2);
      center = Offset(
        lerpDouble(start.dx, _slotCenter.dx, moveT) ?? start.dx,
        lerpDouble(start.dy, _slotCenter.dy, moveT) ?? start.dy,
      );
    } else if (_phase == _GamePhase.glow) {
      center = _slotCenter;
    } else {
      center = Offset(size.width / 2, rectTop + bigHeight / 2);
    }

    Widget content;
    if (photo.mediaType == 'image' && file.existsSync()) {
      content = ExtendedImage.file(
        file,
        fit: BoxFit.cover,
      );
    } else {
      content = Container(
        color: Colors.grey.shade800,
        alignment: Alignment.center,
        child: const Text(
          'NO IMAGE',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    Widget frame = Container(
      width: bigWidth,
      height: bigHeight,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 28,
            spreadRadius: 6,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.07),
                  Colors.transparent,
                  Colors.black.withOpacity(0.08),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );

    final frameTopCenter = Offset(center.dx, center.dy - bigHeight / 2);

    return Stack(
      children: [
        // nail + hanging line
        Positioned(
          left: anchor.dx - 1,
          top: anchor.dy - 10,
          child: Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: (frameTopCenter.dy - anchor.dy).clamp(0.0, 200.0),
                color: Colors.white.withOpacity(0.25),
              ),
            ],
          ),
        ),

        // burst effect — только в фазе burst
        if (_phase == _GamePhase.burst)
          _buildBurstEffect(center, bigWidth, bigHeight, burstT),

        // frame + image
        Positioned(
          left: center.dx - bigWidth / 2,
          top: center.dy - bigHeight / 2,
          child: Transform.rotate(
            angle: angle,
            origin: Offset(0, -bigHeight / 2),
            child: Transform.scale(
              scale: scale,
              child: frame,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBurstEffect(
    Offset center,
    double w,
    double h,
    double burstT,
  ) {
    if (burstT <= 0.0) return const SizedBox.shrink();

    final baseRadius = (w + h) * 0.35;
    final radiusOuter = baseRadius * (0.6 + 0.8 * burstT);
    final radiusInner = baseRadius * (0.3 + 0.6 * burstT);

    final colorOuter = _burstColor.withOpacity(0.18 * (1 - burstT));
    final colorInner = _burstColor.withOpacity(0.34 * (1 - burstT));

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _BurstPainter(
            center: center,
            radiusOuter: radiusOuter,
            radiusInner: radiusInner,
            colorOuter: colorOuter,
            colorInner: colorInner,
          ),
        ),
      ),
    );
  }

  // ---------- glow layer around last placed photo ----------
  Widget _buildSlotGlowLayer(Size size) {
    if (_slotGlowCtrl.isDismissed ||
        _lastPlacedCenter == null ||
        _lastPlacedGlowColor == Colors.transparent) {
      return const SizedBox.shrink();
    }

    final t = Curves.easeOutCubic.transform(_slotGlowCtrl.value);
    final radius = 80 + 40 * t;
    final opacity = (1.0 - t) * 0.55;

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _SlotGlowPainter(
            center: _lastPlacedCenter!,
            radius: radius,
            color: _lastPlacedGlowColor.withOpacity(opacity),
          ),
        ),
      ),
    );
  }

  // ---------- thumbnails on wall ----------
  List<Widget> _buildPlacedThumbnails() {
    final helper = PhotoPathHelper();
    final widgets = <Widget>[];

    for (final placed in _placed) {
      final p = placed.photo;
      final path = p.isStoredInApp ? helper.getFullPath(p.fileName) : p.path;
      final file = File(path);

      Widget content;
      if (p.mediaType == 'image' && file.existsSync()) {
        content = FittedBox(
          fit: BoxFit.contain,
          child: ExtendedImage.file(file),
        );
      } else {
        content = FittedBox(
          fit: BoxFit.contain,
          child: Container(
            width: 200,
            height: 200,
            color: Colors.grey.shade800,
            alignment: Alignment.center,
            child: const Text(
              'NO IMAGE',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
        );
      }

      const double slotMaxW = 120;
      const double slotMaxH = 120;

      widgets.add(
        Positioned(
          left: placed.center.dx - slotMaxW / 2,
          top: placed.center.dy - slotMaxH / 2,
          width: slotMaxW,
          height: slotMaxH,
          child: Transform.rotate(
            angle: placed.angleRad,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  // ---------- result screen ----------
  Widget _buildResultView(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final title = _resultTitle();
    final subtitle = _resultSubtitle();
    final bool isPerfect = title == 'PERFECT INSTALLATION';

    if (isPerfect && !_winCtrl.isAnimating) {
      _winCtrl.repeat(reverse: true);
    } else if (!isPerfect && _winCtrl.isAnimating) {
      _winCtrl.stop();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _restart,
      child: AnimatedBuilder(
        animation: _winCtrl,
        builder: (context, _) {
          double winT = _winCtrl.isAnimating ? _winCtrl.value : 0.0;
          final pulse = (sin(winT * 2 * pi) + 1) / 2;

          final glowOpacity = isPerfect ? 0.35 * pulse : 0.0;
          final scale = isPerfect ? 1.0 + 0.04 * pulse : 1.0;

          return Stack(
            children: [
              // фон
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF181C27),
                        Color(0xFF050608),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              // лёгкое зелёное сияние при PERFECT INSTALLATION
              if (isPerfect)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.2),
                          radius: 1.2,
                          colors: [
                            const Color(0xFF4CAF50)
                                .withOpacity(glowOpacity.clamp(0.0, 0.4)),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _WallGuidesPainter(),
                ),
              ),
              ..._buildPlacedThumbnails(),
              Positioned(
                top: size.height * 0.1,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    Transform.scale(
                      scale: scale,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 32,
                left: 16,
                right: 16,
                child: Column(
                  children: const [
                    Text(
                      'Tap anywhere to try another hanging.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your wall is ready for the opening night.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------- wall guide painter ----------
class _WallGuidesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;

    // центр стены совпадает с логикой _computeSlotCenter
    final center = Offset(size.width / 2, size.height / 2);

    const double gridX = 150;
    const double gridY = 130;

    for (int row = -1; row <= 1; row += 2) {
      for (int col = -1; col <= 1; col++) {
        final dx = col * gridX.toDouble();
        final dy = row * gridY.toDouble();

        final p = center + Offset(dx, dy);
        canvas.drawCircle(p, 4, paintLine);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WallGuidesPainter oldDelegate) => false;
}

// ---------- burst painter ----------
class _BurstPainter extends CustomPainter {
  final Offset center;
  final double radiusOuter;
  final double radiusInner;
  final Color colorOuter;
  final Color colorInner;

  _BurstPainter({
    required this.center,
    required this.radiusOuter,
    required this.radiusInner,
    required this.colorOuter,
    required this.colorInner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radiusOuter <= 0) return;

    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = colorOuter;

    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          colorInner,
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radiusInner),
      );

    canvas.drawCircle(center, radiusOuter, outerPaint);
    canvas.drawCircle(center, radiusInner, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) {
    return radiusOuter != oldDelegate.radiusOuter ||
        radiusInner != oldDelegate.radiusInner ||
        colorOuter != oldDelegate.colorOuter ||
        colorInner != oldDelegate.colorInner ||
        center != oldDelegate.center;
  }
}

// ---------- slot glow painter ----------
class _SlotGlowPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;

  _SlotGlowPainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || color.opacity == 0) return;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _SlotGlowPainter oldDelegate) {
    return center != oldDelegate.center ||
        radius != oldDelegate.radius ||
        color != oldDelegate.color;
  }
}
