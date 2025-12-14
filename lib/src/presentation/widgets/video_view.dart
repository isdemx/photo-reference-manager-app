import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/photo.dart';
import 'video_loop_timeline.dart';

class VideoView extends StatefulWidget {
  /// индекс этого виджета и «текущей» страницы (нужны,
  /// если VideoView используется в пейджере / ленте)
  final int index;
  final int currentIndex;

  /// данные о медиа-файле
  final Photo photo;

  /// внешний контроллер, если нужен
  final VideoPlayerController? videoController;

  /// --- новые параметры -----------------------------------------------------
  final double? initialVolume; // (0..1)
  final bool hideVolume; // скрыть регулятор
  final bool hidePlayPause; // скрыть кнопку play / pause
  /// скрыть слайдер выбора петли
  final bool loopSliderHide;

  /// показывать название файла
  final bool showTitle;

  /// скорость воспроизведения (0.1..4.0), null => 1.0
  final double? initialSpeed;

  /// скрыть регулятор скорости
  final bool hideSpeed;
  // -------------------------------------------------------------------------

  const VideoView(
    this.index,
    this.photo,
    this.currentIndex,
    this.videoController, {
    Key? key,
    this.initialVolume, // теперь по умолчанию будет 0.0 (см. initState)
    this.hideVolume = false,
    this.hidePlayPause = false,
    this.loopSliderHide = false,
    this.showTitle = false,
    this.initialSpeed, // по умолчанию 1.0 (см. initState)
    this.hideSpeed = false,
  }) : super(key: key);

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late VideoPlayerController _internalController;
  bool _ownsController = false;
  bool _isInitializing = false;

  // громкость и скорость
  late double _volume; // (0..1)
  late double _speed; // (0.1..4.0)

  double _loopStart = 0;
  double _loopEnd = 1;
  Timer? _loopTimer;

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // ГРОМКОСТЬ: дефолт теперь 0.0 если не задана initialVolume
    _volume = (widget.initialVolume ?? 0.0).clamp(0.0, 1.0);
    // СКОРОСТЬ: дефолт 1.0 если не задана initialSpeed
    _speed = (widget.initialSpeed ?? 1.0).clamp(0.1, 4.0);
    _createControllerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant VideoView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // сменилось видео → пересоздаём контроллер
    if (widget.videoController == null &&
        widget.photo.path != oldWidget.photo.path) {
      _createControllerIfNeeded(recreate: true);
    }

    // изменили громкость извне
    if (widget.initialVolume != null &&
        widget.initialVolume != oldWidget.initialVolume) {
      _volume = widget.initialVolume!.clamp(0.0, 1.0);
      final c = widget.videoController ?? _internalController;
      if (_controllerReady(c)) c.setVolume(_volume);
    }

    // изменили скорость извне
    if (widget.initialSpeed != null &&
        widget.initialSpeed != oldWidget.initialSpeed) {
      _speed = widget.initialSpeed!.clamp(0.1, 4.0);
      final c = widget.videoController ?? _internalController;
      if (_controllerReady(c)) c.setPlaybackSpeed(_speed);
    }

    // авто-пауза / авто-плей
    final c = widget.videoController ?? _internalController;
    if (_controllerReady(c)) {
      widget.index == widget.currentIndex ? c.play() : c.pause();
    }
  }

  @override
  void dispose() {
    if (_ownsController) _internalController.dispose();
    _loopTimer?.cancel();
    super.dispose();
  }

  // ─────────────────── helpers ──────────────────────────────────────────────
  bool _controllerReady(VideoPlayerController c) =>
      !_isInitializing && c.value.isInitialized;

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  Future<void> _createControllerIfNeeded({bool recreate = false}) async {
    if (widget.videoController != null) return; // внешний

    if (_isInitializing) return;

    if (recreate && _ownsController) {
      await _internalController.dispose();
      _ownsController = false;
    }

    _isInitializing = true;
    _internalController = VideoPlayerController.file(File(widget.photo.path));
    await _internalController.initialize();
    _internalController
      ..setLooping(true)
      ..setVolume(_volume)
      ..setPlaybackSpeed(_speed); // ← применяем скорость

    if (widget.index == widget.currentIndex) _internalController.play();

    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final c = widget.videoController ?? _internalController;
      if (_controllerReady(c)) {
        final pos = c.value.position;
        final dur = c.value.duration;
        final start =
            Duration(milliseconds: (dur.inMilliseconds * _loopStart).toInt());
        final end =
            Duration(milliseconds: (dur.inMilliseconds * _loopEnd).toInt());

        if (pos >= end) {
          c.seekTo(start);
        }
      }
    });

    setState(() {
      _ownsController = true;
      _isInitializing = false;
    });
  }

  // ─────────────────── UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final controller = widget.videoController ?? _internalController;

    if (widget.index != widget.currentIndex || !_controllerReady(controller)) {
      return const Center(child: CircularProgressIndicator());
    }

    final pos = controller.value.position;
    final dur = controller.value.duration;

    // фракция текущей позиции (0..1)
    final double positionFrac = dur.inMilliseconds == 0
        ? 0.0
        : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // сам плеер -----------------------------------------------------------
        Expanded(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        if (widget.showTitle)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
            child: Text(
              widget.photo.fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),

        // нижняя панель ------------------------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Text(_fmt(pos)),
                  const SizedBox(width: 8),

                  /// Видео-прогресс + loop в одном виджете
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!widget.loopSliderHide)
                          VideoLoopTimeline(
                            position: positionFrac,
                            loopStart: _loopStart,
                            loopEnd: _loopEnd,
                            onPositionChanged: (frac) {
                              final c =
                                  widget.videoController ?? _internalController;
                              if (!_controllerReady(c)) return;
                              final d = c.value.duration;
                              if (d.inMilliseconds == 0) return;
                              final targetMs =
                                  (d.inMilliseconds * frac).round();
                              c.seekTo(Duration(milliseconds: targetMs));
                            },
                            onLoopChanged: (range) {
                              final c =
                                  widget.videoController ?? _internalController;
                              setState(() {
                                final prevStart = _loopStart;
                                _loopStart = range.start;
                                _loopEnd = range.end;

                                // если поменяли начало петли — сразу прыгаем туда
                                if (_loopStart != prevStart &&
                                    _controllerReady(c)) {
                                  final d = c.value.duration;
                                  if (d.inMilliseconds > 0) {
                                    final startMs =
                                        (d.inMilliseconds * _loopStart)
                                            .round();
                                    c.seekTo(
                                        Duration(milliseconds: startMs));
                                  }
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  /// Регулятор скорости (0.1x..4x)
                  if (!widget.hideSpeed)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 60,
                          child: RotatedBox(
                            quarterTurns: -1,
                            child: Slider(
                              min: 0.1,
                              max: 4.0,
                              divisions: 39, // шаг ~0.1x
                              value: _speed,
                              onChanged: (v) {
                                setState(() {
                                  _speed = double.parse(v.toStringAsFixed(2));
                                  controller.setPlaybackSpeed(_speed);
                                });
                              },
                            ),
                          ),
                        ),
                        Text(
                          '${_speed.toStringAsFixed(2)}x',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(width: 8),

                  /// Громкость
                  if (!widget.hideVolume)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 60,
                          child: RotatedBox(
                            quarterTurns: -1,
                            child: Slider(
                              min: 0.0,
                              max: 1.0,
                              divisions: 10,
                              value: _volume,
                              onChanged: (v) {
                                setState(() {
                                  _volume = v;
                                  controller.setVolume(_volume);
                                });
                              },
                            ),
                          ),
                        ),
                        Text(
                          '${(_volume * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 8),
                  // Text(_fmt(dur)),
                ],
              ),
            ],
          ),
        ),

        // play / pause -------------------------------------------------------
        if (!widget.hidePlayPause)
          IconButton(
            icon:
                Icon(controller.value.isPlaying ? Iconsax.pause : Iconsax.play),
            onPressed: () => setState(() => controller.value.isPlaying
                ? controller.pause()
                : controller.play()),
          ),
      ],
    );
  }
}
