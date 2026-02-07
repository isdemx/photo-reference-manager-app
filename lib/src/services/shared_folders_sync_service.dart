import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';

class SharedFoldersSyncService {
  static const MethodChannel _channel = MethodChannel('refma/shared_folders');

  Future<void> syncFolders(List<Folder> folders) async {
    if (kIsWeb || !Platform.isIOS) return;

    try {
      final categoryNames = <String, String>{};
      if (Hive.isBoxOpen('categories')) {
        final categoryBox = Hive.box<Category>('categories');
        for (final category in categoryBox.values) {
          categoryNames[category.id] = category.name;
        }
      }

      final payload = jsonEncode(folders.map((f) {
        final map = f.toJson();
        final categoryId = f.categoryId;
        if (categoryId.isNotEmpty && categoryNames.containsKey(categoryId)) {
          map['categoryName'] = categoryNames[categoryId];
        }
        return map;
      }).toList());
      await _channel.invokeMethod('setFoldersJson', payload);
    } catch (e) {
      // ignore: avoid_print
      print('[SharedFoldersSync] $e');
    }
  }
}
