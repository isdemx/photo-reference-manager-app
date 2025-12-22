import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_controls_widget.dart';
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
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
              child: SizedBox(
                height: 34,
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
                        child: Builder(
                          builder: (_) {
                            final duration = c.value.duration;
                            final position = c.value.position;
                            final positionFrac = duration == Duration.zero
                                ? 0.0
                                : (position.inMilliseconds /
                                        duration.inMilliseconds)
                                    .clamp(0.0, 1.0);
                            return VideoControls(
                              startFrac: 0.0,
                              endFrac: 1.0,
                              positionFrac: positionFrac,
                              onSeekFrac: (f) {
                                if (duration == Duration.zero) return;
                                final target = Duration(
                                  milliseconds:
                                      (duration.inMilliseconds * f).round(),
                                );
                                c.seekTo(target);
                              },
                              onChangeRange: null,
                              onChangeVolume: (v01) {
                                setState(() => _volume = v01);
                                c.setVolume(_volume);
                              },
                              onChangeSpeed: null,
                              volume: _volume,
                              speed: _speed,
                              showLoopRange: false,
                              showSpeed: false,
                            );
                          },
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
