import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';

class SharedTagsSyncService {
  static const MethodChannel _channel = MethodChannel('refma/shared_tags');

  Future<void> syncTags(List<Tag> tags) async {
    if (kIsWeb || !Platform.isIOS) return;

    try {
      final categoryNames = <String, String>{};
      if (Hive.isBoxOpen('tag_categories')) {
        final categoryBox = Hive.box<TagCategory>('tag_categories');
        for (final category in categoryBox.values) {
          categoryNames[category.id] = category.name;
        }
      }

      final payload = jsonEncode(tags.map((t) {
        final map = t.toJson();
        final categoryId = t.tagCategoryId;
        if (categoryId != null && categoryNames.containsKey(categoryId)) {
          map['tagCategoryName'] = categoryNames[categoryId];
        }
        return map;
      }).toList());
      await _channel.invokeMethod('setTagsJson', payload);
    } catch (e) {
      // ignore: avoid_print
      print('[SharedTagsSync] $e');
    }
  }
}
