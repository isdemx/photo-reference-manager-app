import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart' as archive;
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/collage.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';
import 'package:photographers_reference_app/src/services/app_reload_service.dart';

enum _BackupPhase {
  preparing,
  copyingMedia,
  zipping,
  sharing,
}

enum _RestorePhase {
  preparing,
  extracting,
  snapshottingCurrent,
  applyingBackup,
}

class _BackupProgressSnapshot {
  const _BackupProgressSnapshot({
    required this.phase,
    required this.progress,
    required this.copiedMediaFiles,
    required this.totalMediaFiles,
    this.currentItemName,
    this.eta,
  });

  final _BackupPhase phase;
  final double progress;
  final int copiedMediaFiles;
  final int totalMediaFiles;
  final String? currentItemName;
  final Duration? eta;
}

class _BackupCancelToken {
  bool isCanceled = false;
}

class _BackupCanceledException implements Exception {}

class _BackupDeliveryCanceledException implements Exception {}

class _RestoreProgressSnapshot {
  const _RestoreProgressSnapshot({
    required this.phase,
    required this.progress,
    required this.processedFiles,
    required this.totalFiles,
  });

  final _RestorePhase phase;
  final double progress;
  final int processedFiles;
  final int totalFiles;
}

class BackupProgressState {
  const BackupProgressState({
    required this.visible,
    required this.isActive,
    required this.isFinal,
    required this.canceling,
    required this.phaseLabel,
    required this.progress,
    required this.copiedMediaFiles,
    required this.totalMediaFiles,
    this.currentItemName,
    this.eta,
  });

  final bool visible;
  final bool isActive;
  final bool isFinal;
  final bool canceling;
  final String phaseLabel;
  final double progress;
  final int copiedMediaFiles;
  final int totalMediaFiles;
  final String? currentItemName;
  final Duration? eta;

  BackupProgressState copyWith({
    bool? visible,
    bool? isActive,
    bool? isFinal,
    bool? canceling,
    String? phaseLabel,
    double? progress,
    int? copiedMediaFiles,
    int? totalMediaFiles,
    String? currentItemName,
    Duration? eta,
  }) {
    return BackupProgressState(
      visible: visible ?? this.visible,
      isActive: isActive ?? this.isActive,
      isFinal: isFinal ?? this.isFinal,
      canceling: canceling ?? this.canceling,
      phaseLabel: phaseLabel ?? this.phaseLabel,
      progress: progress ?? this.progress,
      copiedMediaFiles: copiedMediaFiles ?? this.copiedMediaFiles,
      totalMediaFiles: totalMediaFiles ?? this.totalMediaFiles,
      currentItemName: currentItemName ?? this.currentItemName,
      eta: eta ?? this.eta,
    );
  }
}

class BackupService {
  static final ValueNotifier<BackupProgressState?> progressNotifier =
      ValueNotifier<BackupProgressState?>(null);
  static _BackupCancelToken? _activeCancelToken;
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  static void cancelCurrent() {
    final token = _activeCancelToken;
    if (token == null) return;
    token.isCanceled = true;
    final current = progressNotifier.value;
    if (current != null) {
      progressNotifier.value = current.copyWith(canceling: true);
    }
  }

  static void _updateProgress(BackupProgressState state) {
    progressNotifier.value = state;
  }

  static Future<void> _flushOpenBoxes() async {
    if (Hive.isBoxOpen('tags')) {
      await Hive.box<Tag>('tags').flush();
    }
    if (Hive.isBoxOpen('categories')) {
      await Hive.box<Category>('categories').flush();
    }
    if (Hive.isBoxOpen('folders')) {
      await Hive.box<Folder>('folders').flush();
    }
    if (Hive.isBoxOpen('photos')) {
      await Hive.box<Photo>('photos').flush();
    }
    if (Hive.isBoxOpen('collages')) {
      await Hive.box<Collage>('collages').flush();
    }
    if (Hive.isBoxOpen('tag_categories')) {
      await Hive.box<TagCategory>('tag_categories').flush();
    }
  }

  /// Собираем ZIP-файл.
  static Future<String> _buildZip({
    void Function(_BackupProgressSnapshot progress)? onProgress,
    required _BackupCancelToken cancelToken,
  }) async {
    print('[Backup] Начало создания ZIP...');
    final docs = await getApplicationDocumentsDirectory();
    final tmp = await getTemporaryDirectory();
    final startedAt = DateTime.now();

    print('[Backup] documentsDir: ${docs.path}');
    print('[Backup] tempDir: ${tmp.path}');

    final workDir = Directory(p.join(tmp.path, 'backup_build'));
    if (await workDir.exists()) {
      print('[Backup] Удаляем предыдущую временную папку...');
      await workDir.delete(recursive: true);
    }
    await workDir.create(recursive: true);
    print('[Backup] Создана временная рабочая папка: ${workDir.path}');

    void emitProgress({
      required _BackupPhase phase,
      required double progress,
      required int copiedMediaFiles,
      required int totalMediaFiles,
      String? currentItemName,
    }) {
      if (onProgress == null) return;
      final normalized = progress.clamp(0.0, 100.0);
      Duration? eta;
      if (normalized > 0) {
        final elapsed = DateTime.now().difference(startedAt);
        final totalMs = elapsed.inMilliseconds * (100 / normalized);
        final remainingMs = (totalMs - elapsed.inMilliseconds).round();
        if (remainingMs > 0) {
          eta = Duration(milliseconds: remainingMs);
        }
      }
      onProgress(
        _BackupProgressSnapshot(
          phase: phase,
          progress: normalized,
          copiedMediaFiles: copiedMediaFiles,
          totalMediaFiles: totalMediaFiles,
          currentItemName: currentItemName,
          eta: eta,
        ),
      );
    }

    emitProgress(
      phase: _BackupPhase.preparing,
      progress: 0,
      copiedMediaFiles: 0,
      totalMediaFiles: 0,
    );

    // Hive-файлы
    final hiveFiles = docs
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.hive') || f.path.endsWith('.lock'))
        .toList();

    print('[Backup] Найдено Hive-файлов: ${hiveFiles.length}');
    for (final f in hiveFiles) {
      final dest = p.join(workDir.path, p.basename(f.path));
      await f.copy(dest);
      print('[Backup] Скопирован Hive-файл: ${f.path}');
    }

    // Медиа
    final photosSrc = Directory(p.join(docs.path, 'photos'));
    int totalMediaFiles = 0;
    if (await photosSrc.exists()) {
      print('[Backup] Копируем директорию с фото...');
      final mediaFiles =
          photosSrc.listSync(recursive: true).whereType<File>().toList();
      totalMediaFiles = mediaFiles.length;
      var copiedMediaFiles = 0;
      await _copyDirForBackup(
        photosSrc,
        Directory(p.join(workDir.path, 'photos')),
        cancelToken: cancelToken,
        onFileCopied: (relativePath) {
          copiedMediaFiles += 1;
          emitProgress(
            phase: _BackupPhase.copyingMedia,
            progress: totalMediaFiles == 0
                ? 35
                : (copiedMediaFiles / totalMediaFiles) * 35,
            copiedMediaFiles: copiedMediaFiles,
            totalMediaFiles: totalMediaFiles,
            currentItemName: p.basename(relativePath),
          );
        },
      );
    } else {
      print('[Backup] Папка "photos" не найдена.');
    }

    // Упаковка
    final zipPath = p.join(
      tmp.path,
      'backup_${DateTime.now().toIso8601String()}.zip',
    );

    print('[Backup] Начинаем упаковку в: $zipPath');

    try {
      await ZipFile.createFromDirectory(
        sourceDir: workDir,
        zipFile: File(zipPath),
        recurseSubDirs: true,
        onZipping: (filePath, isDir, progress) {
          if (cancelToken.isCanceled) {
            print('[Backup] Отмена запрошена во время упаковки.');
            return ZipFileOperation.cancel;
          }
          final name = p.basename(filePath);
          print('[Backup] ${progress.toStringAsFixed(1)}% → $name');
          emitProgress(
            phase: _BackupPhase.zipping,
            progress: 35 + (progress * 0.65),
            copiedMediaFiles: totalMediaFiles,
            totalMediaFiles: totalMediaFiles,
            currentItemName: name,
          );
          return ZipFileOperation.includeItem;
        },
      );
      if (cancelToken.isCanceled) {
        throw _BackupCanceledException();
      }

      final zipSize = await File(zipPath).length();
      print(
        '[Backup] ZIP-файл создан: $zipPath '
        '(${(zipSize / 1024 / 1024).toStringAsFixed(2)} MB)',
      );
      return zipPath;
    } finally {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
        print('[Backup] Временная рабочая папка удалена.');
      }
      if (cancelToken.isCanceled && await File(zipPath).exists()) {
        await File(zipPath).delete();
      }
    }
  }

  static Future<void> _copyDir(
    Directory from,
    Directory to, {
    void Function(String relativePath)? onFileCopied,
  }) async {
    await for (final ent in from.list(recursive: true)) {
      final rel = p.relative(ent.path, from: from.path);
      final newPath = p.join(to.path, rel);
      if (ent is File) {
        await File(newPath).create(recursive: true);
        await ent.copy(newPath);
        onFileCopied?.call(rel);
        print('[Backup] Скопирован файл: $rel');
      } else if (ent is Directory) {
        await Directory(newPath).create(recursive: true);
        print('[Backup] Создана папка: $rel');
      }
    }
  }

  static Future<void> _copyDirForBackup(
    Directory from,
    Directory to, {
    required _BackupCancelToken cancelToken,
    required void Function(String relativePath) onFileCopied,
  }) async {
    await for (final ent in from.list(recursive: true)) {
      if (cancelToken.isCanceled) {
        throw _BackupCanceledException();
      }
      final rel = p.relative(ent.path, from: from.path);
      final newPath = p.join(to.path, rel);
      if (ent is File) {
        await File(newPath).create(recursive: true);
        await ent.copy(newPath);
        onFileCopied(rel);
        print('[Backup] Скопирован файл: $rel');
      } else if (ent is Directory) {
        await Directory(newPath).create(recursive: true);
        print('[Backup] Создана папка: $rel');
      }
    }
  }

  static String _phaseLabel(_BackupPhase phase) {
    switch (phase) {
      case _BackupPhase.preparing:
        return 'Preparing backup...';
      case _BackupPhase.copyingMedia:
        return 'Copying media files...';
      case _BackupPhase.zipping:
        return 'Packaging backup...';
      case _BackupPhase.sharing:
        return 'Opening share dialog...';
    }
  }

  static String _restorePhaseLabel(_RestorePhase phase) {
    switch (phase) {
      case _RestorePhase.preparing:
        return 'Preparing restore...';
      case _RestorePhase.extracting:
        return 'Extracting backup...';
      case _RestorePhase.snapshottingCurrent:
        return 'Saving current data...';
      case _RestorePhase.applyingBackup:
        return 'Applying backup...';
    }
  }

  /// Публичный метод: спросить пользователя, затем показать прогресс и сделать бэкап.
  static Future<void> promptAndRun(BuildContext context) async {
    print('[Backup] Показываем диалог пользователю...');
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create a backup?'),
        content: const Text(
          'We’ll package your Hive database and all media files into a ZIP archive. '
          'Then you’ll be able to store them or import the backup into the app on another device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (agreed != true) {
      print('[Backup] Пользователь отказался от backup.');
      return;
    }

    await _runInBackground(context);
  }

  static Future<void> _runInBackground(BuildContext context) async {
    final rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (_isRunning) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Backup is already running')),
      );
      return;
    }

    _isRunning = true;
    final cancelToken = _BackupCancelToken();
    _activeCancelToken = cancelToken;

    _updateProgress(
      BackupProgressState(
        visible: true,
        isActive: true,
        isFinal: false,
        canceling: false,
        phaseLabel: _phaseLabel(_BackupPhase.preparing),
        progress: 0,
        copiedMediaFiles: 0,
        totalMediaFiles: 0,
        eta: null,
      ),
    );

    try {
      print('[Backup] Сбрасываем открытые Hive box-ы...');
      await _flushOpenBoxes();

      print('[Backup] Стартуем _buildZip...');
      final zipPath = await _buildZip(
        cancelToken: cancelToken,
        onProgress: (p) {
          _updateProgress(
            BackupProgressState(
              visible: true,
              isActive: true,
              isFinal: false,
              canceling: cancelToken.isCanceled,
              phaseLabel: _phaseLabel(p.phase),
              progress: p.progress,
              copiedMediaFiles: p.copiedMediaFiles,
              totalMediaFiles: p.totalMediaFiles,
              currentItemName: p.currentItemName,
              eta: p.eta,
            ),
          );
        },
      );

      _updateProgress(
        BackupProgressState(
          visible: true,
          isActive: true,
          isFinal: false,
          canceling: false,
          phaseLabel: Platform.isMacOS
              ? 'Choose where to save backup...'
              : _phaseLabel(_BackupPhase.sharing),
          progress: 100,
          copiedMediaFiles: progressNotifier.value?.totalMediaFiles ?? 0,
          totalMediaFiles: progressNotifier.value?.totalMediaFiles ?? 0,
          currentItemName: p.basename(zipPath),
          eta: Duration.zero,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));

      await _deliverBackupFile(
        zipPath: zipPath,
        rootNavigator: rootNavigator,
      );

      print('[Backup] Backup завершён успешно!');
      _updateProgress(
        BackupProgressState(
          visible: true,
          isActive: false,
          isFinal: true,
          canceling: false,
          phaseLabel: 'Backup ready',
          progress: 100,
          copiedMediaFiles: progressNotifier.value?.totalMediaFiles ?? 0,
          totalMediaFiles: progressNotifier.value?.totalMediaFiles ?? 0,
          currentItemName: p.basename(zipPath),
          eta: Duration.zero,
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      progressNotifier.value = null;
    } on _BackupCanceledException {
      print('[Backup] Backup отменён пользователем.');
      _updateProgress(
        BackupProgressState(
          visible: true,
          isActive: false,
          isFinal: true,
          canceling: true,
          phaseLabel: 'Backup canceled',
          progress: progressNotifier.value?.progress ?? 0,
          copiedMediaFiles: progressNotifier.value?.copiedMediaFiles ?? 0,
          totalMediaFiles: progressNotifier.value?.totalMediaFiles ?? 0,
          currentItemName: progressNotifier.value?.currentItemName,
          eta: null,
        ),
      );
      messenger?.showSnackBar(
        const SnackBar(content: Text('Backup canceled')),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      progressNotifier.value = null;
    } on _BackupDeliveryCanceledException {
      _updateProgress(
        BackupProgressState(
          visible: true,
          isActive: false,
          isFinal: true,
          canceling: false,
          phaseLabel: Platform.isMacOS ? 'Save canceled' : 'Share canceled',
          progress: 100,
          copiedMediaFiles: progressNotifier.value?.copiedMediaFiles ?? 0,
          totalMediaFiles: progressNotifier.value?.totalMediaFiles ?? 0,
          currentItemName: progressNotifier.value?.currentItemName,
          eta: null,
        ),
      );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            Platform.isMacOS ? 'Backup save canceled' : 'Backup share canceled',
          ),
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      progressNotifier.value = null;
    } catch (e, st) {
      print('[Backup] Ошибка при создании backup: $e');
      print('[Backup] Stacktrace:\n$st');
      _updateProgress(
        BackupProgressState(
          visible: true,
          isActive: false,
          isFinal: true,
          canceling: false,
          phaseLabel: 'Backup failed',
          progress: progressNotifier.value?.progress ?? 0,
          copiedMediaFiles: progressNotifier.value?.copiedMediaFiles ?? 0,
          totalMediaFiles: progressNotifier.value?.totalMediaFiles ?? 0,
          currentItemName: progressNotifier.value?.currentItemName,
          eta: null,
        ),
      );
      messenger?.showSnackBar(
        const SnackBar(content: Text('Failed to create backup')),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      progressNotifier.value = null;
    } finally {
      _activeCancelToken = null;
      _isRunning = false;
    }
  }

  static Future<void> _deliverBackupFile({
    required String zipPath,
    required NavigatorState? rootNavigator,
  }) async {
    final fileName = p.basename(zipPath);

    if (!kIsWeb && Platform.isMacOS) {
      print('[Backup] Открываем системное окно Save As...');
      final destinationPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      if (destinationPath == null || destinationPath.isEmpty) {
        throw _BackupDeliveryCanceledException();
      }
      if (destinationPath != zipPath) {
        await File(zipPath).copy(destinationPath);
      }
      return;
    }

    print('[Backup] Открываем системное окно share...');
    final shareOrigin = _shareOriginRect(rootNavigator);
    print('[Backup] sharePositionOrigin: $shareOrigin');
    final result = await Share.shareXFiles(
      [XFile(zipPath, mimeType: 'application/zip')],
      subject: 'Photographers Reference backup',
      text: Platform.isIOS
          ? 'Choose Save to Files or share the backup'
          : 'Photographers Reference backup',
      sharePositionOrigin: shareOrigin,
      fileNameOverrides: [fileName],
    );
    if (result.status == ShareResultStatus.dismissed) {
      throw _BackupDeliveryCanceledException();
    }
  }

  static Rect _shareOriginRect(NavigatorState? navigator) {
    final box = navigator?.context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final size = box.size;
      print('[Backup] share origin box size: $size');
      final topLeft = box.localToGlobal(Offset.zero);
      return topLeft & box.size;
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? WidgetsBinding.instance.platformDispatcher.views.first
        : null;
    final size = view == null
        ? const Size(1200, 800)
        : view.physicalSize / view.devicePixelRatio;
    print('[Backup] share origin fallback size: $size');
    final safeWidth = size.width <= 0 ? 1.0 : size.width;
    final safeHeight = size.height <= 0 ? 1.0 : size.height;
    return Rect.fromLTWH(
      safeWidth / 2,
      safeHeight / 2,
      1,
      1,
    );
  }

  static Future<void> restoreFromBackup(BuildContext context) async {
    final rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'Restoring will replace your current database and photos. '
          'This cannot be undone. We strongly recommend creating a backup before proceeding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (agreed != true) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select backup file',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    final backupFile = File(result.files.single.path!);
    if (!await backupFile.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup file not found')),
      );
      return;
    }

    _RestoreProgressSnapshot snapshot = const _RestoreProgressSnapshot(
      phase: _RestorePhase.preparing,
      progress: 0,
      processedFiles: 0,
      totalFiles: 0,
    );
    StateSetter? progressSetState;

    void updateRestoreProgress({
      required _RestorePhase phase,
      required double progress,
      required int processedFiles,
      required int totalFiles,
    }) {
      final setState = progressSetState;
      if (setState == null) return;
      setState(() {
        snapshot = _RestoreProgressSnapshot(
          phase: phase,
          progress: progress.clamp(0.0, 100.0),
          processedFiles: processedFiles,
          totalFiles: totalFiles,
        );
      });
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            progressSetState = setState;
            final normalized = (snapshot.progress / 100).clamp(0.0, 1.0);
            return AlertDialog(
              title: const Text('Restoring backup...'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: normalized == 0 ? null : normalized,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_restorePhaseLabel(snapshot.phase)),
                        Text(
                          '${snapshot.progress.toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Files ${snapshot.processedFiles}/${snapshot.totalFiles}',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    try {
      updateRestoreProgress(
        phase: _RestorePhase.preparing,
        progress: 2,
        processedFiles: 0,
        totalFiles: 0,
      );
      await Hive.close();

      final tmp = await getTemporaryDirectory();
      final restoreDir = Directory(p.join(tmp.path, 'backup_restore'));
      if (await restoreDir.exists()) {
        await restoreDir.delete(recursive: true);
      }
      await restoreDir.create(recursive: true);

      final fallbackDir = Directory(p.join(tmp.path, 'backup_fallback'));
      if (await fallbackDir.exists()) {
        await fallbackDir.delete(recursive: true);
      }
      await fallbackDir.create(recursive: true);

      final bytes = await backupFile.readAsBytes();
      final zip = archive.ZipDecoder().decodeBytes(bytes);
      final totalZipFiles = zip.where((file) => file.isFile).length;
      var extractedFiles = 0;
      await _extractArchive(
        zip,
        restoreDir.path,
        onFileWritten: () {
          extractedFiles += 1;
          updateRestoreProgress(
            phase: _RestorePhase.extracting,
            progress: totalZipFiles == 0 ? 30 : (extractedFiles / totalZipFiles) * 30,
            processedFiles: extractedFiles,
            totalFiles: totalZipFiles,
          );
        },
      );

      final root = _resolveRestoreRoot(restoreDir);
      final docs = await getApplicationDocumentsDirectory();

      final currentFilesCount = _countBackupTargetFiles(docs);
      var snapshottedFiles = 0;
      updateRestoreProgress(
        phase: _RestorePhase.snapshottingCurrent,
        progress: 30,
        processedFiles: 0,
        totalFiles: currentFilesCount,
      );
      await _backupExistingTargets(
        docs,
        fallbackDir,
        onFileCopied: () {
          snapshottedFiles += 1;
          updateRestoreProgress(
            phase: _RestorePhase.snapshottingCurrent,
            progress: currentFilesCount == 0
                ? 55
                : 30 + (snapshottedFiles / currentFilesCount) * 25,
            processedFiles: snapshottedFiles,
            totalFiles: currentFilesCount,
          );
        },
      );
      await _deleteExistingBackupTargets(docs);
      final restoreFilesCount = _countBackupTargetFiles(root);
      var restoredFiles = 0;
      updateRestoreProgress(
        phase: _RestorePhase.applyingBackup,
        progress: 55,
        processedFiles: 0,
        totalFiles: restoreFilesCount,
      );
      await _copyRestorePayload(
        root,
        docs,
        onFileCopied: () {
          restoredFiles += 1;
          updateRestoreProgress(
            phase: _RestorePhase.applyingBackup,
            progress: restoreFilesCount == 0
                ? 100
                : 55 + (restoredFiles / restoreFilesCount) * 45,
            processedFiles: restoredFiles,
            totalFiles: restoreFilesCount,
          );
        },
      );

      if (rootNavigator?.canPop() ?? false) {
        rootNavigator!.pop();
      }

      await AppReloadService.instance.reload();
    } catch (e) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final fallbackDir = Directory(p.join(
          (await getTemporaryDirectory()).path,
          'backup_fallback',
        ));
        if (await fallbackDir.exists()) {
          await _deleteExistingBackupTargets(docs);
          await _copyRestorePayload(fallbackDir, docs);
        }
      } catch (_) {}
      if (rootNavigator?.canPop() ?? false) {
        rootNavigator!.pop();
      }
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not restore backup')),
      );
    }
  }

  static Future<void> _extractArchive(
    archive.Archive zip,
    String destPath, {
    void Function()? onFileWritten,
  }) async {
    for (final file in zip) {
      final outPath = p.join(destPath, file.name);
      if (file.isFile) {
        final outFile = File(outPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>, flush: true);
        onFileWritten?.call();
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
  }

  static Directory _resolveRestoreRoot(Directory dir) {
    final entries = dir.listSync(followLinks: false);
    final dirs = entries.whereType<Directory>().toList();
    final files = entries.whereType<File>().toList();
    if (files.isEmpty && dirs.length == 1) {
      return dirs.first;
    }
    return dir;
  }

  static Future<void> _deleteExistingBackupTargets(Directory docs) async {
    final entries = docs.listSync();
    for (final entry in entries) {
      if (entry is File) {
        final name = p.basename(entry.path);
        if (name.endsWith('.hive') || name.endsWith('.lock')) {
          await entry.delete();
        }
      } else if (entry is Directory) {
        if (p.basename(entry.path) == 'photos') {
          await entry.delete(recursive: true);
        }
      }
    }
  }

  static Future<void> _copyRestorePayload(
    Directory from,
    Directory docs, {
    void Function()? onFileCopied,
  }) async {
    final entries = from.listSync();
    for (final entry in entries) {
      if (entry is File) {
        final name = p.basename(entry.path);
        if (name.endsWith('.hive') || name.endsWith('.lock')) {
          await entry.copy(p.join(docs.path, name));
          onFileCopied?.call();
        }
      } else if (entry is Directory) {
        if (p.basename(entry.path) == 'photos') {
          await _copyDir(
            entry,
            Directory(p.join(docs.path, 'photos')),
            onFileCopied: (_) => onFileCopied?.call(),
          );
        }
      }
    }
  }

  static Future<void> _backupExistingTargets(
    Directory docs,
    Directory fallbackDir, {
    void Function()? onFileCopied,
  }) async {
    final entries = docs.listSync();
    for (final entry in entries) {
      if (entry is File) {
        final name = p.basename(entry.path);
        if (name.endsWith('.hive') || name.endsWith('.lock')) {
          await entry.copy(p.join(fallbackDir.path, name));
          onFileCopied?.call();
        }
      } else if (entry is Directory) {
        if (p.basename(entry.path) == 'photos') {
          await _copyDir(
            entry,
            Directory(p.join(fallbackDir.path, 'photos')),
            onFileCopied: (_) => onFileCopied?.call(),
          );
        }
      }
    }
  }

  static int _countBackupTargetFiles(Directory dir) {
    if (!dir.existsSync()) return 0;
    var count = 0;
    final entries = dir.listSync(recursive: true, followLinks: false);
    for (final entry in entries) {
      if (entry is! File) continue;
      final path = entry.path;
      if (path.endsWith('.hive') ||
          path.endsWith('.lock') ||
          path.contains('${p.separator}photos${p.separator}')) {
        count += 1;
      }
    }
    return count;
  }
}
