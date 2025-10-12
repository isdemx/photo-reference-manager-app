import 'dart:io';
import 'dart:isolate';

import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:photographers_reference_app/src/domain/entities/photo_info.dart';


class PhotoIndexer {
  /// Поддерживаемые расширения
  static const _exts = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.heif'];

  /// Быстрая индексация: читаем только размеры (заголовки), без полного декода.
  static Future<List<PhotoInfo>> indexFolderFast(String dirPath, {int thumbLongEdge = 768}) async {
    return await Isolate.run(() async {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return <PhotoInfo>[];

      final entries = dir
          .listSync(recursive: false, followLinks: false)
          .whereType<File>()
          .where((f) => _exts.contains(p.extension(f.path).toLowerCase()))
          .toList();

      final thumbsDir = Directory(p.join(dirPath, '.thumbs'));
      if (!thumbsDir.existsSync()) thumbsDir.createSync(recursive: true);

      final result = <PhotoInfo>[];

      for (final f in entries) {
        try {
          final sz = ImageSizeGetter.getSize(FileInput(f));
          final id = p.basenameWithoutExtension(f.path);
          final thumbPath = p.join(thumbsDir.path, '$id.jpg');

          result.add(PhotoInfo(
            id: id,
            path: f.path,
            width: sz.width,
            height: sz.height,
            thumbPath: thumbPath,
          ));
        } catch (_) {
          // ignore broken/unsupported files
        }
      }
      return result;
    });
  }

  /// Генерация миниатюры в изоляте. Если уже существует — пропускаем.
  static Future<void> ensureThumb(PhotoInfo info, {int longEdge = 768}) async {
    await Isolate.run(() async {
      final inFile = File(info.path);
      if (!await inFile.exists()) return;
      final outFile = File(info.thumbPath);
      if (await outFile.exists()) return;

      final w = info.width;
      final h = info.height;
      if (w <= 0 || h <= 0) return;

      final scale = (w >= h) ? longEdge / w : longEdge / h;
      final targetW = (w * scale).round().clamp(1, w);
      final targetH = (h * scale).round().clamp(1, h);

      final bytes = await FlutterImageCompress.compressWithFile(
        inFile.path,
        minWidth: targetW,
        minHeight: targetH,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      if (bytes != null) {
        await outFile.writeAsBytes(bytes, flush: true);
      }
    });
  }
}
