// lib/src/services/import_json_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';

import '../domain/entities/category.dart';
import '../domain/entities/folder.dart';
import '../domain/entities/photo.dart';
import '../domain/entities/tag.dart';
import '../domain/entities/collage.dart';

class ImportJsonService {
  static Future<void> run() async {
    final String jsonString =
        await rootBundle.loadString('assets/old-mac-refma-hive.json');
    final Map<String, dynamic> data = json.decode(jsonString);

    final catsBox = await Hive.openBox<Category>('categories');
    final foldersBox = await Hive.openBox<Folder>('folders');
    final photosBox = await Hive.openBox<Photo>('photos');
    final tagsBox = await Hive.openBox<Tag>('tags');
    final collagesBox = await Hive.openBox<Collage>('collages');

    int added = 0;

    for (final item in data['categories'] ?? []) {
      final model = Category.fromJson(item);
      if (!catsBox.values.any((x) => x.id == model.id)) {
        await catsBox.add(model);
        added++;
      }
    }

    for (final item in data['folders'] ?? []) {
      final model = Folder.fromJson(item);
      if (!foldersBox.values.any((x) => x.id == model.id)) {
        await foldersBox.add(model);
        added++;
      }
    }

    for (final item in data['photos'] ?? []) {
      final model = Photo.fromJson(item);
      if (!photosBox.values.any((x) => x.id == model.id)) {
        await photosBox.add(model);
        added++;
      }
    }

    for (final item in data['tags'] ?? []) {
      final model = Tag.fromJson(item);
      if (!tagsBox.values.any((x) => x.id == model.id)) {
        await tagsBox.add(model);
        added++;
      }
    }

    for (final item in data['collages'] ?? []) {
      final model = Collage.fromJson(item);
      if (!collagesBox.values.any((x) => x.id == model.id)) {
        await collagesBox.add(model);
        added++;
      }
    }

    print('✅ Импорт JSON завершён. Добавлено $added объектов');
  }
}
