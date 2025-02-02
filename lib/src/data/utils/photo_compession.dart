// lib/src/utils/photo_compressor.dart

import 'dart:io';
import 'package:image/image.dart' as img;

class PhotoCompressor {
  // Синхронный метод для уменьшения изображения
  static void compressPhotoSync(File file, {int maxFileSize = 200 * 1024, int maxShortSide = 800}) {
    // Шаг 1: Чтение изображения
    final imageBytes = file.readAsBytesSync();
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      throw Exception("Failed to load image");
    }

    // Шаг 2: Определение новой ширины и высоты
    int width = originalImage.width;
    int height = originalImage.height;

    if (width > height && height > maxShortSide) {
      width = (maxShortSide * width / height).round();
      height = maxShortSide;
    } else if (width <= height && width > maxShortSide) {
      height = (maxShortSide * height / width).round();
      width = maxShortSide;
    }

    // Шаг 3: Изменение размера изображения
    img.Image resizedImage;
    if (width == originalImage.width && height == originalImage.height) {
      resizedImage = originalImage;
    } else {
      resizedImage = img.copyResize(originalImage, width: width, height: height);
    }

    // Шаг 4: Сжатие изображения в jpg
    int quality = 100; // Начинаем с максимального качества
    List<int> compressedBytes = img.encodeJpg(resizedImage, quality: quality);

    // Шаг 5: Понижаем качество, пока размер не станет меньше maxFileSize
    while (compressedBytes.length > maxFileSize && quality > 5) {
      quality -= 5; // Уменьшаем качество на 5 шагов
      compressedBytes = img.encodeJpg(resizedImage, quality: quality);
    }

    // Шаг 6: Сохраняем новое сжатое изображение
    file.writeAsBytesSync(compressedBytes);
  }
}
