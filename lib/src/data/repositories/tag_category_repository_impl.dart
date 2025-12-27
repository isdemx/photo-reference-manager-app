// lib/src/data/repositories/tag_category_repository_impl.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';
import 'package:photographers_reference_app/src/domain/repositories/tag_category_repository.dart';
import 'package:photographers_reference_app/src/services/shared_tags_sync_service.dart';

class TagCategoryRepositoryImpl implements TagCategoryRepository {
  final Box<TagCategory> categoryBox;
  final Box<Tag> tagBox;

  TagCategoryRepositoryImpl(this.categoryBox, this.tagBox);

  @override
  Future<void> addTagCategory(TagCategory category) async {
    await categoryBox.put(category.id, category);
    await _syncSharedTags();
  }

  @override
  Future<List<TagCategory>> getTagCategories() async {
    final list = categoryBox.values.toList();
    list.sort((a, b) {
      final s = a.sortOrder.compareTo(b.sortOrder);
      return s != 0 ? s : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  @override
  Future<void> deleteTagCategory(String id, {String? reassignToCategoryId}) async {
    // 1) Обновим теги, указывающие на удаляемую категорию
    final toUpdate = <String, Tag>{};
    for (final key in tagBox.keys) {
      final tag = tagBox.get(key);
      if (tag == null) continue;
      if (tag.tagCategoryId == id) {
        final newTag = tag.copyWith(tagCategoryId: reassignToCategoryId);
        toUpdate[tag.id] = newTag;
      }
    }
    if (toUpdate.isNotEmpty) {
      await tagBox.putAll(toUpdate.map((k, v) => MapEntry(k, v)));
    }

    // 2) Удаляем категорию
    await categoryBox.delete(id);

    // 3) Нормализуем sortOrder (плотные индексы 0..n-1)
    await _normalizeSortOrder();
    await _syncSharedTags();
  }

  @override
  Future<void> updateTagCategory(TagCategory category) async {
    await categoryBox.put(category.id, category);
    await _syncSharedTags();
  }

  @override
  Future<void> reorderTagCategories(List<String> idsInOrder) async {
    for (int i = 0; i < idsInOrder.length; i++) {
      final id = idsInOrder[i];
      final c = categoryBox.get(id);
      if (c != null && c.sortOrder != i) {
        await categoryBox.put(id, c.copyWith(sortOrder: i));
      }
    }
    await _syncSharedTags();
  }

  @override
  Future<void> initializeDefaultTagCategory() async {
    if (categoryBox.isEmpty) {
      final def = TagCategory(
        id: UniqueKey().toString(),
        name: 'General',
        dateCreated: DateTime.now(),
        sortOrder: 0,
      );
      await categoryBox.put(def.id, def);
    }
    await _syncSharedTags();
  }

  Future<void> _normalizeSortOrder() async {
    final all = categoryBox.values.toList()
      ..sort((a, b) {
        final s = a.sortOrder.compareTo(b.sortOrder);
        return s != 0 ? s : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    for (int i = 0; i < all.length; i++) {
      final c = all[i];
      if (c.sortOrder != i) {
        await categoryBox.put(c.id, c.copyWith(sortOrder: i));
      }
    }
  }

  Future<void> _syncSharedTags() async {
    await SharedTagsSyncService().syncTags(tagBox.values.toList());
  }
}
