// lib/src/data/repositories/category_repository_impl.dart

import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final Box<Category> categoryBox;

  CategoryRepositoryImpl(this.categoryBox);

  @override
  Future<void> addCategory(Category category) async {
    await categoryBox.put(category.id, category);
  }

  @override
  Future<List<Category>> getCategories() async {
    final categories = categoryBox.values.toList();

    // Сортировка категорий по sortOrder перед возвратом
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return categories;
  }

  @override
  Future<void> deleteCategory(String id) async {
    await categoryBox.delete(id);
  }

  @override
  Future<void> updateCategory(Category category) async {
    try {
      await categoryBox.put(category.id, category);
      print('Category SAVED');
    } catch (e) {
      print('Error saving category: $e');
      rethrow;
    }
  }
}
