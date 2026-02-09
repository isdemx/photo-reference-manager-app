import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/helpers/photo_save_helper.dart';
import 'package:photographers_reference_app/src/utils/_determine_media_type.dart';

enum ImportStage {
  idle,
  loading,
  converting,
  done,
  canceled,
  error,
}

class ImportStatus {
  final ImportStage stage;
  final int total;
  final int completed;
  final String? currentName;
  final String? message;
  final bool visible;

  const ImportStatus({
    required this.stage,
    required this.total,
    required this.completed,
    required this.currentName,
    required this.message,
    required this.visible,
  });

  double get progress => total == 0 ? 0.0 : completed / total;

  bool get isActive => stage == ImportStage.loading || stage == ImportStage.converting;
  bool get isFinal =>
      stage == ImportStage.done ||
      stage == ImportStage.canceled ||
      stage == ImportStage.error;
}

typedef ImportCompletionHandler = Future<void> Function(List<Photo> photos);

class DragDropImportService {
  final StreamController<ImportStatus> _controller =
      StreamController<ImportStatus>.broadcast();
  final Queue<_ImportJob> _queue = Queue<_ImportJob>();
  final Map<String, DateTime> _recentlyDropped = <String, DateTime>{};
  bool _isRunning = false;
  bool _cancelRequested = false;
  Timer? _autoHideTimer;
  ImportCompletionHandler? _collageHandler;
  int _lastTotal = 0;
  int _lastCompleted = 0;
  String? _lastName;

  Stream<ImportStatus> get statusStream => _controller.stream;

  void registerCollageHandler(ImportCompletionHandler handler) {
    _collageHandler = handler;
  }

  void unregisterCollageHandler(ImportCompletionHandler handler) {
    if (_collageHandler == handler) {
      _collageHandler = null;
    }
  }

  void importFiles({
    required List<XFile> files,
    required BuildContext context,
  }) {
    if (!_isDesktop()) return;
    final filtered = files.where((f) => !_shouldSkipDroppedFile(f.path)).toList();
    if (filtered.isEmpty) return;
    _queue.add(_ImportJob(files: filtered, context: context));
    _processQueue();
  }

  void cancel() {
    _cancelRequested = true;
    _queue.clear();
    _emit(
      stage: ImportStage.canceled,
      total: 0,
      completed: 0,
      currentName: null,
      message: null,
      visible: true,
    );
    _scheduleAutoHide();
  }

  void dispose() {
    _autoHideTimer?.cancel();
    _controller.close();
  }

  Future<void> _processQueue() async {
    if (_isRunning) return;
    _isRunning = true;

    while (_queue.isNotEmpty) {
      if (_cancelRequested) break;
      final job = _queue.removeFirst();
      final total = job.files.length;
      _lastTotal = total;
      int completed = 0;
      final List<Photo> importedPhotos = <Photo>[];

      for (final xfile in job.files) {
        if (_cancelRequested) break;
        final fileName = p.basename(xfile.path);
        _lastName = fileName;
        _emit(
          stage: ImportStage.loading,
          total: total,
          completed: completed,
          currentName: fileName,
          message: null,
          visible: true,
        );

        try {
          final bytes = await File(xfile.path).readAsBytes();
          if (bytes.isEmpty) {
            completed++;
            continue;
          }
          final mediaType = determineMediaType(xfile.path);
          if (mediaType == 'unknown') {
            completed++;
            continue;
          }

          final photo = await PhotoSaveHelper.savePhoto(
            fileName: fileName,
            bytes: bytes,
            context: job.context,
            mediaType: mediaType,
            onStatus: (status) {
              if (status == 'converting') {
                _emit(
                  stage: ImportStage.converting,
                  total: total,
                  completed: completed,
                  currentName: fileName,
                  message: null,
                  visible: true,
                );
              }
            },
          );
          importedPhotos.add(photo);
        } catch (e) {
          debugPrint('[DragDropImport] $e');
        } finally {
          completed++;
          _lastCompleted = completed;
        }
      }

      if (importedPhotos.isNotEmpty && _collageHandler != null) {
        await _collageHandler!(importedPhotos);
      }
    }

    if (_cancelRequested) {
      _emit(
        stage: ImportStage.canceled,
        total: _lastTotal,
        completed: _lastCompleted,
        currentName: _lastName,
        message: null,
        visible: true,
      );
    } else {
      _emit(
        stage: ImportStage.done,
        total: _lastTotal,
        completed: _lastCompleted,
        currentName: _lastName,
        message: null,
        visible: true,
      );
    }
    _scheduleAutoHide();
    _cancelRequested = false;
    _isRunning = false;
  }

  void _emit({
    required ImportStage stage,
    required int total,
    required int completed,
    required String? currentName,
    required String? message,
    required bool visible,
  }) {
    _autoHideTimer?.cancel();
    _controller.add(
      ImportStatus(
        stage: stage,
        total: total,
        completed: completed,
        currentName: currentName,
        message: message,
        visible: visible,
      ),
    );
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 3), () {
      _controller.add(
        const ImportStatus(
          stage: ImportStage.idle,
          total: 0,
          completed: 0,
          currentName: null,
          message: null,
          visible: false,
        ),
      );
    });
  }

  bool _shouldSkipDroppedFile(String path) {
    final now = DateTime.now();
    _recentlyDropped.removeWhere(
      (_, ts) => now.difference(ts).inMilliseconds > 500,
    );
    final last = _recentlyDropped[path];
    if (last != null && now.difference(last).inMilliseconds < 400) {
      return true;
    }
    _recentlyDropped[path] = now;
    return false;
  }

  bool _isDesktop() {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }
}

class _ImportJob {
  final List<XFile> files;
  final BuildContext context;

  const _ImportJob({
    required this.files,
    required this.context,
  });
}
