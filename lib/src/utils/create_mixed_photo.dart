import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;


Future<File> createMixedImage(File image1, File image2, int index) async {
  // Проверяем и читаем данные изображения
  final imageBytes1 = await image1.readAsBytes();
  final imageBytes2 = await image2.readAsBytes();

  if (imageBytes1.isEmpty || imageBytes2.isEmpty) {
    throw Exception('One of the images is empty or corrupted.');
  }

  // Проверяем формат
  if (!['.png', '.jpg', '.jpeg'].contains(p.extension(image1.path).toLowerCase()) ||
      !['.png', '.jpg', '.jpeg'].contains(p.extension(image2.path).toLowerCase())) {
    throw Exception('Unsupported image format for ${image1.path} or ${image2.path}');
  }

  // Логируем путь и размер
  print('Image 1 path: ${image1.path}, size: ${image1.lengthSync()} bytes');
  print('Image 2 path: ${image2.path}, size: ${image2.lengthSync()} bytes');

  // Декодируем изображения
  final ui.Image imageA = await decodeImageFromList(imageBytes1);
  final ui.Image imageB = await decodeImageFromList(imageBytes2);

  final size = Size(800, 800); // Итоговый размер изображения
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Фон
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = Colors.black,
  );

  // Функция для расчета пропорций
  Rect calculateFitRect(ui.Image image, Size targetSize) {
    final imageAspectRatio = image.width / image.height;
    final targetAspectRatio = targetSize.width / targetSize.height;

    if (imageAspectRatio > targetAspectRatio) {
      final width = targetSize.width;
      final height = width / imageAspectRatio;
      return Rect.fromLTWH(0, (targetSize.height - height) / 2, width, height);
    } else {
      final height = targetSize.height;
      final width = height * imageAspectRatio;
      return Rect.fromLTWH((targetSize.width - width) / 2, 0, width, height);
    }
  }

  // Рисуем изображения
  final rectA = calculateFitRect(imageA, size);
  canvas.drawImageRect(
    imageA,
    Rect.fromLTWH(0, 0, imageA.width.toDouble(), imageA.height.toDouble()),
    rectA,
    Paint(),
  );

  final rectB = calculateFitRect(imageB, size);
  canvas.drawImageRect(
    imageB,
    Rect.fromLTWH(0, 0, imageB.width.toDouble(), imageB.height.toDouble()),
    rectB,
    Paint()..blendMode = BlendMode.overlay,
  );

  // Генерируем изображение
  final picture = recorder.endRecording();
  final img = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

  // Сохраняем изображение
  final outputDir = await getTemporaryDirectory();
  final outputFile = File('${outputDir.path}/mixed_$index.png');
  await outputFile.writeAsBytes(byteData!.buffer.asUint8List());

  return outputFile;
}
