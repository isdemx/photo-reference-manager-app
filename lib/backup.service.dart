import 'dart:io';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  static Future<String> _buildZip() async {
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
        return ZipFileOperation.includeItem;
      },
    );

    await workDir.delete(recursive: true);
    print('[Backup] Временная рабочая папка удалена.');

    final zipSize = await File(zipPath).length();
    print('[Backup] ZIP-файл создан: $zipPath (${(zipSize / 1024 / 1024).toStringAsFixed(2)} MB)');

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

  static Future<void> promptAndRun(BuildContext context) async {
    print('[Backup] Показываем диалог пользователю...');
    final agreed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Сделать резервную копию?'),
        content: const Text(
          'Мы упакуем базу Hive и все медиа в ZIP и предложим сохранить '
          'файл в «Файлы», iCloud или отправить AirDrop.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(_, true), child: const Text('Создать')),
        ],
      ),
    );

    if (agreed == true) {
      try {
        print('[Backup] Пользователь подтвердил. Закрываем Hive...');
        await Hive.close();

        final zip = await _buildZip();

        print('[Backup] Открываем системное окно share...');
        await Share.shareXFiles([XFile(zip)], text: 'Photographers Reference backup');

        print('[Backup] Backup завершён успешно!');
      } catch (e, st) {
        print('[Backup] Ошибка при создании backup: $e');
        print('[Backup] Stacktrace:\n$st');
      }
    } else {
      print('[Backup] Пользователь отказался от backup.');
    }
  }
}
