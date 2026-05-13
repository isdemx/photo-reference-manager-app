import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoSurface extends StatefulWidget {
  final String filePath;
  final VideoPlayerController? controller;

  final Duration startTime; // default = Duration.zero
  final Duration? endTime; // null => конец
  final double volume; // 0..1
  final double speed; // 0.1..4.0
  final bool autoplay; // default = true

  final ValueChanged<Duration>? onPosition;
  final ValueChanged<Duration>? onDuration;

  /// Доля длительности (0..1), куда нужно перемотаться по запросу UI.
  final double? externalPositionFrac;

  /// Идентификатор запроса seek — меняем при каждом новом пользовательском действии.
  final int? externalSeekId;

  final ValueChanged<VideoPlayerController>? onControllerReady;

  const VideoSurface({
    Key? key,
    required this.filePath,
    this.controller,
    this.startTime = Duration.zero,
    this.endTime,
    this.volume = 0.0,
    this.speed = 1.0,
    this.autoplay = true,
    this.onPosition,
    this.onDuration,
    this.externalPositionFrac,
    this.externalSeekId,
    this.onControllerReady,
  }) : super(key: key);

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  late VideoPlayerController _internal;
  VideoPlayerController get _c => widget.controller ?? _internal;

  bool _owns = false;
  bool _initing = false;
  bool _disposed = false;
  int _setupToken = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant VideoSurface old) {
    super.didUpdateWidget(old);

    // смена файла при внутреннем контроллере
    if (widget.controller == null && widget.filePath != old.filePath) {
      _disposeInternal();
      _setup();
      return;
    }

    if (_ready) {
      // громкость
      if (widget.volume != old.volume) {
        _c.setVolume(widget.volume.clamp(0, 1));
      }
      // скорость
      if (widget.speed != old.speed) {
        _c.setPlaybackSpeed(widget.speed.clamp(0.1, 4.0));
      }
      // старт/энд → перескок на новый старт и ПЛЕЙ
      if (widget.startTime != old.startTime || widget.endTime != old.endTime) {
        final duration = _c.value.duration;
        final end = widget.endTime ?? duration;
        final startClamped = _clampStart(widget.startTime, end);
        _c.seekTo(startClamped);
        _c.play(); // по ТЗ — перезапускается
      }

      if (widget.externalSeekId != null &&
          widget.externalSeekId != old.externalSeekId &&
          widget.externalPositionFrac != null) {
        final frac = widget.externalPositionFrac!.clamp(0.0, 1.0);
        final duration = _c.value.duration;
        if (duration > Duration.zero) {
          final targetMs = (duration.inMilliseconds * frac)
              .clamp(0, duration.inMilliseconds);
          final target = Duration(milliseconds: targetMs.toInt());
          _c.seekTo(target);
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _setupToken++;
    _tick?.cancel();
    _disposeInternal();
    super.dispose();
  }

  bool get _ready {
    if (_disposed || _initing) return false;
    try {
      return _c.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  Duration _clampStart(Duration start, Duration end) {
    if (start < Duration.zero) return Duration.zero;
    final edge = end - const Duration(milliseconds: 10);
    return start > edge ? edge : start;
  }

  Future<void> _setup() async {
    if (_initing) return;
    final token = ++_setupToken;
    _initing = true;

    try {
      if (widget.controller == null) {
        _internal = VideoPlayerController.file(File(widget.filePath));
        _owns = true;
        await _internal.initialize();
      } else {
        if (!widget.controller!.value.isInitialized) {
          await widget.controller!.initialize();
        }
      }
      if (!_isCurrentSetup(token)) return;

      widget.onControllerReady?.call(_c);

      await _c.setLooping(false); // лупим вручную в [start; end)
      if (!_isCurrentSetup(token)) return;
      await _c.setVolume(widget.volume.clamp(0, 1));
      if (!_isCurrentSetup(token)) return;
      await _c.setPlaybackSpeed(widget.speed.clamp(0.1, 4.0));
      if (!_isCurrentSetup(token)) return;

      final duration = _c.value.duration;
      widget.onDuration?.call(duration);

      final end = widget.endTime ?? duration;
      final startClamped = _clampStart(widget.startTime, end);
      await _c.seekTo(startClamped);
      if (!_isCurrentSetup(token)) return;
      if (widget.autoplay) await _c.play(); // ← автостарт

      if (!_isCurrentSetup(token)) return;
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(milliseconds: 120), (_) async {
        if (!_ready) return;
        final d = _c.value.duration;
        final end = (widget.endTime == null || widget.endTime! > d)
            ? d
            : widget.endTime!;
        final pos = _c.value.position;

        widget.onPosition?.call(pos);

        if (pos >= end && _ready) {
          await _c.seekTo(widget.startTime);
          if (_ready) await _c.play();
        }
      });

      if (mounted && !_disposed && token == _setupToken) {
        setState(() => _initing = false);
      }
    } catch (_) {
      if (mounted && !_disposed && token == _setupToken) {
        setState(() => _initing = false);
      }
    }
  }

  bool _isCurrentSetup(int token) {
    return mounted && !_disposed && token == _setupToken;
  }

  void _disposeInternal() {
    if (_owns) {
      try {
        _internal.dispose();
      } catch (_) {}
      _owns = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    final size = _c.value.size;

    // ТАП — пауза/плей
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_c.value.isPlaying) {
          _c.pause();
        } else {
          _c.play();
        }
        setState(() {});
      },
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(_c),
        ),
      ),
    );
  }
}
