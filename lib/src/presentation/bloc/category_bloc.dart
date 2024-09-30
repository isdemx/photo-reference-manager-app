// lib/src/presentation/blocs/category_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/repositories/category_repository.dart';

part 'category_event.dart';
part 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository categoryRepository;

  CategoryBloc({required this.categoryRepository}) : super(CategoryInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<AddCategory>(_onAddCategory);
    on<DeleteCategory>(_onDeleteCategory);
    on<UpdateCategory>(_onUpdateCategory);
  }

  Future<void> _onLoadCategories(
      LoadCategories event, Emitter<CategoryState> emit) async {
    emit(CategoryLoading());
    try {
      final categories = await categoryRepository.getCategories();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(const CategoryError('Failed to load categories'));
    }
  }

  Future<void> _onAddCategory(
      AddCategory event, Emitter<CategoryState> emit) async {
    try {
      await categoryRepository.addCategory(event.category);
      add(LoadCategories());
    } catch (e) {
      emit(const CategoryError('Failed to add category'));
    }
  }

  Future<void> _onDeleteCategory(
      DeleteCategory event, Emitter<CategoryState> emit) async {
    try {
      await categoryRepository.deleteCategory(event.id);
      add(LoadCategories());
    } catch (e) {
      emit(const CategoryError('Failed to delete category'));
    }
  }

  Future<void> _onUpdateCategory(
      UpdateCategory event, Emitter<CategoryState> emit) async {
    try {
      await categoryRepository.updateCategory(event.category);
      add(LoadCategories());
    } catch (e) {
      emit(const CategoryError('Failed to update category'));
    }
  }
}
