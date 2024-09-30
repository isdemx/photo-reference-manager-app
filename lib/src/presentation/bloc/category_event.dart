// lib/src/presentation/blocs/category_event.dart

part of 'category_bloc.dart';

abstract class CategoryEvent extends Equatable {
  const CategoryEvent();

  @override
  List<Object> get props => [];
}

class LoadCategories extends CategoryEvent {}

class AddCategory extends CategoryEvent {
  final Category category;

  const AddCategory(this.category);

  @override
  List<Object> get props => [category];
}

class DeleteCategory extends CategoryEvent {
  final String id;

  const DeleteCategory(this.id);

  @override
  List<Object> get props => [id];
}

class UpdateCategory extends CategoryEvent {
  final Category category;

  const UpdateCategory(this.category);

  @override
  List<Object> get props => [category];
}
