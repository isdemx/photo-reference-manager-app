// lib/src/domain/repositories/category_repository.dart

import 'package:photographers_reference_app/src/domain/entities/category.dart';

abstract class CategoryRepository {
  Future<void> addCategory(Category category);
  Future<List<Category>> getCategories();
  Future<void> deleteCategory(String id);
  Future<void> updateCategory(Category category);
}
