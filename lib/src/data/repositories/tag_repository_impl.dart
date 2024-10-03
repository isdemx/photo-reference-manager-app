// lib/src/data/repositories/tag_repository_impl.dart

import 'dart:math';

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
    // print('getTags ${tagBox.values.toList()}');
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
}
