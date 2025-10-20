// lib/src/presentation/blocs/tag_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/domain/repositories/tag_repository.dart';

part 'tag_event.dart';
part 'tag_state.dart';

class TagBloc extends Bloc<TagEvent, TagState> {
  final TagRepository tagRepository;

  TagBloc({required this.tagRepository}) : super(TagInitial()) {
    on<LoadTags>(_onLoadTags);
    on<AddTag>(_onAddTag);
    on<DeleteTag>(_onDeleteTag);
    on<UpdateTag>(_onUpdateTag);
  }

  Future<void> _onLoadTags(LoadTags event, Emitter<TagState> emit) async {
    emit(TagLoading());
    try {
      final tags = await tagRepository.getTags();
      emit(TagLoaded(tags));
    } catch (e) {
      emit(const TagError('Failed to load tags'));
    }
  }

  Future<void> _onAddTag(AddTag event, Emitter<TagState> emit) async {
    if (state is TagLoaded) {
      final currentState = state as TagLoaded;
      try {
        await tagRepository.addTag(event.tag);

        final updatedTags = List<Tag>.from(currentState.tags)..add(event.tag);

        emit(TagLoaded(updatedTags));
      } catch (e) {
        emit(const TagError('Failed to add tag'));
      }
    }
  }

  Future<void> _onDeleteTag(DeleteTag event, Emitter<TagState> emit) async {
    if (state is TagLoaded) {
      final currentState = state as TagLoaded;
      try {
        await tagRepository.deleteTag(event.id);

        final updatedTags =
            currentState.tags.where((tag) => tag.id != event.id).toList();

        emit(TagLoaded(updatedTags));
      } catch (e) {
        emit(const TagError('Failed to delete tag'));
      }
    }
  }

  Future<void> _onUpdateTag(UpdateTag event, Emitter<TagState> emit) async {
    final prev = state;
    if (prev is TagLoaded) {
      try {
        // 1) Сохраняем ВЕСЬ объект тега как есть (со всеми новыми полями)
        await tagRepository.updateTag(event.tag);

        // 2) Обновляем state, подменяя ровно этот тег на event.tag
        final updated = prev.tags.map((t) {
          return t.id == event.tag.id ? event.tag : t;
        }).toList();

        emit(TagLoaded(updated));
      } catch (e) {
        // Лог можно добавить при желании
        emit(const TagError('Failed to update tag'));
        emit(prev);
      }
    }
  }
}
