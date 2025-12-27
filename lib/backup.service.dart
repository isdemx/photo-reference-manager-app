import 'dart:io';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart' as archive;

class BackupService {
  /// Собираем ZIP-файл.
  /// [onProgress] получает значение 0..100 (double).
  static Future<String> _buildZip({
    void Function(double progress)? onProgress,
  }) async {
    print('[Backup] Начало создания ZIP...');
    final docs = await getApplicationDocumentsDirectory();
    final tmp = await getTemporaryDirectory();

    print('[Backup] documentsDir: ${docs.path}');
    print('[Backup] tempDir: ${tmp.path}');

    final workDir = Directory(p.join(tmp.path, 'backup_build'));
    if (await workDir.exists()) {
      print('[Backup] Удаляем предыдущую временную папку...');
      await workDir.delete(recursive: true);
    }
    await workDir.create(recursive: true);
    print('[Backup] Создана временная рабочая папка: ${workDir.path}');

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
    if (await photosSrc.exists()) {
      print('[Backup] Копируем директорию с фото...');
      await _copyDir(photosSrc, Directory(p.join(workDir.path, 'photos')));
    } else {
      print('[Backup] Папка "photos" не найдена.');
    }

    // Упаковка
    final zipPath = p.join(
      tmp.path,
      'backup_${DateTime.now().toIso8601String()}.zip',
    );

    print('[Backup] Начинаем упаковку в: $zipPath');

    await ZipFile.createFromDirectory(
      sourceDir: workDir,
      zipFile: File(zipPath),
      recurseSubDirs: true,
      onZipping: (filePath, isDir, progress) {
        final name = p.basename(filePath);
        print('[Backup] ${progress.toStringAsFixed(1)}% → $name');

        // Пробрасываем прогресс наружу
        if (onProgress != null) {
          onProgress(progress); // progress: 0..100
        }

        return ZipFileOperation.includeItem;
      },
    );

    await workDir.delete(recursive: true);
    print('[Backup] Временная рабочая папка удалена.');

    final zipSize = await File(zipPath).length();
    print(
      '[Backup] ZIP-файл создан: $zipPath '
      '(${(zipSize / 1024 / 1024).toStringAsFixed(2)} MB)',
    );

    return zipPath;
  }

  static Future<void> _copyDir(Directory from, Directory to) async {
    await for (final ent in from.list(recursive: true)) {
      final rel = p.relative(ent.path, from: from.path);
      final newPath = p.join(to.path, rel);
      if (ent is File) {
        await File(newPath).create(recursive: true);
        await ent.copy(newPath);
        print('[Backup] Скопирован файл: $rel');
      } else if (ent is Directory) {
        await Directory(newPath).create(recursive: true);
        print('[Backup] Создана папка: $rel');
      }
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

    print('[Backup] Пользователь подтвердил. Показываем прогресс-диалог...');

    // Диалог с прогрессом
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        double progress = 0.0; // 0..100

        return StatefulBuilder(
          builder: (ctx, setState) {
            // Стартуем бэкап только один раз — при первой сборке виджета,
            // когда progress == 0.0
            if (progress == 0.0) {
              Future.microtask(() async {
                try {
                  print('[Backup] Закрываем Hive...');
                  await Hive.close();

                  print('[Backup] Стартуем _buildZip...');
                  final zipPath = await _buildZip(
                    onProgress: (p) {
                      // Обновление прогресса
                      setState(() {
                        progress = p;
                      });
                    },
                  );

                  if (Navigator.of(dialogCtx).canPop()) {
                    Navigator.of(dialogCtx).pop(); // закрываем прогресс-диалог
                  }

                  await Future<void>.delayed(
                      const Duration(milliseconds: 200));

                  print('[Backup] Открываем системное окно share...');
                  final rootContext =
                      Navigator.of(context, rootNavigator: true).context;
                  final shareOrigin = _shareOriginRect(rootContext);
                  print('[Backup] sharePositionOrigin: $shareOrigin');
                  await Share.shareXFiles(
                    [XFile(zipPath)],
                    text: 'Photographers Reference backup',
                    sharePositionOrigin: shareOrigin,
                  );

                  print('[Backup] Backup завершён успешно!');
                } catch (e, st) {
                  print('[Backup] Ошибка при создании backup: $e');
                  print('[Backup] Stacktrace:\n$st');

                  if (Navigator.of(dialogCtx).canPop()) {
                    Navigator.of(dialogCtx).pop();
                  }

                  // По желанию здесь можно показать SnackBar/AlertDialog об ошибке
                  // ScaffoldMessenger.of(context).showSnackBar(...)
                }
              });
            }

            final normalized = (progress / 100).clamp(0.0, 1.0);

            return AlertDialog(
              title: const Text('Creating backup...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: normalized == 0 ? null : normalized),
                  const SizedBox(height: 12),
                  Text(
                    progress > 0
                        ? '${progress.toStringAsFixed(0)} %'
                        : 'Preparing files...',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Rect _shareOriginRect(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
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
        ? MediaQuery.of(context).size
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
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'Restoring will replace your current database and photos. '
          'This cannot be undone. Make sure you trust the backup file.',
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

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return const AlertDialog(
          title: Text('Restoring backup...'),
          content: SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );

    try {
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
      await _extractArchive(zip, restoreDir.path);

      final root = _resolveRestoreRoot(restoreDir);
      final docs = await getApplicationDocumentsDirectory();

      await _backupExistingTargets(docs, fallbackDir);
      await _deleteExistingBackupTargets(docs);
      await _copyRestorePayload(root, docs);

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore completed. Please restart the app.'),
          duration: Duration(seconds: 6),
        ),
      );
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
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not restore backup')),
      );
    }
  }

  static Future<void> _extractArchive(archive.Archive zip, String destPath) async {
    for (final file in zip) {
      final outPath = p.join(destPath, file.name);
      if (file.isFile) {
        final outFile = File(outPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>, flush: true);
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

  static Future<void> _copyRestorePayload(Directory from, Directory docs) async {
    final entries = from.listSync();
    for (final entry in entries) {
      if (entry is File) {
        final name = p.basename(entry.path);
        if (name.endsWith('.hive') || name.endsWith('.lock')) {
          await entry.copy(p.join(docs.path, name));
        }
      } else if (entry is Directory) {
        if (p.basename(entry.path) == 'photos') {
          await _copyDir(entry, Directory(p.join(docs.path, 'photos')));
        }
      }
    }
  }

  static Future<void> _backupExistingTargets(Directory docs, Directory fallbackDir) async {
    final entries = docs.listSync();
    for (final entry in entries) {
      if (entry is File) {
        final name = p.basename(entry.path);
        if (name.endsWith('.hive') || name.endsWith('.lock')) {
          await entry.copy(p.join(fallbackDir.path, name));
        }
      } else if (entry is Directory) {
        if (p.basename(entry.path) == 'photos') {
          await _copyDir(entry, Directory(p.join(fallbackDir.path, 'photos')));
        }
      }
    }
  }
}
