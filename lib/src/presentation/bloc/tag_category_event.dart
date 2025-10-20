// lib/src/presentation/bloc/tag_category_event.dart
part of 'tag_category_bloc.dart';

abstract class TagCategoryEvent extends Equatable {
  const TagCategoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadTagCategories extends TagCategoryEvent {
  const LoadTagCategories();
}

class AddTagCategory extends TagCategoryEvent {
  final TagCategory category;

  const AddTagCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class UpdateTagCategory extends TagCategoryEvent {
  final TagCategory category;

  const UpdateTagCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class DeleteTagCategory extends TagCategoryEvent {
  final String id;
  /// Переназначить теги этой категории в другую категорию.
  /// Если null — у тегов будет снята категория (tagCategoryId = null).
  final String? reassignTo;

  const DeleteTagCategory({required this.id, this.reassignTo});

  @override
  List<Object?> get props => [id, reassignTo];
}

class ReorderTagCategories extends TagCategoryEvent {
  /// Новый порядок категорий по списку их id
  final List<String> idsInOrder;

  const ReorderTagCategories(this.idsInOrder);

  @override
  List<Object?> get props => [idsInOrder];
}
