// lib/src/domain/repositories/tag_category_repository.dart
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';

abstract class TagCategoryRepository {
  Future<void> addTagCategory(TagCategory category);
  Future<List<TagCategory>> getTagCategories(); // отсортировано по sortOrder, затем name
  Future<void> deleteTagCategory(String id, {String? reassignToCategoryId});
  Future<void> updateTagCategory(TagCategory category);
  Future<void> reorderTagCategories(List<String> idsInOrder);
  Future<void> initializeDefaultTagCategory(); // создаст 'General' при пустой базе
}
