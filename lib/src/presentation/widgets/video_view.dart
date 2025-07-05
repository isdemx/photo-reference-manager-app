import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/photo.dart';

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
  // -------------------------------------------------------------------------

  const VideoView(
    this.index,
    this.photo,
    this.currentIndex,
    this.videoController, {
    Key? key,
    this.initialVolume,
    this.hideVolume = false,
    this.hidePlayPause = false,
    this.loopSliderHide = false,
    this.showTitle = false,
  }) : super(key: key);

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late VideoPlayerController _internalController;
  bool _ownsController = false;
  bool _isInitializing = false;
  late double _volume; // текущее значение громкости

  double _loopStart = 0;
  double _loopEnd = 1;
  Timer? _loopTimer;

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _volume = (widget.initialVolume ?? 0.1).clamp(0.0, 1.0);
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
      ..setVolume(_volume);

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

                  /// Видео-прогресс и loop-range идут в колонке
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: EdgeInsets.zero, // убрать лишние отступы
                          colors: const VideoProgressColors(
                            playedColor: Colors.blue,
                            bufferedColor: Colors.white54,
                            backgroundColor: Colors.black26,
                          ),
                        ),
                        // уменьшить отступ между слайдерами
                        const SizedBox(height: 4),

                        if (!widget.loopSliderHide) // <— NEW
                          Theme(
                            data: Theme.of(context).copyWith(
                              sliderTheme: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white30,
                                thumbColor: Colors.white,
                                overlayColor: Colors.white.withOpacity(0.2),
                                trackHeight: 2.0,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6.0),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12.0),
                              ),
                            ),
                            child: RangeSlider(
                              values: RangeValues(_loopStart, _loopEnd),
                              min: 0,
                              max: 1,
                              divisions: null,
                              onChanged: (RangeValues values) {
                                final wasStartChanged =
                                    values.start != _loopStart;
                                setState(() {
                                  _loopStart = values.start;
                                  _loopEnd = values.end;
                                });

                                if (wasStartChanged) {
                                  final c = widget.videoController ??
                                      _internalController;
                                  if (_controllerReady(c)) {
                                    final dur = c.value.duration;
                                    final start = Duration(
                                      milliseconds:
                                          (dur.inMilliseconds * _loopStart)
                                              .toInt(),
                                    );
                                    c.seekTo(start);
                                  }
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  /// Громкость
                  if (!widget.hideVolume)
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
