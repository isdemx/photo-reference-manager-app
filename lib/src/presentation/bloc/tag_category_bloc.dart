// lib/src/presentation/bloc/tag_category_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';
import 'package:photographers_reference_app/src/domain/repositories/tag_category_repository.dart';

part 'tag_category_event.dart';
part 'tag_category_state.dart';

class TagCategoryBloc extends Bloc<TagCategoryEvent, TagCategoryState> {
  final TagCategoryRepository tagCategoryRepository;

  TagCategoryBloc({required this.tagCategoryRepository})
      : super(TagCategoryInitial()) {
    on<LoadTagCategories>(_onLoad);
    on<AddTagCategory>(_onAdd);
    on<UpdateTagCategory>(_onUpdate);
    on<DeleteTagCategory>(_onDelete);
    on<ReorderTagCategories>(_onReorder);
  }

  Future<void> _onLoad(
    LoadTagCategories event,
    Emitter<TagCategoryState> emit,
  ) async {
    emit(TagCategoryLoading());
    try {
      final items = await tagCategoryRepository.getTagCategories();
      emit(TagCategoryLoaded(items));
    } catch (e) {
      emit(const TagCategoryError('Failed to load tag categories'));
    }
  }

  Future<void> _onAdd(
    AddTagCategory event,
    Emitter<TagCategoryState> emit,
  ) async {
    final prev = state;
    if (prev is TagCategoryLoaded) {
      emit(TagCategoryLoading());
      try {
        await tagCategoryRepository.addTagCategory(event.category);
        final items = await tagCategoryRepository.getTagCategories();
        emit(TagCategoryLoaded(items));
      } catch (e) {
        emit(const TagCategoryError('Failed to add tag category'));
        // Вернёмся к предыдущему успешному состоянию, если было
        if (prev is TagCategoryLoaded) emit(prev);
      }
    }
  }

  Future<void> _onUpdate(
    UpdateTagCategory event,
    Emitter<TagCategoryState> emit,
  ) async {
    final prev = state;
    if (prev is TagCategoryLoaded) {
      emit(TagCategoryLoading());
      try {
        await tagCategoryRepository.updateTagCategory(event.category);
        final items = await tagCategoryRepository.getTagCategories();
        emit(TagCategoryLoaded(items));
      } catch (e) {
        emit(const TagCategoryError('Failed to update tag category'));
        if (prev is TagCategoryLoaded) emit(prev);
      }
    }
  }

  Future<void> _onDelete(
    DeleteTagCategory event,
    Emitter<TagCategoryState> emit,
  ) async {
    final prev = state;
    if (prev is TagCategoryLoaded) {
      emit(TagCategoryLoading());
      try {
        await tagCategoryRepository.deleteTagCategory(
          event.id,
          reassignToCategoryId: event.reassignTo,
        );
        final items = await tagCategoryRepository.getTagCategories();
        emit(TagCategoryLoaded(items));
      } catch (e) {
        emit(const TagCategoryError('Failed to delete tag category'));
        if (prev is TagCategoryLoaded) emit(prev);
      }
    }
  }

  Future<void> _onReorder(
    ReorderTagCategories event,
    Emitter<TagCategoryState> emit,
  ) async {
    final prev = state;
    if (prev is TagCategoryLoaded) {
      // Оптимистично обновим порядок локально
      final map = {
        for (final c in prev.categories) c.id: c,
      };
      final reordered = <TagCategory>[];
      for (int i = 0; i < event.idsInOrder.length; i++) {
        final id = event.idsInOrder[i];
        final c = map[id];
        if (c != null) {
          reordered.add(c.copyWith(sortOrder: i));
        }
      }
      emit(TagCategoryLoaded(reordered));

      // Сохраняем на диск
      try {
        await tagCategoryRepository.reorderTagCategories(event.idsInOrder);
        final items = await tagCategoryRepository.getTagCategories();
        emit(TagCategoryLoaded(items));
      } catch (e) {
        emit(const TagCategoryError('Failed to reorder tag categories'));
        emit(prev); // откат к предыдущему
      }
    }
  }
}
