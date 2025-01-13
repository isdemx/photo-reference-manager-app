// lib/src/data/repositories/category_repository_impl.dart

import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/repositories/category_repository.dart';
import 'package:uuid/uuid.dart';

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

  Future<void> initializeDefaultCategory() async {
    // Проверяем, есть ли хотя бы одна категория
    if (categoryBox.isEmpty) {
      // Если категорий нет, создаём дефолтную категорию
      final defaultCategory = Category(
        id: const Uuid().v4(), // Уникальный идентификатор
        name: "General",
        sortOrder: 0,
        isPrivate: false, // Делаем категорию публичной по умолчанию
        collapsed: false, // Категория не свернута
        folderIds: [], // Пустой список папок
      );
      await addCategory(defaultCategory);
      print('Default category "General" has been added to the database.');
    } else {
      print('Categories already exist, no default category added.');
    }
  }
}
