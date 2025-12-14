// lib/src/presentation/widgets/photo_ghost_game.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class PhotoGhostGame extends StatefulWidget {
  const PhotoGhostGame({Key? key}) : super(key: key);

  @override
  State<PhotoGhostGame> createState() => _PhotoGhostGameState();
}

class _PhotoGhostGameState extends State<PhotoGhostGame> {
  // ------------ Game core ------------
  final Random _rnd = Random();

  // Active flying photos
  final List<_Ghost> _ghosts = [];

  // Photos for the game (filtered, without "Not Ref")
  List<Photo> _photos = [];

  // All tags (needed to exclude "Not Ref")
  List<Tag> _tags = [];

  // Play area size
  Size _areaSize = Size.zero;

  // Game loop timer
  Timer? _timer;
  static const Duration _tick = Duration(milliseconds: 16); // ~60 FPS

  // Time limit
  double _gameTimeLeft = 30.0; // seconds
  bool _running = true;

  // Spawn control
  double _spawnAccumulator = 0.0;
  static const double _spawnInterval = 0.7; // seconds
  static const int _maxGhosts = 7;

  // Score
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, _onTick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick(Timer timer) {
    if (!mounted) return;
    if (!_running) return;

    final double dt = _tick.inMilliseconds / 1000.0;

    setState(() {
      _gameTimeLeft -= dt;
      if (_gameTimeLeft <= 0) {
        _gameTimeLeft = 0;
        _running = false;
      }

      _spawnAccumulator += dt;

      // Spawn new photos if we have space and data
      if (_areaSize != Size.zero &&
          _photos.isNotEmpty &&
          _ghosts.length < _maxGhosts &&
          _spawnAccumulator >= _spawnInterval) {
        _spawnAccumulator = 0.0;
        _spawnGhost();
      }

      // Move / age photos
      if (_areaSize != Size.zero) {
        _updateGhosts(dt);
      }
    });
  }

  void _spawnGhost() {
    if (_photos.isEmpty) return;

    // Prefer images
    Photo? chosen;
    for (int i = 0; i < 10; i++) {
      final candidate = _photos[_rnd.nextInt(_photos.length)];
      if (candidate.mediaType == 'image') {
        chosen = candidate;
        break;
      }
    }
    chosen ??= _photos[_rnd.nextInt(_photos.length)];

    // Size of the floating square
    final double minSide = min(_areaSize.width, _areaSize.height);
    double size = minSide * 0.25;
    size = size.clamp(70.0, 160.0);

    final double maxX = _areaSize.width - size;
    final double maxY = _areaSize.height - size;

    final double x = _rnd.nextDouble() * (maxX > 0 ? maxX : 0);
    final double y = _rnd.nextDouble() * (maxY > 0 ? maxY : 0);

    // Speed slightly scales with current score (soft difficulty ramp)
    final double baseSpeed = 80.0 + _score * 4.0;
    final double speed = baseSpeed + _rnd.nextDouble() * 120.0;
    final double angle = _rnd.nextDouble() * 2 * pi;
    final Offset velocity = Offset(
      cos(angle) * speed,
      sin(angle) * speed,
    );

    // Small twist: some photos are "highlight shots" with extra score
    final bool isHighlight = _rnd.nextDouble() < 0.22; // ~22% chance
    final int scoreValue = isHighlight ? 3 : 1;

    // Lifetime: photo slowly fades and disappears if you don't catch it
    final double ttl = 3.0 + _rnd.nextDouble() * 3.0; // 3–6 seconds

    _ghosts.add(
      _Ghost(
        photo: chosen!,
        position: Offset(x, y),
        velocity: velocity,
        size: size,
        isHighlight: isHighlight,
        scoreValue: scoreValue,
        ttl: ttl,
        maxTtl: ttl,
      ),
    );
  }

  void _updateGhosts(double dt) {
    int missed = 0;
    final List<_Ghost> alive = [];

    for (final ghost in _ghosts) {
      // Movement
      Offset pos = ghost.position + ghost.velocity * dt;
      double x = pos.dx;
      double y = pos.dy;

      double vx = ghost.velocity.dx;
      double vy = ghost.velocity.dy;

      // Bounce from walls
      if (x < 0) {
        x = 0;
        vx = -vx;
      } else if (x + ghost.size > _areaSize.width) {
        x = _areaSize.width - ghost.size;
        vx = -vx;
      }

      if (y < 0) {
        y = 0;
        vy = -vy;
      } else if (y + ghost.size > _areaSize.height) {
        y = _areaSize.height - ghost.size;
        vy = -vy;
      }

      // Lifetime
      double ttl = ghost.ttl - dt;

      if (ttl <= 0) {
        // Photo "slipped away" – small penalty, but not below zero
        missed++;
      } else {
        ghost.position = Offset(x, y);
        ghost.velocity = Offset(vx, vy);
        ghost.ttl = ttl;
        alive.add(ghost);
      }
    }

    _ghosts
      ..clear()
      ..addAll(alive);

    if (missed > 0) {
      _score = max(0, _score - missed);
    }
  }

  void _handleTap(Offset localPosition) {
    if (!_running) return;

    setState(() {
      for (int i = _ghosts.length - 1; i >= 0; i--) {
        final g = _ghosts[i];
        final rect = Rect.fromLTWH(
          g.position.dx,
          g.position.dy,
          g.size,
          g.size,
        );
        if (rect.contains(localPosition)) {
          // Haptic feedback on successful catch
          HapticFeedback.mediumImpact();

          _score += g.scoreValue;
          _ghosts.removeAt(i);
          break;
        }
      }
    });
  }

  void _restartGame() {
    setState(() {
      _ghosts.clear();
      _score = 0;
      _gameTimeLeft = 30.0;
      _spawnAccumulator = 0.0;
      _running = true;
    });
  }

  void _exitGame() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  // ------------ UI ------------

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PhotoBloc, PhotoState>(
      builder: (context, photoState) {
        return BlocBuilder<TagBloc, TagState>(
          builder: (context, tagState) {
            // Photos
            if (photoState is PhotoLoaded) {
              _photos = photoState.photos;
            } else if (photoState is PhotoLoading ||
                photoState is PhotoInitial) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Tags
            if (tagState is TagLoaded) {
              _tags = tagState.tags;
            }

            // Exclude photos with tag.name == "Not Ref"
            final String? notRefTagId = _tags
                .where((t) => t.name == 'Not Ref')
                .map((t) => t.id)
                .cast<String?>()
                .firstWhere(
                  (id) => id != null,
                  orElse: () => null,
                );

            if (notRefTagId != null) {
              _photos = _photos
                  .where((p) => !p.tagIds.contains(notRefTagId))
                  .toList();
            }

            if (_photos.isEmpty) {
              return Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo, color: Colors.white54, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Add some photos first,\nthen come back to play.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _exitGame,
                        child: const Text(
                          'Back',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Scaffold(
              backgroundColor: Colors.black,
              body: LayoutBuilder(
                builder: (context, constraints) {
                  _areaSize =
                      Size(constraints.maxWidth, constraints.maxHeight);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        _handleTap(details.localPosition),
                    child: Stack(
                      children: [
                        // Floating photos
                        ..._buildGhostWidgets(),

                        // HUD
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 12,
                          left: 16,
                          right: 16,
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              _buildHudPill(
                                icon: Icons.timer,
                                label:
                                    'Time: ${_gameTimeLeft.toStringAsFixed(1)} s',
                              ),
                              _buildHudPill(
                                icon: Icons.star,
                                label: 'Score: $_score',
                              ),
                            ],
                          ),
                        ),

                        // Hint text
                        Positioned(
                          bottom:
                              MediaQuery.of(context).padding.bottom + 24,
                          left: 16,
                          right: 16,
                          child: Opacity(
                            opacity: _running ? 0.85 : 0.3,
                            child: const Text(
                              'Tap the drifting photos before they fade.\nGlowing shots are worth more points.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                        // Close button
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 12,
                          right: 16,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                            onPressed: _exitGame,
                          ),
                        ),

                        // Game over overlay
                        if (!_running)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.65),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Time is up',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'You caught $_score photo${_score == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton(
                                          onPressed: _restartGame,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.black,
                                          ),
                                          child: const Text('Play again'),
                                        ),
                                        const SizedBox(width: 16),
                                        OutlinedButton(
                                          onPressed: _exitGame,
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          child: const Text(
                                            'Exit',
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
    );
  }

  // ------------ Helpers ------------

  List<Widget> _buildGhostWidgets() {
    final helper = PhotoPathHelper();
    final List<Widget> widgets = [];
    final double t = DateTime.now().millisecondsSinceEpoch / 1000.0;

    for (final ghost in _ghosts) {
      final Photo photo = ghost.photo;

      final String path = photo.isStoredInApp
          ? helper.getFullPath(photo.fileName)
          : photo.path;

      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }

      final bool isHighlight = ghost.isHighlight;

      // Lifetime ratio 0..1
      final double life =
          (ghost.ttl / ghost.maxTtl).clamp(0.0, 1.0);

      // Soft pulsing for highlight photos
      double scale = 1.0;
      double glowOpacity = 0.0;
      if (isHighlight) {
        scale = 1.0 + 0.08 * sin(t * 5.0);
        glowOpacity = 0.6 + 0.3 * sin(t * 5.0);
      }

      // Overall opacity: photos fade out before disappearing
      final double opacity = 0.3 + 0.7 * life; // 0.3..1.0

      widgets.add(
        Positioned(
          left: ghost.position.dx,
          top: ghost.position.dy,
          width: ghost.size,
          height: ghost.size,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Stack(
                children: [
                  if (isHighlight)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow
                                .withOpacity(glowOpacity.clamp(0.0, 1.0)),
                            blurRadius: 22,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ExtendedImage.file(
                      file,
                      fit: BoxFit.cover,
                      cacheWidth: 400,
                      clearMemoryCacheIfFailed: true,
                      cacheRawData: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildHudPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ghost {
  Photo photo;
  Offset position;
  Offset velocity;
  double size;
  bool isHighlight;
  int scoreValue;
  double ttl;
  double maxTtl;

  _Ghost({
    required this.photo,
    required this.position,
    required this.velocity,
    required this.size,
    required this.isHighlight,
    required this.scoreValue,
    required this.ttl,
    required this.maxTtl,
  });
}
