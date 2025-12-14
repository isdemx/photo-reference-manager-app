// lib/src/presentation/widgets/color_harmony_game.dart

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:palette_generator/palette_generator.dart';

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';

// ⬇️ Tag imports for "Not Ref" exclusion
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';

class ColorHarmonyGame extends StatefulWidget {
  const ColorHarmonyGame({Key? key}) : super(key: key);

  @override
  State<ColorHarmonyGame> createState() => _ColorHarmonyGameState();
}

class _ColorHarmonyGameState extends State<ColorHarmonyGame>
    with TickerProviderStateMixin {
  final math.Random _rng = math.Random();

  // Photos and palette
  List<Photo> _availablePhotos = [];
  Photo? _currentPhoto;
  ImageProvider? _currentImage;
  Color? _targetColor; // "true" color
  Color? _distortedColor; // slightly distorted clue color
  List<Color> _options = [];

  // Round state
  bool _roundLoading = false;
  bool _answerLocked = false;
  double _lastAccuracy = 0.0;
  Color? _lastFlashColor;
  String _lastLabel = '';
  int _roundIndex = 0;
  int _score = 0;

  // Animations
  late final AnimationController _swingController;
  late final Animation<double> _swingAngle;

  late final AnimationController _answerController;
  late final Animation<double> _answerFlashOpacity;
  late final Animation<double> _answerScale;

  late final AnimationController _bgPulseController;
  late final Animation<double> _bgPulseValue;

  @override
  void initState() {
    super.initState();

    // Gentle photo swing
    _swingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _swingAngle = Tween<double>(
      begin: -0.14, // ~ -8°
      end: 0.14, // ~ +8°
    ).animate(
      CurvedAnimation(
        parent: _swingController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Answer animation (flash + slight scale)
    _answerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _answerFlashOpacity = CurvedAnimation(
      parent: _answerController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _answerScale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(
      CurvedAnimation(
        parent: _answerController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Soft background pulse
    _bgPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);

    _bgPulseValue = CurvedAnimation(
      parent: _bgPulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _swingController.dispose();
    _answerController.dispose();
    _bgPulseController.dispose();
    super.dispose();
  }

  Future<void> _startNewRound() async {
    if (!mounted) return;
    if (_availablePhotos.isEmpty) return;

    setState(() {
      _roundLoading = true;
      _answerLocked = false;
      _lastFlashColor = null;
      _lastAccuracy = 0.0;
      _lastLabel = '';
    });

    final helper = PhotoPathHelper();

    // Try to find an existing file
    Photo? picked;
    File? file;
    for (int i = 0; i < 8; i++) {
      final candidate =
          _availablePhotos[_rng.nextInt(_availablePhotos.length)];
      final String path = candidate.isStoredInApp
          ? helper.getFullPath(candidate.fileName)
          : candidate.path;
      final f = File(path);
      if (f.existsSync()) {
        picked = candidate;
        file = f;
        break;
      }
    }

    if (picked == null || file == null) {
      setState(() {
        _roundLoading = false;
      });
      return;
    }

    final imageProvider = FileImage(file);

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 12,
      );

      final List<Color> baseColors = [
        if (palette.dominantColor != null) palette.dominantColor!.color,
        if (palette.lightVibrantColor != null)
          palette.lightVibrantColor!.color,
        if (palette.darkVibrantColor != null) palette.darkVibrantColor!.color,
        if (palette.mutedColor != null) palette.mutedColor!.color,
        if (palette.lightMutedColor != null) palette.lightMutedColor!.color,
      ];

      final extra = palette.colors.toList();
      extra.shuffle(_rng);
      for (final c in extra) {
        if (!baseColors.contains(c)) baseColors.add(c);
        if (baseColors.length >= 6) break;
      }

      if (baseColors.isEmpty) {
        setState(() {
          _roundLoading = false;
        });
        return;
      }

      final Color target = baseColors[_rng.nextInt(baseColors.length)];
      final Color distorted = _distortColor(target);
      final List<Color> options = _buildOptions(target);

      setState(() {
        _currentPhoto = picked;
        _currentImage = imageProvider;
        _targetColor = target;
        _distortedColor = distorted;
        _options = options;
        _roundLoading = false;
        _roundIndex++;
      });
    } catch (_) {
      setState(() {
        _roundLoading = false;
      });
    }
  }

  Color _distortColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    final hueShift = (_rng.nextDouble() * 18 - 9); // -9..+9°
    final lightShift = (_rng.nextDouble() * 0.12 - 0.06); // -0.06..+0.06
    final satShift = (_rng.nextDouble() * 0.16 - 0.08); // -0.08..+0.08

    final hslNew = HSLColor.fromAHSL(
      hsl.alpha,
      (hsl.hue + hueShift) % 360,
      (hsl.saturation + satShift).clamp(0.0, 1.0),
      (hsl.lightness + lightShift).clamp(0.0, 1.0),
    );

    return hslNew.toColor();
  }

  List<Color> _buildOptions(Color target) {
    final List<Color> result = [target];

    double quant(double v, double step) =>
        ((v / step).roundToDouble() * step).clamp(0.0, 1.0);

    final targetHsl = HSLColor.fromColor(target);
    final refinedTarget = HSLColor.fromAHSL(
      targetHsl.alpha,
      targetHsl.hue,
      quant(targetHsl.saturation, 0.07),
      quant(targetHsl.lightness, 0.07),
    ).toColor();

    result[0] = refinedTarget;

    while (result.length < 5) {
      final hsl = HSLColor.fromColor(refinedTarget);
      final hueShift = (_rng.nextDouble() * 28 - 14); // -14..+14°
      final lightShift = (_rng.nextDouble() * 0.18 - 0.09);
      final satShift = (_rng.nextDouble() * 0.2 - 0.1);

      final hslNew = HSLColor.fromAHSL(
        hsl.alpha,
        (hsl.hue + hueShift) % 360,
        (hsl.saturation + satShift).clamp(0.0, 1.0),
        (hsl.lightness + lightShift).clamp(0.0, 1.0),
      );

      final candidate = hslNew.toColor();

      bool tooClose =
          result.any((c) => _colorDistance(c, candidate) < 12.0);
      bool tooFar = _colorDistance(refinedTarget, candidate) > 70.0;

      if (!tooClose && !tooFar) {
        result.add(candidate);
      }
    }

    result.shuffle(_rng);

    return result;
  }

  double _colorDistance(Color a, Color b) {
    final dr = (a.red - b.red).toDouble();
    final dg = (a.green - b.green).toDouble();
    final db = (a.blue - b.blue).toDouble();
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  void _onOptionTap(Color selected) {
    if (_answerLocked) return;
    if (_targetColor == null) return;

    _answerLocked = true;
    final double dist = _colorDistance(selected, _targetColor!);
    final double normalized = (dist / 75.0).clamp(0.0, 1.0);
    final double accuracy = (1.0 - normalized).clamp(0.0, 1.0);

    Color flashColor =
        Color.lerp(Colors.red.shade700, Colors.greenAccent.shade400, accuracy)!;

    String label;
    if (accuracy > 0.88) {
      label = 'PERFECT TONE';
      _score += 3;
      HapticFeedback.heavyImpact();
      vibrate();
    } else if (accuracy > 0.65) {
      label = 'CLOSE MATCH';
      _score += 2;
      HapticFeedback.mediumImpact();
      vibrate();
    } else if (accuracy > 0.4) {
      label = 'NEARLY THERE';
      _score += 1;
      HapticFeedback.selectionClick();
      vibrate();
    } else {
      label = 'OFF COLOR';
      HapticFeedback.vibrate();
      vibrate();
    }

    setState(() {
      _lastAccuracy = accuracy;
      _lastFlashColor = flashColor;
      _lastLabel = label;
    });

    _answerController.forward(from: 0.0).then((_) async {
      await Future.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      _answerLocked = false;
      await _startNewRound();
    });
  }

  Color _backgroundGradientStart() {
    final c = _targetColor ?? Colors.deepPurple.shade700;
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness * 0.3).clamp(0.0, 0.6))
        .toColor();
  }

  Color _backgroundGradientEnd() {
    final c = _distortedColor ?? _targetColor ?? Colors.blueGrey.shade900;
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness * 0.1 + 0.05).clamp(0.0, 0.4))
        .toColor();
  }

  Widget _buildBodyWithPhotos(List<Photo> photos) {
    // photos уже отфильтрованы по "Not Ref" в build()
    _availablePhotos = photos.where((p) => !p.isVideo).toList();

    if (_currentPhoto == null &&
        !_roundLoading &&
        _availablePhotos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startNewRound();
      });
    }

    final bool ready =
        _currentPhoto != null && _currentImage != null && !_roundLoading;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: ready
          ? _buildGameContent()
          : Center(
              key: const ValueKey('loading'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Preparing your colors…',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGameContent() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _bgPulseController,
        _answerController,
      ]),
      builder: (context, _) {
        final bgStart = _backgroundGradientStart();
        final bgEnd = _backgroundGradientEnd();
        final t = _bgPulseValue.value;
        final blendedStart = Color.lerp(bgStart, bgEnd, 0.25 + 0.35 * t)!;
        final blendedEnd = Color.lerp(bgEnd, Colors.black, 0.3 + 0.3 * t)!;

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.6),
                  radius: 1.4,
                  colors: [
                    blendedStart,
                    blendedEnd,
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 8),
                    Expanded(
                      flex: 6,
                      child: _buildPhotoCard(),
                    ),
                    const SizedBox(height: 18),
                    _buildInstruction(),
                    const SizedBox(height: 14),
                    _buildDistortedColorPreview(),
                    const SizedBox(height: 18),
                    Expanded(
                      flex: 3,
                      child: _buildOptionsRow(),
                    ),
                    const SizedBox(height: 8),
                    _buildAccuracyLabel(),
                  ],
                ),
              ),
            ),
            if (_lastFlashColor != null)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _answerController,
                  builder: (context, _) {
                    final opacity =
                        (1.0 - _answerFlashOpacity.value) * 0.40;
                    return Opacity(
                      opacity: opacity.clamp(0.0, 0.4),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, 0),
                            radius: 1.0,
                            colors: [
                              _lastFlashColor!.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const Text(
          'COLOR HARMONY',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            letterSpacing: 3,
          ),
        ),
        const Spacer(),
        AnimatedOpacity(
          opacity: _score > 0 ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.blur_circular,
                  color: Colors.white.withOpacity(0.8),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Score: $_score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard() {
    if (_currentImage == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_swingController, _answerController]),
      builder: (context, _) {
        final angle = _swingAngle.value;
        final scale = _answerScale.value;

        return Center(
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: angle,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.7),
                      blurRadius: 24,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image(
                          image: _currentImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.22),
                              Colors.black.withOpacity(0.60),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 16,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _currentPhoto?.fileName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'MATCH THE TONE',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstruction() {
    return Column(
      children: [
        const Text(
          'Tap the swatch that matches\nthe REAL color hidden in the photo.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Round $_roundIndex',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildDistortedColorPreview() {
    final color = _distortedColor ?? _targetColor ?? Colors.white24;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.9),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Container(
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This is your distorted clue.\nFind its true twin below.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildOptionsRow() {
    if (_options.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final int count = _options.length;
        final double circleSize =
            math.min(64, (maxWidth - 40) / count.clamp(1, 5));

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _options.map((color) {
            return _ColorSwatchButton(
              color: color,
              size: circleSize,
              onTap: () => _onOptionTap(color),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAccuracyLabel() {
    if (_lastLabel.isEmpty) {
      return const SizedBox(height: 30);
    }

    Color textColor =
        Color.lerp(Colors.redAccent.shade100, Colors.greenAccent, _lastAccuracy)!
            .withOpacity(0.95);

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 250),
      child: Column(
        children: [
          Text(
            _lastLabel,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(_lastAccuracy * 100).round()}% tone match',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TagBloc, TagState>(
      builder: (context, tagState) {
        // collect "Not Ref" tag ids if tags loaded
        final Set<String> notRefTagIds = {};
        if (tagState is TagLoaded) {
          for (final Tag t in tagState.tags) {
            if (t.name.trim().toLowerCase() == 'not ref') {
              notRefTagIds.add(t.id);
            }
          }
        }

        return BlocBuilder<PhotoBloc, PhotoState>(
          builder: (context, state) {
            if (state is PhotoLoading || state is PhotoInitial) {
              return Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading your references…',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is PhotoLoaded) {
              // ⬇️ filter out photos tagged "Not Ref"
              List<Photo> filtered = state.photos.where((p) {
                if (p.isVideo) return false;
                if (notRefTagIds.isEmpty) return true; // no tag info yet
                final ids = p.tagIds ?? <String>[];
                return !ids.any(notRefTagIds.contains);
              }).toList();

              if (filtered.isEmpty) {
                return Scaffold(
                  backgroundColor: Colors.black,
                  body: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No suitable reference images.\nRemove "Not Ref" tag to use photos in Color Harmony.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  ),
                );
              }

              return Scaffold(
                backgroundColor: Colors.black,
                body: _buildBodyWithPhotos(filtered),
              );
            }

            return Scaffold(
              backgroundColor: Colors.black,
              body: const Center(
                child: Text(
                  'Unable to load photos.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ColorSwatchButton extends StatefulWidget {
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ColorSwatchButton({
    Key? key,
    required this.color,
    required this.size,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_ColorSwatchButton> createState() => _ColorSwatchButtonState();
}

class _ColorSwatchButtonState extends State<_ColorSwatchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.09).animate(
      CurvedAnimation(
        parent: _hoverController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _hoverController.forward();
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails _) {
    _hoverController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                widget.color.withOpacity(0.9),
                widget.color.withOpacity(0.7),
                widget.color.withOpacity(0.9),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.7),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.7),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.25, -0.2),
                  radius: 0.9,
                  colors: [
                    Colors.white.withOpacity(0.25),
                    widget.color,
                    widget.color.withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
