// lib/src/domain/repositories/tag_repository.dart

import 'package:photographers_reference_app/src/domain/entities/tag.dart';

abstract class TagRepository {
  Future<void> addTag(Tag tag);
  Future<List<Tag>> getTags();
  Future<void> deleteTag(String id);
  Future<void> updateTag(Tag tag);
}
