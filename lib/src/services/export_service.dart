import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/entities/category.dart';
import '../domain/entities/folder.dart';
import '../domain/entities/photo.dart';
import '../domain/entities/tag.dart';
import '../domain/entities/collage.dart';

class ExportService {
  static Future<void> run() async {
    try {
      final cats = await Hive.openBox<Category>('categories');
      final folders = await Hive.openBox<Folder>('folders');
      final photos = await Hive.openBox<Photo>('photos');
      final tags = await Hive.openBox<Tag>('tags');
      final collages = await Hive.openBox<Collage>('collages');

      final data = {
        'categories': cats.values.map((e) => e.toJson()).toList(),
        'folders': folders.values.map((e) => e.toJson()).toList(),
        'photos': photos.values.map((e) => e.toJson()).toList(),
        'tags': tags.values.map((e) => e.toJson()).toList(),
        'collages': collages.values.map((e) => e.toJson()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      print('✅ Экспорт завершён:\n$jsonString');
    } catch (e, st) {
      print('❌ ExportService error: $e\n$st');
    }
  }
}

