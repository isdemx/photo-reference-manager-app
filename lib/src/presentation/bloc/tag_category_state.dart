// lib/src/presentation/bloc/tag_category_state.dart
part of 'tag_category_bloc.dart';

abstract class TagCategoryState extends Equatable {
  const TagCategoryState();

  @override
  List<Object?> get props => [];
}

class TagCategoryInitial extends TagCategoryState {
  const TagCategoryInitial();
}

class TagCategoryLoading extends TagCategoryState {
  const TagCategoryLoading();
}

class TagCategoryLoaded extends TagCategoryState {
  final List<TagCategory> categories;

  const TagCategoryLoaded(this.categories);

  @override
  List<Object?> get props => [categories];
}

class TagCategoryError extends TagCategoryState {
  final String message;

  const TagCategoryError(this.message);

  @override
  List<Object?> get props => [message];
}
