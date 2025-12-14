// lib/src/presentation/widgets/photo_magnet_game_screen.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';

import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';

import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class PhotoMagnetGameScreen extends StatefulWidget {
  const PhotoMagnetGameScreen({Key? key}) : super(key: key);

  @override
  State<PhotoMagnetGameScreen> createState() => _PhotoMagnetGameScreenState();
}

class _PhotoMagnetGameScreenState extends State<PhotoMagnetGameScreen>
    with TickerProviderStateMixin {
  final math.Random _rnd = math.Random();

  // Current photo
  Photo? _currentPhoto;
  File? _currentFile;

  // All photos allowed in the game
  List<Photo> _allPhotos = [];

  // All tags (for filtering out "Not Ref")
  List<Tag> _allTags = [];

  // Success counter
  int _successCount = 0;

  // Animation controllers
  late final AnimationController _timeController;    // global time (magnetic wobble)
  late final AnimationController _holdController;    // long press progress
  late final AnimationController _explodeController; // shatter effect

  bool _isHolding = false;
  bool _isExploding = false;
  bool _isCompleted = false;
  bool _initialized = false;

  // Magnetic field "points"
  late List<_MagnetPoint> _magnets;

  // Shatter tiles
  late List<_TilePiece> _tiles;
  static const int _tileRows = 4;
  static const int _tileCols = 4;

  @override
  void initState() {
    super.initState();

    _timeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _explodeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _magnets = _generateMagnets();
    _tiles = _generateTiles();
  }

  @override
  void dispose() {
    _timeController.dispose();
    _holdController.dispose();
    _explodeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATA INIT
  // ---------------------------------------------------------------------------

  void _initPhotosFromState(PhotoState state) {
    if (state is! PhotoLoaded) return;

    // Find "Not Ref" tag id (if exists)
    String? notRefTagId;
    for (final tag in _allTags) {
      if (tag.name == 'Not Ref') {
        notRefTagId = tag.id;
        break;
      }
    }

    // Base image list
    List<Photo> images = state.photos
        .where((p) => p.mediaType == 'image')
        .where((p) => p.fileName.isNotEmpty || p.path.isNotEmpty)
        .toList();

    // Filter out photos that have "Not Ref" tag
    if (notRefTagId != null) {
      images = images
          .where((p) => !p.tagIds.contains(notRefTagId!))
          .toList();
    }

    if (images.isEmpty) {
      setState(() {
        _allPhotos = [];
        _currentPhoto = null;
        _currentFile = null;
      });
      return;
    }

    _allPhotos = images;
    _pickNextPhoto();
  }

  void _pickNextPhoto() {
    if (_allPhotos.isEmpty) {
      setState(() {
        _currentPhoto = null;
        _currentFile = null;
      });
      return;
    }

    final int index = _rnd.nextInt(_allPhotos.length);
    final Photo photo = _allPhotos[index];

    final helper = PhotoPathHelper();
    final String path =
        photo.isStoredInApp ? helper.getFullPath(photo.fileName) : photo.path;

    final file = File(path);
    if (!file.existsSync()) {
      // If file is missing, drop it and try again
      _allPhotos.removeAt(index);
      if (_allPhotos.isEmpty) {
        setState(() {
          _currentPhoto = null;
          _currentFile = null;
        });
        return;
      }
      _pickNextPhoto();
      return;
    }

    setState(() {
      _currentPhoto = photo;
      _currentFile = file;
      _isExploding = false;
      _isHolding = false;
      _isCompleted = false;
    });

    _holdController.reset();
    _explodeController.reset();
    _magnets = _generateMagnets();
    _tiles = _generateTiles();
  }

  // ---------------------------------------------------------------------------
  // MAGNET FIELD
  // ---------------------------------------------------------------------------

  List<_MagnetPoint> _generateMagnets() {
    final List<_MagnetPoint> list = [];
    for (int i = 0; i < 4; i++) {
      final dx = _rnd.nextDouble() * 2 - 1; // -1..1
      final dy = _rnd.nextDouble() * 2 - 1;
      final strength = 40 + _rnd.nextDouble() * 60; // px
      final speed = 0.5 + _rnd.nextDouble() * 1.5; // frequency multiplier
      list.add(_MagnetPoint(Offset(dx, dy), strength, speed));
    }
    return list;
  }

  /// Calculates offset from center based on "magnetic" points.
  Offset _computeMagnetOffset(Size size, double time, double holdProgress) {
    if (_magnets.isEmpty) return Offset.zero;

    // The longer you hold, the calmer it gets
    final double magnetIntensity = 1.0 - 0.75 * holdProgress;

    final double base = math.min(size.width, size.height) * 0.2;

    double dx = 0;
    double dy = 0;

    for (final m in _magnets) {
      final mx = m.normalizedPos.dx * base;
      final my = m.normalizedPos.dy * base;

      final double phase = time * m.speed * 2 * math.pi;
      dx += mx * math.sin(phase) * (m.strength / 100) * magnetIntensity;
      dy += my * math.cos(phase) * (m.strength / 100) * magnetIntensity;
    }

    // Light jitter
    final jitter = (1.0 - holdProgress) * 3.0;
    dx += math.sin(time * 7.0) * jitter;
    dy += math.cos(time * 9.0) * jitter;

    return Offset(dx, dy);
  }

  double _computeRotation(double time, double holdProgress) {
    final double baseRot = 0.1 + (1.0 - holdProgress) * 0.25;
    return math.sin(time * 1.7 * 2 * math.pi) * baseRot;
  }

  double _computeScale(double time, double holdProgress) {
    final double wobble = (1.0 - holdProgress) * 0.04;
    return 1.0 + math.sin(time * 2.3 * 2 * math.pi) * wobble;
  }

  // ---------------------------------------------------------------------------
  // SHATTER / EXPLOSION
  // ---------------------------------------------------------------------------

  List<_TilePiece> _generateTiles() {
    final List<_TilePiece> tiles = [];
    for (int row = 0; row < _tileRows; row++) {
      for (int col = 0; col < _tileCols; col++) {
        final angle = _rnd.nextDouble() * 2 * math.pi;
        final distance = 60 + _rnd.nextDouble() * 120;
        final dir = Offset(
          math.cos(angle) * distance,
          math.sin(angle) * distance,
        );
        tiles.add(
          _TilePiece(
            row: row,
            col: col,
            direction: dir,
          ),
        );
      }
    }
    return tiles;
  }

  void _triggerExplosion() {
    if (_isExploding || _currentPhoto == null) return;

    setState(() {
      _isExploding = true;
      _isHolding = false;
    });

    _holdController.reset();

    _explodeController
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;
        _pickNextPhoto();
      });
  }

  // ---------------------------------------------------------------------------
  // HOLD LOGIC
  // ---------------------------------------------------------------------------

  void _startHold() {
    if (_currentPhoto == null || _isExploding || _isCompleted) return;
    if (_isHolding) return;

    setState(() {
      _isHolding = true;
    });

    _holdController
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;
        if (_isHolding && !_isExploding && !_isCompleted) {
          _onHoldSuccess();
        }
      });
  }

  void _cancelHold() {
    if (!_isHolding || _isExploding || _isCompleted) return;

    final progress = _holdController.value;

    setState(() {
      _isHolding = false;
    });

    if (progress > 0.6) {
      // Almost there, but released too early -> explode
      _triggerExplosion();
    } else {
      // Just reset
      _holdController.reset();
    }
  }

  void _onHoldSuccess() {
    if (_isCompleted || _currentPhoto == null) return;

    setState(() {
      _isHolding = false;
      _isCompleted = true;
      _successCount++;
    });

    // Small pause before next photo
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _pickNextPhoto();
    });
  }

  // ---------------------------------------------------------------------------
  // UI LAYERS
  // ---------------------------------------------------------------------------

  Widget _buildBackground(double time, double holdProgress) {
    final baseColor = const Color(0xFF050509);
    final accentColor = Colors.purpleAccent;

    final t = (math.sin(time * 2 * math.pi) + 1) / 2; // 0..1

    final double intensity = (1.0 - holdProgress);
    final color1 = Color.lerp(
      baseColor,
      accentColor.withOpacity(0.4),
      t * intensity,
    )!;
    final color2 = Color.lerp(
      const Color(0xFF121212),
      Colors.blueAccent.withOpacity(0.3),
      (1.0 - t) * intensity,
    )!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(
            math.sin(time * 1.3),
            math.cos(time * 1.7),
          ),
          radius: 1.2 + 0.3 * intensity,
          colors: [
            color1,
            color2,
            baseColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildPhotoContent(Size size, double time) {
    final photo = _currentPhoto;
    final file = _currentFile;

    if (photo == null || file == null) {
      return const Center(
        child: Text(
          'No photos available.\nAdd some images to play.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      );
    }

    final holdProgress = _holdController.value;

    if (_isExploding) {
      return _buildExplosionView(size);
    }

    final double maxPhotoWidth = size.width * 0.72;
    final double maxPhotoHeight = size.height * 0.58;

    final Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: Colors.black,
        child: Image.file(
          file,
          fit: BoxFit.cover,
          width: maxPhotoWidth,
          height: maxPhotoHeight,
        ),
      ),
    );

    return Center(
      child: GestureDetector(
        onLongPressStart: (_) => _startHold(),
        onLongPressEnd: (_) => _cancelHold(),
        onLongPressCancel: _cancelHold,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _timeController,
            _holdController,
          ]),
          builder: (context, child) {
            final double t = _timeController.value;
            final Offset offset =
                _computeMagnetOffset(size, t, _holdController.value);
            final double rotation =
                _computeRotation(t, _holdController.value);
            final double scale = _computeScale(t, _holdController.value);

            final double holdGlowOpacity =
                holdProgress > 0.0 ? 0.4 + 0.4 * holdProgress : 0.0;
            final double holdScale = 1.0 + 0.12 * holdProgress;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Glow while holding
                if (holdGlowOpacity > 0.01)
                  Transform.translate(
                    offset: offset * 0.4,
                    child: Transform.scale(
                      scale: holdScale,
                      child: Container(
                        width: maxPhotoWidth + 40,
                        height: maxPhotoHeight + 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: RadialGradient(
                            colors: [
                              Colors.purpleAccent
                                  .withOpacity(holdGlowOpacity),
                              Colors.blueAccent
                                  .withOpacity(holdGlowOpacity * 0.3),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.3, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Main photo
                Transform.translate(
                  offset: offset,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  ),
                ),

                // Progress ring or success label
                if (!_isCompleted)
                  Positioned(
                    bottom: -maxPhotoHeight * 0.55,
                    child: _buildHoldProgressIndicator(),
                  )
                else
                  Positioned(
                    bottom: -maxPhotoHeight * 0.55,
                    child: _buildHarmonizedLabel(),
                  ),
              ],
            );
          },
          child: image,
        ),
      ),
    );
  }

  Widget _buildHoldProgressIndicator() {
    final progress = _holdController.value;
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.4),
            ),
          ),
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: progress == 0 ? null : progress,
              strokeWidth: 3,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress < 0.6 ? Colors.pinkAccent : Colors.lightGreenAccent,
              ),
            ),
          ),
          const Text(
            'HOLD',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarmonizedLabel() {
    return AnimatedOpacity(
      opacity: _isCompleted ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.greenAccent, width: 1),
        ),
        child: const Text(
          'HARMONIZED',
          style: TextStyle(
            color: Colors.greenAccent,
            letterSpacing: 2,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildExplosionView(Size size) {
    final file = _currentFile;
    if (file == null) {
      return const SizedBox.shrink();
    }

    final double maxPhotoWidth = size.width * 0.72;
    final double maxPhotoHeight = size.height * 0.58;

    final image = Image.file(
      file,
      fit: BoxFit.cover,
      width: maxPhotoWidth,
      height: maxPhotoHeight,
    );

    final double value = Curves.easeOut.transform(_explodeController.value);
    final double baseFade = 1.0 - value;

    return Center(
      child: SizedBox(
        width: maxPhotoWidth,
        height: maxPhotoHeight,
        child: Stack(
          fit: StackFit.expand,
          children: _tiles.map((tile) {
            final double tx = tile.direction.dx * value;
            final double ty = tile.direction.dy * value;

            final double tileWidthFactor = 1.0 / _tileCols;
            final double tileHeightFactor = 1.0 / _tileRows;

            final double alignmentX =
                -1.0 + tileWidthFactor * 2 * tile.col + tileWidthFactor;
            final double alignmentY =
                -1.0 + tileHeightFactor * 2 * tile.row + tileHeightFactor;

            return Transform.translate(
              offset: Offset(tx, ty),
              child: Opacity(
                opacity: baseFade,
                child: Align(
                  alignment: Alignment(alignmentX, alignmentY),
                  widthFactor: tileWidthFactor,
                  heightFactor: tileHeightFactor,
                  child: ClipRect(
                    child: image,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PHOTO MAGNET',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hold the photo to calm the field.\nRelease too early – it shatters.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withOpacity(0.5),
                border: Border.all(
                  color: Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt,
                    color: Colors.yellowAccent.withOpacity(0.9),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'x$_successCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Close mini-game',
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TagBloc, TagState>(
      builder: (context, tagState) {
        if (tagState is TagLoaded) {
          _allTags = tagState.tags;
        }

        return BlocBuilder<PhotoBloc, PhotoState>(
          builder: (context, photoState) {
            if (!_initialized && photoState is PhotoLoaded) {
              _initialized = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _initPhotosFromState(photoState);
              });
            }

            return Scaffold(
              backgroundColor: Colors.black,
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );

                  return AnimatedBuilder(
                    animation: _timeController,
                    builder: (context, _) {
                      final double t = _timeController.value;
                      final holdProgress = _holdController.value;

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildBackground(t, holdProgress),
                          _buildPhotoContent(size, t),
                          _buildTopBar(),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// INTERNAL CLASSES
// -----------------------------------------------------------------------------

class _MagnetPoint {
  final Offset normalizedPos; // -1..1
  final double strength; // px
  final double speed; // frequency multiplier

  _MagnetPoint(this.normalizedPos, this.strength, this.speed);
}

class _TilePiece {
  final int row;
  final int col;
  final Offset direction;

  _TilePiece({
    required this.row,
    required this.col,
    required this.direction,
  });
}
