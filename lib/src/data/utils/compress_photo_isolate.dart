// Функция для сжатия изображения в изоляте
import 'dart:io';

import 'package:photographers_reference_app/src/data/utils/photo_compession.dart';

void compressPhotoIsolate(String filePath) {
  final file = File(filePath);
  PhotoCompressor.compressPhotoSync(file, maxFileSize: 200 * 1024);
}