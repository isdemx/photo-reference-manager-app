// Функция для сжатия изображения в изоляте
import 'dart:io';

import 'package:photographers_reference_app/src/data/utils/photo_compession.dart';

void compressPhotoIsolate(Map<String, dynamic> args) {
  final filePath = args['filePath'] as String;
  final compressSizeKb = args['compressSizeKb'] as int;

  final file = File(filePath);
  PhotoCompressor.compressPhotoSync(file, maxFileSize: compressSizeKb * 1024);
}