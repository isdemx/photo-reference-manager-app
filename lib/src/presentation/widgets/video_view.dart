import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photographers_reference_app/src/presentation/widgets/triangle_volume_slider_widget.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/photo.dart';
import '../../utils/photo_path_helper.dart';

class GalleryVideoPage extends StatefulWidget {
  final int index;
  final int currentIndex;
  final Photo photo;

  final bool autoplay;
  final bool looping;

  final double volume; // 0..1
  final double speed; // 0.25..2.0

  /// чтобы родитель мог делать seek/play/pause по хоткеям
  final ValueChanged<VideoPlayerController?>? onControllerChanged;

  const GalleryVideoPage({
    super.key,
    required this.index,
    required this.currentIndex,
    required this.photo,
    this.autoplay = true,
    this.looping = true,
    this.volume = 1.0,
    this.speed = 1.0,
    this.onControllerChanged,
  });

  @override
  State<GalleryVideoPage> createState() => _GalleryVideoPageState();
}

class _GalleryVideoPageState extends State<GalleryVideoPage>
    with WidgetsBindingObserver {
  VideoPlayerController? _c;
  Future<void>? _init;

  bool _wasPlayingBeforeBackground = false;

  bool get _isCurrent => widget.index == widget.currentIndex;

  late double _volume; // 0..1
  late double _speed; // 0.25..2.0

  // стиль “как у VideoProgressIndicator по умолчанию”
  static const double _trackThickness = 4.0;

// высота вертикальных полосок (в 3 раза меньше, чем 92)
  static const double _vBarHeight = 30.0;

// подпись под полоской
  static const double _vLabelGap = 6.0;
  static const double _vLabelHeight = 14.0; // фикс высоты подписи (2 строки)

  final Color _trackColor = const Color.fromRGBO(200, 200, 200, 0.5);
  final Color _fillColor = const Color.fromRGBO(255, 0, 0, 0.7);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _volume = widget.volume.clamp(0.0, 1.0);
    _speed = widget.speed.clamp(0.25, 2.0);

    if (_isCurrent) _start();
  }

  @override
  void didUpdateWidget(covariant GalleryVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasCurrent = oldWidget.index == oldWidget.currentIndex;
    final isCurrentNow = _isCurrent;

    final videoChanged = oldWidget.photo.path != widget.photo.path ||
        oldWidget.photo.fileName != widget.photo.fileName;

    if (videoChanged) {
      _stop();
      if (isCurrentNow) _start();
      return;
    }

    if (!wasCurrent && isCurrentNow) {
      _start();
      return;
    }

    if (wasCurrent && !isCurrentNow) {
      _stop();
      return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;

    final bool isMobile = Platform.isIOS || Platform.isAndroid;

    // На macOS/desktop не считаем "inactive/hidden" поводом ставить видео на паузу —
    // это часто просто потеря фокуса окна.
    if (isMobile) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.hidden) {
        _wasPlayingBeforeBackground = c.value.isPlaying;
        c.pause();
        return;
      }

      if (state == AppLifecycleState.resumed) {
        // Возвращаем только если действительно играло до ухода
        if (_isCurrent && _wasPlayingBeforeBackground) {
          c.play();
        }
        return;
      }
    }
  }

  String _resolveVideoPath(Photo p) {
    if (p.path.isNotEmpty && File(p.path).existsSync()) return p.path;

    final byFileName = PhotoPathHelper().getFullPath(p.fileName);
    if (File(byFileName).existsSync()) return byFileName;

    return p.path;
  }

  void _start() {
    if (!_isCurrent) return;
    if (_c != null) return;

    final resolved = _resolveVideoPath(widget.photo);
    final file = File(resolved);

    if (!file.existsSync()) {
      setState(() {});
      return;
    }

    final controller = VideoPlayerController.file(file);
    _c = controller;
    widget.onControllerChanged?.call(controller);

    _init = controller.initialize().then((_) async {
      if (!mounted) return;

      await controller.setLooping(widget.looping);
      await controller.setVolume(_volume);

      // скорость применяем после init; на большинстве платформ ок.
      // если на iOS будет “самоплей”, можно перенести setPlaybackSpeed в момент play.
      await controller.setPlaybackSpeed(_speed);

      if (widget.autoplay && _isCurrent) {
        await controller.play();
      }

      if (mounted) setState(() {});
    });

    setState(() {});
  }

  void _stop() {
    final c = _c;
    _c = null;
    _init = null;

    if (c != null) {
      if (c.value.isInitialized) {
        c.pause();
        c.setVolume(0.0);
      }
      c.dispose();
    }

    widget.onControllerChanged?.call(null);

    if (mounted) setState(() {});
  }

  // ---------- helpers ----------
  void _togglePlayPause(VideoPlayerController c) {
    if (!c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  // тонкая “прогресс-полоска” вертикальная (volume/speed) тем же визуальным языком
  Widget _verticalProgressBar({
    required double value01, // 0..1
    required ValueChanged<double> onChanged01,
    required String label,
  }) {
    return SizedBox(
      width: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: _vBarHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) =>
                  _handleVerticalDrag(d.localPosition, onChanged01),
              onVerticalDragStart: (d) =>
                  _handleVerticalDrag(d.localPosition, onChanged01),
              onVerticalDragUpdate: (d) =>
                  _handleVerticalDrag(d.localPosition, onChanged01),
              child: LayoutBuilder(
                builder: (context, c) {
                  final h = c.maxHeight;
                  final w = c.maxWidth;

                  final v = value01.clamp(0.0, 1.0);
                  final fillH = h * v;

                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // track (серый)
                      Positioned(
                        left: (w - _trackThickness) / 2,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: _trackThickness,
                          decoration: BoxDecoration(
                            color: _trackColor,
                            borderRadius:
                                BorderRadius.circular(_trackThickness / 2),
                          ),
                        ),
                      ),

                      // fill (красный) снизу вверх
                      Positioned(
                        left: (w - _trackThickness) / 2,
                        bottom: 0,
                        height: fillH,
                        child: Container(
                          width: _trackThickness,
                          decoration: BoxDecoration(
                            color: _fillColor,
                            borderRadius:
                                BorderRadius.circular(_trackThickness / 2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SizedBox(
            height: _vLabelHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: true,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleVerticalDrag(
    Offset localPos,
    ValueChanged<double> onChanged01,
  ) {
    final double effectiveH = _vBarHeight;

    final dy = localPos.dy.clamp(0.0, effectiveH);
    final v = (1.0 - (dy / effectiveH)).clamp(0.0, 1.0);
    onChanged01(v);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    if (!_isCurrent) return const SizedBox.expand();

    final c = _c;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done ||
            !c.value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        final aspect = (c.value.aspectRatio == 0) ? 1.0 : c.value.aspectRatio;

        // speed -> нормируем к 0..1 для полоски (0.25..2.0)
        final speed01 = ((_speed - 0.25) / (2.0 - 0.25)).clamp(0.0, 1.0);

        final double panelHeight = _vBarHeight + _vLabelGap + _vLabelHeight;

        return Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: VideoPlayer(c),
                ),
              ),
            ),

            // нижняя панель: play/pause + красная прогресс-полоса + вертикалки
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: SizedBox(
                height: panelHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: 36,
                        height: 18,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                              width: 36, height: 36),
                          iconSize: 22,
                          splashRadius: 18,
                          icon: Icon(
                            c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () => _togglePlayPause(c),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: VideoProgressIndicator(
                          c,
                          allowScrubbing: true,
                          padding: const EdgeInsets.only(top: 6, bottom: 3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Align(
                    //   alignment: Alignment.bottomCenter,
                    //   child: _verticalProgressBar(
                    //     value01: speed01,
                    //     onChanged01: (v01) {
                    //       final newSpeed = 0.25 + v01 * (4.0 - 0.25);
                    //       final rounded = (newSpeed * 100).round() / 100.0;
                    //       setState(() => _speed = rounded);
                    //       c.setPlaybackSpeed(_speed);
                    //     },
                    //     label: '${_speed.toStringAsFixed(1)}x',
                    //   ),
                    // ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: TriangleVolumeSlider(
                          value: _volume.clamp(0.0, 1.0),
                          onChanged: (v01) {
                            setState(() => _volume = v01);
                            c.setVolume(_volume);
                          },
                          width: 26,
                          height: 10, // в 3 раза ниже
                          hitHeight: 30, // удобная зона для тача/мыши
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
