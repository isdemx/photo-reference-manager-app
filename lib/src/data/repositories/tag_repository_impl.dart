// lib/src/data/repositories/tag_repository_impl.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/domain/repositories/tag_repository.dart';

class TagRepositoryImpl implements TagRepository {
  final Box<Tag> tagBox;

  TagRepositoryImpl(this.tagBox);

  @override
  Future<void> addTag(Tag tag) async {
    print('addTag $tag');
    await tagBox.put(tag.id, tag);
  }

  @override
  Future<List<Tag>> getTags() async {
    return tagBox.values.toList();
  }

  @override
  Future<void> deleteTag(String id) async {
    await tagBox.delete(id);
  }

  @override
  Future<void> updateTag(Tag tag) async {
    try {
      print('repo updateTag ${tag.toString()}');
      await tagBox.put(tag.id, tag);
      print('TAG SAVED');
    } catch (e) {
      print('Error saving tag: $e');
      rethrow;
    }
  }

  // Метод для инициализации тега "Not Ref" при старте
  Future<void> initializeDefaultTags() async {
    // Список тегов, которые должны быть в базе
    final List<Map<String, dynamic>> defaultTags = [
      {'name': 'Not Ref', 'color': const Color.fromARGB(255, 212, 61, 10)},
      {'name': 'bw', 'color': const Color.fromARGB(96, 97, 97, 97)},
      {'name': 'nature', 'color': const Color.fromARGB(255, 26, 194, 14)},
      {'name': 'portrait', 'color': const Color.fromARGB(255, 215, 141, 44)},
    ];

    for (var tagData in defaultTags) {
      // Проверяем, существует ли тег с данным именем
      final existingTags =
          tagBox.values.where((tag) => tag.name == tagData['name']).toList();

      if (existingTags.isEmpty) {
        // Если тега нет, добавляем новый тег
        final newTag = Tag(
          id: UniqueKey().toString(), // Уникальный идентификатор для тега
          name: tagData['name'] as String,
          colorValue: (tagData['color'] as Color).value, // Цвет по умолчанию
        );
        await addTag(newTag);
        print(
            'Default tag "${tagData['name']}" has been added to the database.');
      }
    }
  }
}
